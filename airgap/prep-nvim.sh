#!/usr/bin/env bash
# prep-nvim.sh — Prepare Neovim for airgap: download all lazy plugins, treesitter parsers, Mason packages
# 
# Usage: ./prep-nvim.sh
# Run this in an ONLINE environment with nvim already installed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"
mkdir -p "$CACHE"

log()  { echo "==> $*"; }
warn() { echo "  ! $*" >&2; }

# Detect if we're in a Docker/container environment
IN_CONTAINER=false
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IN_CONTAINER=true
fi

# Check for nvim
if ! command -v nvim &>/dev/null; then
    warn "nvim not found in PATH"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -1 | grep -oP 'v\K[0-9.]+')
log "Using nvim: NVIM v$NVIM_VERSION"

# Check minimum version for LazyVim
if [[ "$(printf '%s\n' "0.11.2" "$NVIM_VERSION" | sort -V | head -n1)" != "0.11.2" ]]; then
    warn "LazyVim requires Neovim >= 0.11.2, you have $NVIM_VERSION"
    warn "Please upgrade nvim before running this script"
    exit 1
fi

export HOME="${HOME:-/root}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Use zig cc for treesitter compilation if available
if [[ -f "$HOME/.local/bin/zig" ]]; then
    export CC="$HOME/.local/bin/zig"
    log "Using zig cc for treesitter compilation"
else
    warn "zig not found at ~/.local/bin/zig - treesitter may fail to compile parsers"
fi

NVIM_CONFIG="${XDG_CONFIG_HOME}/nvim"
NVIM_DATA="${XDG_DATA_HOME}/nvim"

if [[ ! -d "$NVIM_CONFIG" ]]; then
    echo "ERROR: $NVIM_CONFIG does not exist"
    exit 1
fi

# Ensure all XDG directories exist
mkdir -p "$NVIM_DATA/lazy"
mkdir -p "$XDG_CACHE_HOME/nvim"
mkdir -p "$XDG_STATE_HOME/nvim"

log "Step 1: Bootstrap lazy.nvim..."
LAZY_PATH="${NVIM_DATA}/lazy/lazy.nvim"
if [[ ! -d "$LAZY_PATH" ]]; then
    log "Cloning lazy.nvim..."
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable "$LAZY_PATH"
fi

log "Step 2: Sync all lazy plugins..."
# Note: We don't manually clone plugins that are in the lazy spec.
# lazy.nvim will install them automatically during sync.

log "Step 3: Sync all lazy plugins..."
nvim --headless -c "lua require('lazy').sync({wait=true})" -c "qa" 2>&1 || {
    warn "Lazy sync may have had issues, continuing..."
}

log "Step 4: Install/Update treesitter parsers..."
# Core parsers for development
PARSERS="python lua bash json yaml toml markdown markdown_inline html css dockerfile vim vimdoc regex diff gitcommit gitignore"
for parser in $PARSERS; do
    nvim --headless -c "lua vim.cmd('TSInstallSync $parser')" -c "qa" 2>/dev/null || {
        warn "Failed to install parser: $parser"
    }
done

# Update all parsers
nvim --headless -c "lua vim.cmd('TSUpdateSync')" -c "qa" 2>/dev/null || true

log "Step 5: Run MasonToolsInstallSync..."
# This installs all Mason packages declared in mason-tool-installer.nvim config
nvim --headless -c "MasonToolsInstallSync" -c "qa" 2>&1 || {
    warn "MasonToolsInstallSync had issues (some packages may already be installed)"
}

log "Step 6: Verify critical components..."

# Verify mason-tool-installer
if [[ -d "${NVIM_DATA}/lazy/mason-tool-installer.nvim" ]]; then
    log "✓ mason-tool-installer.nvim found"
else
    warn "mason-tool-installer.nvim missing"
fi

# Verify mason packages
MASON_COUNT=$(ls "${NVIM_DATA}/mason/packages/" 2>/dev/null | wc -l)
log "Mason packages installed: $MASON_COUNT"

# Verify treesitter parsers
PARSER_COUNT=$(find "${NVIM_DATA}/site/parser/" -name "*.so" 2>/dev/null | wc -l)
log "Treesitter parsers compiled: $PARSER_COUNT"

# Verify lazy plugins
PLUGIN_COUNT=$(ls "${NVIM_DATA}/lazy/" 2>/dev/null | wc -l)
log "Lazy plugins installed: $PLUGIN_COUNT"

log "Step 7: Create bundles..."

# Main data bundle (plugins, mason packages)
tar -czf "${CACHE}/nvim-data.tar.gz" -C "$HOME/.local/share" nvim
log "Created: ${CACHE}/nvim-data.tar.gz ($(du -h "${CACHE}/nvim-data.tar.gz" | cut -f1))"

# Cache bundle (treesitter parsers)
if [[ -d "$HOME/.cache/nvim" ]]; then
    tar -czf "${CACHE}/nvim-cache.tar.gz" -C "$HOME/.cache" nvim 2>/dev/null || true
    if [[ -f "${CACHE}/nvim-cache.tar.gz" ]]; then
        log "Created: ${CACHE}/nvim-cache.tar.gz ($(du -h "${CACHE}/nvim-cache.tar.gz" | cut -f1))"
    fi
fi

# State bundle (Mason registry, etc)
if [[ -d "$HOME/.local/state/nvim" ]]; then
    tar -czf "${CACHE}/nvim-state.tar.gz" -C "$HOME/.local/state" nvim 2>/dev/null || true
    if [[ -f "${CACHE}/nvim-state.tar.gz" ]]; then
        log "Created: ${CACHE}/nvim-state.tar.gz ($(du -h "${CACHE}/nvim-state.tar.gz" | cut -f1))"
    fi
fi

echo ""
echo "=== Summary ==="
ls -lh "${CACHE}"/nvim-*.tar.gz 2>/dev/null

echo ""
echo "Next steps:"
echo "  1. Copy these files to airgap/cache/ in your bundle"
echo "  2. Or use directly: tar -xzf ${CACHE}/nvim-data.tar.gz -C \$HOME"
echo ""
echo "For airgap deployment:"
echo "  bash airgap/deploy.sh --offline devenv-bundle-*.tar.gz"
echo "  # Then manually extract nvim data if not in bundle:"
echo "  tar -xzf ${CACHE}/nvim-data.tar.gz -C /home/\$USER"
