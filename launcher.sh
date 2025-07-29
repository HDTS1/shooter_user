#!/bin/bash
# AUTO-DEPENDENCY CHECK
if ! command -v yad &> /dev/null; then
    echo "yad not found. Installing..." >&2
    if sudo apt update && sudo apt install -y yad; then
        echo "yad installed successfully." >&2
    else
        echo "Failed to install yad!" >&2
        exit 1
    fi
fi

# CLEAN UP
rm -f /tmp/shooter_update.log
rm -f /tmp/shooter_update_exit_code

# CONFIG
USER_REPO="https://raw.githubusercontent.com/HDTS1/shooter_user/main/CHANGELOG.txt"
LOCAL_CHANGELOG="$HOME/.shooter_last_changelog.txt"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
APP_EXEC="/home/controller/shooter/controller/ShooterController"
LOG_FILE="/tmp/shooter_update.log"
EXIT_CODE_FILE="/tmp/shooter_update_exit_code"

# Function to show update result
show_update_result() {
    local message="$1"
    local color="$2"
    local retry="$3"

    yad --title="Update Result" \
        --width=600 --height=250 --center \
        --button="❌ Skip and Launch App:1" \
        $( [ "$retry" = "true" ] && echo --button="🔁 Retry Update:2" ) \
        --button="👍 OK:0" \
        --text="<span font='13' foreground='$color'><b>$message</b></span>" \
        --text-align=center
    return $?
}

# Show splash
yad --title="Shooter Launcher" \
    --text="Checking for updates..." \
    --width=300 --timeout=2 --no-buttons --center

sleep 1

# Fetch remote changelog
TMP_REMOTE_LOG=$(mktemp)
curl -s "$USER_REPO" -o "$TMP_REMOTE_LOG"

# First run? (no local changelog)
if [ ! -f "$LOCAL_CHANGELOG" ]; then
    yad --title="First Run Detected" \
        --text="No previous changelog found.\nPerforming initial update..." \
        --timeout=2 --no-buttons --center

    pkill Shoo 2>/dev/null || true
    sleep 1

    # 🔥 Clear old exit code to avoid false detection
    rm -f "$EXIT_CODE_FILE"

    # Launch terminal with live update log
    xfce4-terminal \
        --hold \
        --title="🔧 Initial Update (Live Log)" \
        --font="Monospace 10" \
        --command="bash -c '\
            echo \"🚀 Starting first-time update...\"; \
            echo \"📁 Script: $SCRIPT_DIR/run_update.sh\"; \
            echo \"📄 Log: $LOG_FILE\"; \
            echo \"──────────────────────────────────────\"; \
            if [ -x \"$SCRIPT_DIR/run_update.sh\" ]; then \
                exec \"$SCRIPT_DIR/run_update.sh\"; \
            else \
                echo \"❌ ERROR: Script not found or not executable\"; \
                echo \"💡 Fix with: chmod +x $SCRIPT_DIR/run_update.sh\"; \
                echo \"1\" > \"$EXIT_CODE_FILE\"; \
                read -p \"Press Enter to exit...\"; \
            fi\
        '" &

# Wait for update to finish
echo "Waiting for update to complete (checking $EXIT_CODE_FILE)..."
UPDATE_EXIT_CODE=""
TIMEOUT=600
while [ $TIMEOUT -gt 0 ]; do
    if [ -f "$EXIT_CODE_FILE" ]; then
        echo "✅ Found exit code file!"
        UPDATE_EXIT_CODE=$(cat "$EXIT_CODE_FILE" 2>/dev/null || echo "1")
        echo "➡️  Exit code: '$UPDATE_EXIT_CODE'"
        break
    else
        echo "⏳ File not found yet: $EXIT_CODE_FILE"
    fi
    sleep 2
    TIMEOUT=$((TIMEOUT - 2))
done

if [ -z "$UPDATE_EXIT_CODE" ]; then
    echo "❌ Timeout: No exit code received."
    UPDATE_EXIT_CODE=1
