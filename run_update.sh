#!/bin/bash

LOG_FILE="/tmp/shooter_update.log"
EXIT_CODE_FILE="/tmp/shooter_update_exit_code"

# Always write exit code on exit, no matter what
trap 'echo "$FINAL_EXIT_CODE" > "$EXIT_CODE_FILE"' EXIT

# Initialize exit code
FINAL_EXIT_CODE=0

# Clear log
> "$LOG_FILE"

{
    echo "[$(date)] Starting update..."
    echo "Running ansible-pull on main.yml"

    # Run ansible-pull
    ansible-pull -v -U https://github.com/HDTS1/shooter_user.git main.yml

    # Capture result
    FINAL_EXIT_CODE=$?

    if [ $FINAL_EXIT_CODE -eq 0 ]; then
        echo "✅ Update succeeded."
    else
        echo "❌ Update failed with code: $FINAL_EXIT_CODE"
    fi

} &>> "$LOG_FILE"

# This ensures trap fires and writes the file
exit $FINAL_EXIT_CODE
