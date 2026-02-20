#!/usr/bin/env bash
set -euo pipefail
# 05-setup-shell.sh — Final setup: zsh default, XDG dirs, zinit

# Set zsh as default shell (use /usr/bin/zsh — must match an entry in /etc/shells)
ZSH="$(command -v zsh)"
# Resolve symlinks to find the canonical path listed in /etc/shells
ZSH="$(readlink -f "$ZSH")"
if [[ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH" ]]; then
    chsh -s "$ZSH"
    echo "Default shell: $ZSH"
else
    echo "Shell already zsh."
fi

# Create standard directories
mkdir -p ~/.local/bin ~/.config ~/.cache ~/.local/share

# Install zinit (zsh plugin manager)
ZINIT="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT" ]]; then
    git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT"
    echo "Installed zinit."
else
    echo "Zinit already installed."
fi

echo ""
echo "Setup complete! Run: exec zsh"