fi
    # If no result, assume failure
    if [ -z "$UPDATE_EXIT_CODE" ]; then
        echo "❌ Update timed out." >> "$LOG_FILE"
        UPDATE_EXIT_CODE=1
    fi

    # Handle result
    if [ "$UPDATE_EXIT_CODE" -eq 0 ]; then
        cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
        yad --title="Update Complete" \
            --text="<span font='13' foreground='green'><b>Update completed successfully.\nSystem will now reboot.</b></span>" \
            --button="👍 OK:0" --center
        /usr/sbin/reboot
    else
        show_update_result "Update failed.\nCheck log at $LOG_FILE.\nRetry or launch app anyway." "red" true
        RESPONSE=$?
        if [ "$RESPONSE" -eq 2 ]; then
            rm -f "$EXIT_CODE_FILE"
            exec "$0"
        fi
        nohup "$APP_EXEC" > /dev/null 2>&1 & disown
    fi

    rm -f "$TMP_REMOTE_LOG"
    exit 0
fi

# Compare changelogs
DIFF_OUTPUT=$(diff --changed-group-format='%>' --unchanged-group-format='' "$LOCAL_CHANGELOG" "$TMP_REMOTE_LOG")

if [ -z "$DIFF_OUTPUT" ]; then
    yad --title="Up to Date" \
        --text="No updates found.\nLaunching Shooter App..." \
        --timeout=3 --no-buttons --center
    exec "$APP_EXEC"
fi

# Show available update
yad --title="Update Available!" \
    --width=600 --height=400 \
    --text="<span font='13'><b>New changes detected:</b>\n\n$DIFF_OUTPUT</span>" \
    --button="❌ Skip for now:1" \
    --button="⚙️ Update Now!:0"

RESPONSE=$?

if [ "$RESPONSE" -eq 0 ]; then
    pkill Shoo 2>/dev/null || true
    sleep 1

    # 🔥 Clear old exit code before starting
    rm -f "$EXIT_CODE_FILE"

    # Launch terminal with live log
    xfce4-terminal \
        --hold \
        --title="🔧 Applying Update (Live Log)" \
        --font="Monospace 10" \
        --command="bash -c '\
            echo \"🚀 Starting update...\"; \
            echo \"📁 Running from: $SCRIPT_DIR\"; \
            echo \"📄 Log: $LOG_FILE\"; \
            echo \"──────────────────────────────────────\"; \
            if [ -x \"$SCRIPT_DIR/run_update.sh\" ]; then \
                exec \"$SCRIPT_DIR/run_update.sh\"; \
            else \
                echo \"❌ ERROR: Script not found or not executable\"; \
                echo \"💡 Run: chmod +x $SCRIPT_DIR/run_update.sh\"; \
                echo \"1\" > \"$EXIT_CODE_FILE\"; \
                read -p \"Press Enter to exit...\"; \
            fi\
        '" &

# Wait for update to finish
echo "Waiting for update to complete (checking $EXIT_CODE_FILE)..."
UPDATE_EXIT_CODE=""
TIMEOUT=600
while [ $TIMEOUT -gt 0 ]; do
    if [ -f "$EXIT_CODE_FILE" ]; then
        echo "✅ Found exit code file!"
        UPDATE_EXIT_CODE=$(cat "$EXIT_CODE_FILE" 2>/dev/null || echo "1")
        echo "➡️  Exit code: '$UPDATE_EXIT_CODE'"
        break
    else
        echo "⏳ File not found yet: $EXIT_CODE_FILE"
    fi
    sleep 2
    TIMEOUT=$((TIMEOUT - 2))
done

if [ -z "$UPDATE_EXIT_CODE" ]; then
    echo "❌ Timeout: No exit code received."
    UPDATE_EXIT_CODE=1
fi
    # Handle result
    if [ "$UPDATE_EXIT_CODE" -eq 0 ]; then
        cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
        yad --title="Update Complete" \
            --text="<span font='13' foreground='green'><b>Update completed successfully.\nSystem will now reboot.</b></span>" \
            --button="👍 OK:0" --center
        /usr/sbin/reboot
    else
        show_update_result "Update failed.\nCheck log at $LOG_FILE.\nRetry or launch app anyway." "red" true
        RESPONSE=$?
        if [ "$RESPONSE" -eq 2 ]; then
            rm -f "$EXIT_CODE_FILE"
            exec "$0"
        fi
        nohup "$APP_EXEC" > /dev/null 2>&1 & disown
    fi
else
    # User skipped update
    nohup "$APP_EXEC" > /dev/null 2>&1 & disown
fi

# Cleanup
rm -f "$TMP_REMOTE_LOG"
exit 0
