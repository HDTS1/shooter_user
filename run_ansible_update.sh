#!/bin/bash

# File paths (adjust if needed)
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LOGFILE="$SCRIPT_DIR/ansible_update.log"
STATUSFILE="$SCRIPT_DIR/update_status.txt"

rm -f "$LOGFILE" "$STATUSFILE"

ansible-pull -U https://github.com/HDTS1/shooter_user.git main.yml > "$LOGFILE" 2>&1

if [ $? -eq 0 ]; then
    echo "success" > "$STATUSFILE"
else
    echo "fail" > "$STATUSFILE"
fi
