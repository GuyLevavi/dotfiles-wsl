#!/usr/bin/env bash
set -euo pipefail
# prep-nvim.sh — Prepare Neovim for airgap: download all lazy plugins, treesitter parsers, Mason packages
# Run this in an ONLINE environment BEFORE creating the airgap bundle.
# Usage: ./prep-nvim.sh [--distro fedora|ubuntu]
#
# IMPORTANT: This script assumes:
#   1. nvim is installed and in PATH
#   2. Your nvim config is at ~/.config/nvim/ (or $XDG_CONFIG_HOME/nvim)
#   3. You have internet access to clone repos and download packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"

DISTRO="${1:-auto}"

log()  { echo "==> $*"; }
warn() { echo "  ! $*" >&2; }

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "${ID:-}" in
            ubuntu|debian) echo "ubuntu" ;;
            fedora|rhel|centos|almalinux|rocky) echo "fedora" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

if [[ "$DISTRO" == "auto" ]]; then
    DISTRO=$(detect_distro)
fi

log "Detected distro: $DISTRO"

# Check for nvim
if ! command -v nvim &>/dev/null; then
    warn "nvim not found in PATH"
    log "Please ensure nvim is installed. For airgap bundle, use the cached nvim.appimage:"
    log "  ./nvim.appimage --appimage-extract"
    log "  export PATH=\$PWD/squashfs-root/usr/bin:\$PATH"
    exit 1
fi

log "Using nvim: $(nvim --version | head -1)"

# Optional: install tree-sitter-cli if not present
if ! command -v tree-sitter &>/dev/null; then
    log "Installing tree-sitter-cli..."
    if command -v npm &>/dev/null; then
        npm install -g tree-sitter-cli 2>/dev/null || true
    elif command -v cargo &>/dev/null; then
        cargo install tree-sitter-cli 2>/dev/null || true
    else
        warn "tree-sitter-cli not found - treesitter compilation may fail"
    fi
fi

export HOME="${HOME:-/root}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

NVIM_CONFIG="${XDG_CONFIG_HOME}/nvim"
NVIM_DATA="${XDG_DATA_HOME}/nvim"

if [[ ! -d "$NVIM_CONFIG" ]]; then
    echo "ERROR: $NVIM_CONFIG does not exist"
    echo "Copy your nvim config to $NVIM_CONFIG first"
    exit 1
fi

log "Bootstrap lazy.nvim if needed..."
LAZY_PATH="${NVIM_DATA}/lazy/lazy.nvim"
if [[ ! -d "$LAZY_PATH" ]]; then
    log "Cloning lazy.nvim..."
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable "$LAZY_PATH"
fi

log "Ensuring nvim data directories exist..."
mkdir -p "$NVIM_DATA/lazy"
mkdir -p "$XDG_CACHE_HOME/nvim"
mkdir -p "$XDG_STATE_HOME/nvim"

log "Syncing all lazy plugins (this downloads EVERYTHING)..."
nvim --headless -c "lua require('lazy').sync({wait=true})" -c "qa"

log "Installing treesitter parsers..."
PARSERS="python lua bash json yaml toml markdown markdown_inline html css dockerfile vim vimdoc regex diff gitcommit gitignore helm requirements"
for parser in $PARSERS; do
    nvim --headless -c "lua vim.cmd('TSInstallSync $parser')" -c "qa" 2>/dev/null || true
done
nvim --headless -c "lua vim.cmd('TSUpdateSync')" -c "qa" 2>/dev/null || true

log "Triggering neotest..."
nvim --headless -c "lua require('neotest-python')" -c "qa" 2>/dev/null || true

log "Triggering nvim-dap-python..."
nvim --headless -c "lua require('dap-python')" -c "qa" 2>/dev/null || true

log "Installing Mason packages via MasonToolsInstallSync..."
nvim --headless -c "MasonToolsInstallSync" -c "qa" 2>&1 || true

log "Waiting for Mason installs to complete..."
sleep 30

log "Verifying nightfox colorscheme is fully installed..."
# Nightfox should already be in lazy plugins, but verify
if [[ -d "${NVIM_DATA}/lazy/nightfox.nvim" ]]; then
    log "nightfox.nvim found in lazy plugins"
else
    warn "nightfox.nvim not found - colorscheme may fail in airgap"
fi

log "Checking lazy-lock.json..."
if [[ -f "$NVIM_CONFIG/lazy-lock.json" ]]; then
    log "lazy-lock.json found at $NVIM_CONFIG/lazy-lock.json"
elif [[ -f "$NVIM_DATA/lazy/lazy-lock.json" ]]; then
    cp "$NVIM_DATA/lazy/lazy-lock.json" "$NVIM_CONFIG/lazy-lock.json"
    log "lazy-lock.json copied to $NVIM_CONFIG/lazy-lock.json"
else
    warn "lazy-lock.json NOT found!"
fi

log "Listing installed plugins..."
ls -la "$NVIM_DATA/lazy/" | head -20

log "Listing treesitter parsers..."
if [[ -d "$NVIM_DATA/site/parser/" ]]; then
    ls -la "$NVIM_DATA/site/parser/" | head -20
else
    warn "No parsers directory found"
fi

log "Creating nvim-data.tar.gz..."
mkdir -p "$CACHE"
tar -czf "${CACHE}/nvim-data.tar.gz" -C "$HOME/.local/share" nvim
log "Created: ${CACHE}/nvim-data.tar.gz ($(du -h "${CACHE}/nvim-data.tar.gz" | cut -f1))"

log "Creating nvim-cache.tar.gz..."
tar -czf "${CACHE}/nvim-cache.tar.gz" -C "$HOME/.cache" nvim 2>/dev/null || true
if [[ -f "${CACHE}/nvim-cache.tar.gz" ]]; then
    log "Created: ${CACHE}/nvim-cache.tar.gz ($(du -h "${CACHE}/nvim-cache.tar.gz" | cut -f1))"
fi

log "Creating nvim-state.tar.gz..."
tar -czf "${CACHE}/nvim-state.tar.gz" -C "$HOME/.local/state" nvim 2>/dev/null || true
if [[ -f "${CACHE}/nvim-state.tar.gz" ]]; then
    log "Created: ${CACHE}/nvim-state.tar.gz ($(du -h "${CACHE}/nvim-state.tar.gz" | cut -f1))"
fi

echo ""
log "=== Summary ==="
log "Files created in ${CACHE}/:"
ls -lh "${CACHE}"/nvim-*.tar.gz 2>/dev/null || true

echo ""
log "On target airgap machine, extract with:"
echo "  tar -xzf nvim-data.tar.gz -C \$HOME"
echo "  tar -xzf nvim-cache.tar.gz -C \$HOME  (optional)"
echo "  tar -xzf nvim-state.tar.gz -C \$HOME  (optional)"
