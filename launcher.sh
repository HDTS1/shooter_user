#!/bin/bash

# CONFIG
USER_REPO="https://raw.githubusercontent.com/HDTS1/shooter_user/main/CHANGELOG.txt"
LOCAL_CHANGELOG="$HOME/.shooter_last_changelog.txt"
TMP_REMOTE_LOG=$(mktemp)

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

    ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml 2>&1 \
        | yad --title="Initial Update..." --width=600 --height=400 \
              --text-info --tail --center

    cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
    sudo reboot
    exit 0
fi

sleep 1

# Compare changelogs
DIFF_OUTPUT=$(diff --changed-group-format='%>' --unchanged-group-format='' "$LOCAL_CHANGELOG" "$TMP_REMOTE_LOG")

if [ -z "$DIFF_OUTPUT" ]; then
    yad --title="Up to Date" \
        --text="No updates found.\nLaunching Fusion Skating Subpacket..." \
        --timeout=3 --no-buttons --center
    exec /home/controller/shooter/controller/ShooterController
    exit 0
fi

# Show new updates and ask user
yad --title="Update Available!" \
    --width=600 --height=400 \
    --text="New changes detected:\n\n$DIFF_OUTPUT" \
    --button="Skip for now:1" --button="Update Now!:0"

RESPONSE=$?

if [ "$RESPONSE" -eq 0 ]; then
    echo "User chose to update."

    pkill Shoo
    sleep 1

    ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml 2>&1 \
        | yad --title="Applying Update..." --width=600 --height=400 \
              --text-info --tail --center

    cp "$TMP_REMOTE_LOG" "$LOCAL_CHANGELOG"
    sleep 1

    yad --title="Update Complete" \
        --text="Update completed successfully.\nRebooting system..." \
        --timeout=2 --no-buttons --center
    sudo reboot
else
    echo "User skipped update."
    nohup /home/controller/shooter/controller/ShooterController > /dev/null 2>&1 & disown
fi

# Cleanup
rm -f "$TMP_REMOTE_LOG"
