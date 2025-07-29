#!/bin/bash

# CONFIG
USER_REPO="https://raw.githubusercontent.com/HDTS1/shooter_user/main/CHANGELOG.txt"
LOCAL_CHANGELOG="$HOME/.shooter_last_changelog.txt"
TMP_REMOTE_LOG=$(mktemp)
APP_EXEC="/home/controller/shooter/controller/ShooterController"

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

# First run? Do updates automatically
if [ ! -f "$LOCAL_CHANGELOG" ]; then
    yad --title="First Run Detected" \
        --text="No previous changelog found.\nPerforming initial update..." \
        --timeout=2 --no-buttons --center

pkill Shoo
sleep 1

if ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml 2>&1 \
    | yad --title="Applying Update..." --width=600 --height=400 --text-info --center --wrap --no-buttons; then

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

    exit 0
fi

sleep 1

# Compare changelogs
DIFF_OUTPUT=$(diff --changed-group-format='%>' --unchanged-group-format='' "$LOCAL_CHANGELOG" "$TMP_REMOTE_LOG")

# No new updates
if [ -z "$DIFF_OUTPUT" ]; then
    yad --title="Up to Date" \
        --text="No updates found.\nLaunching Fusion Skating Subpacket..." \
        --timeout=3 --no-buttons --center
    exec "$APP_EXEC"
    exit 0
fi

# Show detected changes
yad --title="Update Available!" \
    --width=600 --height=400 \
    --text="<span font='13'><b>New changes detected:</b>\n\n$DIFF_OUTPUT</span>" \
    --button="💤 Skip for now:1" --button="⚙️ Update Now!:0"

RESPONSE=$?

if [ "$RESPONSE" -eq 0 ]; then
    echo "User chose to update."
    pkill Shoo
    sleep 1

    if ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml 2>&1 \
        | tee >(yad --title="Applying Update..." --width=600 --height=400 \
                    --text-info --tail --no-buttons --center) \
        | cat > /dev/null; then

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
