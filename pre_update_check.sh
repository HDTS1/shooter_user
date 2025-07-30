#!/bin/bash

# Fast pre-update check: internet + apt unlocked
# Exits 0 if ready, 1 if not

# Install yad and lsof if missing
if ! command -v yad &> /dev/null || ! command -v lsof &> /dev/null; then
    echo "Installing required tools: yad, lsof..." >&2
    if sudo apt update && sudo apt install -y yad lsof curl; then
        echo "✅ Required tools installed."
    else
        echo "❌ Failed to install required tools." >&2
        exit 1
    fi
fi

set -o pipefail
TIMEOUT=10
LOCK_FILES=(
    /var/lib/dpkg/lock
    /var/lib/dpkg/lock-frontend
    /var/cache/apt/archives/lock
)

# Check internet with curl (more reliable)
if ! timeout $TIMEOUT curl -fsS --head https://github.com > /dev/null 2>&1; then
    echo "❌ No internet connectivity"
    exit 1
fi

# 2. Check for apt/dpkg locks
for lockfile in "${LOCK_FILES[@]}"; do
    if [ -f "$lockfile" ]; then
        if lsof "$lockfile" > /dev/null 2>&1 || lsof /var/lib/dpkg/lock > /dev/null 2>&1; then
            echo "❌ Package manager is locked: $lockfile"
            exit 1
        fi
    fi
done

# 3. Optional: Check if unattended-upgrades is running
if pgrep -x "unattended-upgrade" > /dev/null; then
    echo "❌ unattended-upgrades is running"
    exit 1
fi

# All checks passed
exit 0
