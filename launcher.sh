#!/bin/bash

# CONFIG
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
USER_REPO="https://raw.githubusercontent.com/HDTS1/shooter_user/main/CHANGELOG.txt"
LOCAL_CHANGELOG="$HOME/.shooter_last_changelog.txt"
TMP_REMOTE_LOG=$(mktemp)
APP_EXEC="/home/controller/shooter/controller/ShooterController"
STATUS_FILE="$SCRIPT_DIR/update_status.txt"

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

# Fetch changelog
curl -s "$USER_REPO" -o "$TMP_REMOTE_LOG"

# First run? Do update automatically
if [ ! -f "$LOCAL_CHANGELOG" ]; then
    yad --title="First Run Detected" \
        --text="No previous changelog found.\nPerforming initial update..." \
        --timeout=2 --no-buttons --center

    pkill Shoo
    sleep 1

    xterm -hold -e "$SCRIPT_DIR/run_ansible_update.sh"

    if grep -q success "$STATUS_FILE"; then
        cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
        sleep 1
        yad --title="Update Complete" \
            --text="<span font='13' foreground='green'><b>Update successful.\nSystem will now reboot.</b></span>" \
            --button="👍 OK:0" --center
        /usr/sbin/reboot
    else
        show_update_result "Update failed.\nPlease retry or launch app anyway." "red" true
        RESPONSE=$?
        if [ "$RESPONSE" -eq 2 ]; then
            exec "$0"
        else
            nohup "$APP_EXEC" > /dev/null 2>&1 & disown
        fi
    fi
    exit 0
fi

sleep 1

# Compare changelogs
DIFF_OUTPUT=$(diff --changed-group-format='%>' --unchanged-group-format='' "$LOCAL_CHANGELOG" "$TMP_REMOTE_LOG")

if [ -z "$DIFF_OUTPUT" ]; then
    yad --title="Up to Date" \
        --text="No updates found.\nLaunching Fusion Skating Subpacket..." \
        --timeout=3 --no-buttons --center
    exec "$APP_EXEC"
    exit 0
fi

# Show update info and ask user
yad --title="Update Available!" \
    --width=600 --height=400 \
    --text="<span font='13'><b>New changes detected:</b>\n\n$DIFF_OUTPUT</span>" \
    --button="💤 Skip for now:1" --button="⚙️ Update Now!:0"

RESPONSE=$?

if [ "$RESPONSE" -eq 0 ]; then
    echo "User chose to update."
    pkill Shoo
    sleep 1

    xterm -hold -e "$SCRIPT_DIR/run_ansible_update.sh"

    if grep -q success "$STATUS_FILE"; then
        cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
        sleep 1
        yad --title="Update Complete" \
            --text="<span font='13' foreground='green'><b>Update completed successfully.\nSystem will now reboot.</b></span>" \
            --button="👍 OK:0" --center
        /usr/sbin/reboot
    else
        show_update_result "Update failed.\nPlease retry or launch app anyway." "red" true
        RESPONSE=$?
        if [ "$RESPONSE" -eq 2 ]; then
            exec "$0"
        else
            nohup "$APP_EXEC" > /dev/null 2>&1 & disown
        fi
    fi
else
    echo "User skipped update."
    nohup "$APP_EXEC" > /dev/null 2>&1 & disown
fi

# Cleanup
rm -f "$TMP_REMOTE_LOG"
