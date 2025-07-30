#!/bin/bash

# Install yad if missing
if ! command -v yad &> /dev/null; then
    echo "yad not found. Installing yad..." >&2
    if sudo apt update && sudo apt install -y yad; then
        echo "yad installed successfully." >&2
    else
        echo "❌ Failed to install yad. Please install manually: sudo apt install yad" >&2
        exit 1
    fi
fi

# Config
USER_REPO="https://raw.githubusercontent.com/HDTS1/shooter_user/main/CHANGELOG.txt"
ROOT_REPO="https://raw.githubusercontent.com/HDTS1/shooter_root/main/CHANGELOG.txt"

LOCAL_USER_LOG="$HOME/.shooter_last_user_changelog.txt"
LOCAL_ROOT_LOG="$HOME/.shooter_last_root_changelog.txt"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
APP_EXEC="/home/controller/shooter/controller/ShooterController"
LOG_FILE="/tmp/shooter_update.log"

# Exit code files for two-stage update
ROOT_EXIT="/tmp/shooter_update_root_exit_code"
USER_EXIT="/tmp/shooter_update_user_exit_code"

# Function to show update result
show_update_result() {
    local message="$1"
    local color="$2"
    local retry="$3"

    yad --title="Update Result" \
        --width=600 --height=250 --center \
        --button="💤 Skip and Launch App:1" \
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

# Fetch remote changelogs
TMP_USER_LOG=$(mktemp)
TMP_ROOT_LOG=$(mktemp)

curl -s "$USER_REPO" -o "$TMP_USER_LOG"
curl -s "$ROOT_REPO" -o "$TMP_ROOT_LOG"

# First run detection (missing local logs)
FIRST_RUN="false"
if [ ! -f "$LOCAL_USER_LOG" ] || [ ! -f "$LOCAL_ROOT_LOG" ]; then
    FIRST_RUN="true"
fi

# Compare both changelogs
USER_CHANGED=""
ROOT_CHANGED=""

if [ ! -f "$LOCAL_USER_LOG" ] || ! cmp -s "$LOCAL_USER_LOG" "$TMP_USER_LOG"; then
    USER_CHANGED="yes"
fi

if [ ! -f "$LOCAL_ROOT_LOG" ] || ! cmp -s "$LOCAL_ROOT_LOG" "$TMP_ROOT_LOG"; then
    ROOT_CHANGED="yes"
fi

# If no changes and not first run, launch app
if [ -z "$USER_CHANGED" ] && [ -z "$ROOT_CHANGED" ] && [ "$FIRST_RUN" = "false" ]; then
    yad --title="Up to Date" \
        --text="No updates found.\nLaunching Shooter App..." \
        --timeout=3 --no-buttons --center
    rm -f "$TMP_USER_LOG" "$TMP_ROOT_LOG"
    exec "$APP_EXEC"
fi

# Build changelog message
CHANGE_MSG=""

if [ "$USER_CHANGED" = "yes" ]; then
    USER_DIFF=$(diff --unchanged-group-format='' --changed-group-format='%>' "$LOCAL_USER_LOG" "$TMP_USER_LOG")
    CHANGE_MSG+="🔹 <b>App / User Updates:</b>\n\n$USER_DIFF\n\n"
fi

if [ "$ROOT_CHANGED" = "yes" ]; then
    ROOT_DIFF=$(diff --unchanged-group-format='' --changed-group-format='%>' "$LOCAL_ROOT_LOG" "$TMP_ROOT_LOG")
    CHANGE_MSG+="🔐 <b>System Updates:</b>\n\n$ROOT_DIFF"
fi

# Show update dialog if first run or changes detected
if [ "$FIRST_RUN" = "true" ]; then
    yad --title="First Run Detected" \
        --text="No previous changelog found.\nPerforming initial update..." \
        --timeout=2 --no-buttons --center

    pkill Shoo 2>/dev/null || true
    sleep 1
else
    # Show changelog and ask user
    yad --title="Update Available!" \
        --width=600 --height=400 \
        --text="<span font='13'><b>New changes detected:</b>\n\n$CHANGE_MSG</span>" \
        --button="💤 Skip for now:1" \
        --button="⚙️ Update Now!:0"

    RESPONSE=$?
    if [ "$RESPONSE" -ne 0 ]; then
        nohup "$APP_EXEC" > /dev/null 2>&1 & disown
        rm -f "$TMP_USER_LOG" "$TMP_ROOT_LOG"
        exit 0
    fi

    pkill Shoo 2>/dev/null || true
    sleep 1
fi

# Clean old exit codes
rm -f "$ROOT_EXIT" "$USER_EXIT"

# Launch terminal with both updates
xfce4-terminal \
    --hold \
    --title="🔧 Applying System + User Updates" \
    --font="Monospace 10" \
    --command="bash -c '\
        echo \"🚀 Starting system and user updates...\"; \
        echo \"📄 Log: $LOG_FILE\"; \
        echo \"──────────────────────────────────────\"; \
        if [ -x \"$SCRIPT_DIR/run_update.sh\" ]; then \
            exec \"$SCRIPT_DIR/run_update.sh\"; \
        else \
            echo \"❌ ERROR: Script not found or not executable\"; \
            echo \"💡 Run: chmod +x $SCRIPT_DIR/run_update.sh\"; \
            echo \"1\" > \"$ROOT_EXIT\"; \
            echo \"1\" > \"$USER_EXIT\"; \
        fi; \
        echo; \
        echo \"✅ Update process finished. Press Enter to close.\"; \
        read _\
    '" &

# Wait for both updates
echo "Waiting for system and user updates..."
ROOT_OK=""
USER_OK=""
TIMEOUT=600
while [ $TIMEOUT -gt 0 ]; do
    if [ -f "$ROOT_EXIT" ] && [ -f "$USER_EXIT" ]; then
        ROOT_OK=$(cat "$ROOT_EXIT")
        USER_OK=$(cat "$USER_EXIT")
        break
    fi
    sleep 2
    TIMEOUT=$((TIMEOUT - 2))
done

# Handle timeout
if [ -z "$ROOT_OK" ] || [ -z "$USER_OK" ]; then
    ROOT_OK=${ROOT_OK:-1}
    USER_OK=${USER_OK:-1}
    echo "❌ Timeout: One or more updates failed to complete." >> "$LOG_FILE"
fi

# Handle result
if [ "$ROOT_OK" -eq 0 ] && [ "$USER_OK" -eq 0 ]; then
    # Update both local logs
    cp "$TMP_USER_LOG" "$LOCAL_USER_LOG"
    cp "$TMP_ROOT_LOG" "$LOCAL_ROOT_LOG"

    yad --title="Update Complete" \
        --text="<span font='13' foreground='green'><b>All updates succeeded!\nSystem will now reboot.</b></span>" \
        --button="👍 OK:0" --center
    /usr/sbin/reboot

elif [ "$ROOT_OK" -eq 0 ] && [ "$USER_OK" -ne 0 ]; then
    show_update_result "System update OK, but user config failed.\nApp may be outdated.\nLaunch anyway?" "orange" false
    nohup "$APP_EXEC" > /dev/null 2>&1 & disown

elif [ "$ROOT_OK" -ne 0 ] && [ "$USER_OK" -eq 0 ]; then
    show_update_result "User update OK, but SYSTEM UPDATE FAILED.\nThis may cause instability.\nCheck log at $LOG_FILE.\nLaunch app anyway?" "red" true
    RESPONSE=$?
    if [ "$RESPONSE" -eq 2 ]; then
        rm -f "$ROOT_EXIT" "$USER_EXIT"
        exec "$0"
    fi
    nohup "$APP_EXEC" > /dev/null 2>&1 & disown

else
    show_update_result "Both system and user updates failed.\nCheck log at $LOG_FILE.\nRetry or launch app anyway?" "red" true
    RESPONSE=$?
    if [ "$RESPONSE" -eq 2 ]; then
        rm -f "$ROOT_EXIT" "$USER_EXIT"
        exec "$0"
    fi
    nohup "$APP_EXEC" > /dev/null 2>&1 & disown
fi

# Cleanup
rm -f "$TMP_USER_LOG" "$TMP_ROOT_LOG"
exit 0
