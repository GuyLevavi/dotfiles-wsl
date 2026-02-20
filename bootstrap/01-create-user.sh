#!/usr/bin/env bash
set -euo pipefail
# 01-create-user.sh — Create a non-root dev user in WSL2 (Fedora/AlmaLinux)
# Usage: sudo ./01-create-user.sh [USERNAME]

USERNAME="${1:-dev}"

[[ "$(id -u)" -ne 0 ]] && { echo "Run as root (sudo)." >&2; exit 1; }

# Create user + wheel group (sudo)
if id "${USERNAME}" &>/dev/null; then
    echo "User '${USERNAME}' already exists."
else
    useradd --create-home --shell /bin/bash "${USERNAME}"
    echo "Created user '${USERNAME}'."
fi
usermod --append --groups wheel "${USERNAME}"

# Passwordless sudo for wheel
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd
chmod 0440 /etc/sudoers.d/wheel-nopasswd

# No password needed (WSL auto-login + passwordless sudo)
passwd --delete "${USERNAME}" &>/dev/null

# Configure WSL: default user, clean PATH, systemd for podman
cat > /etc/wsl.conf <<EOF
[user]
default=${USERNAME}

[interop]
enabled=true
appendWindowsPath=false

[boot]
systemd=true
EOF

echo ""
echo "Done. Next:"
echo "  1. wsl --shutdown"
echo "  2. Reopen WSL (logs in as ${USERNAME})"
echo "  3. sudo bash bootstrap/02-install-packages.sh"
