#!/bin/bash

# Log and exit code files
LOG_FILE="/tmp/shooter_update.log"
ROOT_EXIT="/tmp/shooter_update_root_exit_code"
USER_EXIT="/tmp/shooter_update_user_exit_code"

# Clear old logs and exit codes
> "$LOG_FILE"
rm -f "$ROOT_EXIT" "$USER_EXIT"

{
    echo "[$(date)] Starting system update (root)..."
    if sudo ansible-pull -U https://github.com/HDTS1/shooter_root.git main.yml; then
        echo "0" > "$ROOT_EXIT"
        echo "✅ System update succeeded."
    else
        echo "1" > "$ROOT_EXIT"
        echo "❌ System update failed."
    fi

    echo "[$(date)] Starting user update (controller)..."
    if ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml; then
        echo "0" > "$USER_EXIT"
        echo "✅ User update succeeded."
    else
        echo "1" > "$USER_EXIT"
        echo "❌ User update failed."
    fi

    echo "[$(date)] Update phase complete."

} &>> "$LOG_FILE"
