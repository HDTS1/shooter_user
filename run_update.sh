#!/bin/bash

# === CONFIG: Update Source Branches ===
# Change these to test different branches
ROOT_REPO_BRANCH="main"
USER_REPO_BRANCH="main"
CTRL_REPO_BRANCH="main"
# Examples:
#   ROOT_REPO_BRANCH="testing"
#   USER_REPO_BRANCH="testing"
#   CTRL_REPO_BRANCH="feature/new-layout"

# === LOG AND EXIT CODE FILES ===
LOG_FILE="/tmp/shooter_update.log"
ROOT_EXIT="/tmp/shooter_update_root_exit_code"
USER_EXIT="/tmp/shooter_update_user_exit_code"
CTRL_EXIT="/tmp/shooter_update_controller_exit_code"

# === CLEAN UP OLD FILES ===
> "$LOG_FILE"
rm -f "$ROOT_EXIT" "$USER_EXIT" "$CTRL_EXIT"

{
    echo "[$(date)] Starting system update (root)..."
    if sudo ansible-pull -U https://github.com/HDTS1/shooter_root.git --branch "$ROOT_REPO_BRANCH" main.yml; then
        echo "0" > "$ROOT_EXIT"
        echo "✅ System update succeeded."
    else
        echo "1" > "$ROOT_EXIT"
        echo "❌ System update failed."
    fi

    echo "[$(date)] Starting user update (controller)..."
    if ansible-pull -U https://github.com/HDTS1/shooter_user.git --branch "$USER_REPO_BRANCH" main.yml; then
        echo "0" > "$USER_EXIT"
        echo "✅ User update succeeded."
    else
        echo "1" > "$USER_EXIT"
        echo "❌ User update failed."
    fi

    echo "[$(date)] Starting controller-specific update..."
    if ansible-pull -U https://github.com/HDTS1/shooter_controller.git --branch "$CTRL_REPO_BRANCH" main.yml; then
        echo "0" > "$CTRL_EXIT"
        echo "✅ Controller update succeeded."
    else
        echo "1" > "$CTRL_EXIT"
        echo "❌ Controller update failed."
    fi

    echo "[$(date)] Update phase complete."

} &>> "$LOG_FILE"