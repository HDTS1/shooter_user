#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# === CONFIG ===
GITHUB_REPO="https://github.com/HDTS1/shooter_user/raw/main"
SCRIPTS=("launcher.sh" "run_update.sh")
TARGET_USER="controller"
TARGET_DIR="/home/$TARGET_USER/bin"

# Sudoers file and temp backup
SUDOERS="/etc/sudoers"
SUDOERS_BACKUP="/etc/sudoers.dpkg-tmp"
SUDOERS_INC="/etc/sudoers.d/shooter"
OLD_SUDOERS_D="/etc/sudoers.d/10-installer"

# Validate controller user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "❌ Error: User '$TARGET_USER' does not exist."
    exit 1
fi

# === 1. Install ansible (includes ansible-pull) ===
echo "📦 Installing ansible (includes ansible-pull)..."
if ! command -v ansible-pull &>/dev/null; then
    sudo apt update
    sudo apt install -y ansible-core || {
        echo "❌ Failed to install ansible-core"
        exit 1
    }
else
    echo "✅ ansible-pull is already installed."
fi

# === 2. Create bin directory and download scripts ===
echo "📥 Downloading scripts to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

for script in "${SCRIPTS[@]}"; do
    url="$GITHUB_REPO/$script"
    dest="$TARGET_DIR/$script"
    if curl -fsSL "$url" -o "$dest"; then
        chmod +x "$dest"
        echo "✅ Downloaded and made executable: $dest"
    else
        echo "❌ Failed to download $url"
        exit 1
    fi
done

# === 3. Clean up old sudoers.d file ===
OLD_SUDOERS_D="/etc/sudoers.d/10-install"

if [ -f "$OLD_SUDOERS_D" ]; then
    echo "🧹 Removing outdated sudoers file: $OLD_SUDOERS_D"
    sudo rm -f "$OLD_SUDOERS_D"
    echo "✅ Removed $OLD_SUDOERS_D"
else
    echo "ℹ️  $OLD_SUDOERS_D not found — skipping."
fi

# === 4. Remove old controller line from /etc/sudoers ===
echo "🔧 Removing old 'controller' line from $SUDOERS"

# Backup before editing
sudo cp "$SUDOERS" "$SUDOERS_BACKUP"
echo "✅ Backed up $SUDOERS to $SUDOERS_BACKUP"

# Remove any line containing "controller ALL=(ALL) NOPASSWD" (case-insensitive)
sudo sed -i '\~controller[[:space:]]\+ALL=(ALL)~d' "$SUDOERS"

# Verify it's gone
if grep -q "controller.*NOPASSWD" "$SUDOERS"; then
    echo "❌ Failed to remove old controller line from $SUDOERS"
    exit 1
fi
echo "✅ Old controller line removed"

# === 5. Write new sudoers rule to /etc/sudoers.d/shooter ===
echo "🔐 Writing new sudoers rule to $SUDOERS_INC"
sudo tee "$SUDOERS_INC" > /dev/null << 'EOF'
# Allow controller to run reboot, shutdown, and ansible-pull without password
controller ALL=(ALL) NOPASSWD: /usr/sbin/reboot, /usr/sbin/shutdown, /usr/bin/ansible-pull
EOF

# Secure permissions (required for sudoers.d)
sudo chmod 440 "$SUDOERS_INC"

# Validate syntax
if sudo visudo -c -f "$SUDOERS_INC" >/dev/null 2>&1; then
    echo "✅ Sudoers rule installed and valid: $SUDOERS_INC"
else
    echo "❌ Invalid sudoers syntax in $SUDOERS_INC"
    exit 1
fi

# === 6. Final Check ===
echo ""
echo "🎉 Kiosk deployment complete!"
echo "   - Scripts: $TARGET_DIR/"
echo "   - Sudoers: /etc/sudoers.d/shooter"
echo "   - Ansible: installed"
echo ""
echo "💡 Next steps:"
echo "   - Reboot or run: $TARGET_DIR/launcher.sh"
echo "   - Ensure yad is installed: sudo apt install -y yad"
