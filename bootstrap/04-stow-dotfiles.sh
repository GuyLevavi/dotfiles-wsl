#!/usr/bin/env bash
set -euo pipefail
# 04-stow-dotfiles.sh — Symlink all config packages into $HOME via GNU Stow
# Safe to re-run (--restow). Backs up conflicting files to ~/.dotfiles-backup/

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="$HOME/.dotfiles-backup"
PACKAGES=(zsh starship nvim tmux yazi git podman opencode codex)

backup_conflicts() {
    local pkg="$1"
    [[ -d "$REPO/$pkg" ]] || return 0
    local prefix="$REPO/$pkg/"
    while IFS= read -r -d '' file; do
        local rel="${file#"$prefix"}"
        [[ -z "$rel" ]] && continue
        local target="$HOME/$rel"
        if [[ -e "$target" ]] && [[ ! -L "$target" ]]; then
            mkdir -p "$(dirname "$BACKUP/$pkg/$rel")"
            mv "$target" "$BACKUP/$pkg/$rel"
            echo "  backed up ~/$rel"
        fi
    done < <(find "$REPO/$pkg" -type f -print0)
}

echo "==> Stowing dotfiles from $REPO"
for pkg in "${PACKAGES[@]}"; do
    [[ -d "$REPO/$pkg" ]] || { echo "  skip $pkg (not found)"; continue; }
    backup_conflicts "$pkg"
    stow --dir="$REPO" --target="$HOME" --restow "$pkg"
    echo "  done $pkg"
done

echo ""
[[ -d "$BACKUP" ]] && echo "Backups: $BACKUP"
echo "Next: bash bootstrap/05-setup-shell.sh"
