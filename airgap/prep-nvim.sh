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
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }
fail() { echo "  ✗ $*" >&2; }

# Detect if we're in a Docker/container environment
IN_CONTAINER=false
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IN_CONTAINER=true
fi

# Check for nvim
if ! command -v nvim &>/dev/null; then
    fail "nvim not found in PATH"
    exit 1
fi

NVIM_VERSION=$(nvim --version | head -1 | grep -oP 'v\K[0-9.]+')
log "Using nvim: NVIM v$NVIM_VERSION"

# Check minimum version for LazyVim
if [[ "$(printf '%s\n' "0.11.2" "$NVIM_VERSION" | sort -V | head -n1)" != "0.11.2" ]]; then
    fail "LazyVim requires Neovim >= 0.11.2, you have $NVIM_VERSION"
    exit 1
fi

export HOME="${HOME:-/root}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Check for build dependencies
log "Checking build dependencies..."
for cmd in gcc make curl; do
    if ! command -v $cmd &>/dev/null; then
        warn "$cmd not found - some builds may fail"
    fi
done

# Use zig cc for treesitter compilation if available
ZIG_PATH=""
if [[ -f "$HOME/.local/bin/zig" ]]; then
    export CC="$HOME/.local/bin/zig"
    ZIG_PATH="$HOME/.local/bin/zig"
    log "Using zig cc for treesitter compilation"
elif command -v zig &>/dev/null; then
    export CC="$(command -v zig)"
    ZIG_PATH="$(command -v zig)"
    log "Using zig cc for treesitter compilation ($(command -v zig))"
else
    warn "zig not found - treesitter may fail to compile parsers"
fi

NVIM_CONFIG="${XDG_CONFIG_HOME}/nvim"
NVIM_DATA="${XDG_DATA_HOME}/nvim"

if [[ ! -d "$NVIM_CONFIG" ]]; then
    fail "$NVIM_CONFIG does not exist"
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
ok "lazy.nvim ready"

log "Step 2: Sync all lazy plugins (this takes a while)..."
nvim --headless -c "lua require('lazy').sync({wait=true})" -c "qa" 2>&1 || {
    warn "Lazy sync may have had issues, continuing..."
}
PLUGIN_COUNT=$(ls "${NVIM_DATA}/lazy/" 2>/dev/null | wc -l)
ok "Lazy plugins: $PLUGIN_COUNT"

log "Step 3: Install Mason packages via mason-tool-installer..."
# This requires the mason-tool-installer.nvim plugin
nvim --headless -c "sleep 3" -c "MasonToolsInstallSync" -c "qa" 2>&1 || {
    warn "MasonToolsInstallSync may have had issues"
}

# Wait and retry if needed
sleep 5
MASON_COUNT=$(ls "${NVIM_DATA}/mason/packages/" 2>/dev/null | wc -l)
if [[ $MASON_COUNT -lt 8 ]]; then
    warn "Only $MASON_COUNT Mason packages, retrying..."
    nvim --headless -c "sleep 5" -c "MasonToolsInstallSync" -c "qa" 2>&1 || true
    MASON_COUNT=$(ls "${NVIM_DATA}/mason/packages/" 2>/dev/null | wc -l)
fi
ok "Mason packages: $MASON_COUNT"

log "Step 4: Install/Compile treesitter parsers..."
# Parsers matching treesitter.lua config
PARSERS="python lua bash dockerfile json jsonc yaml toml markdown markdown_inline html css vim vimdoc regex gitcommit gitignore git_rebase diff helm requirements"
for parser in $PARSERS; do
    echo -n "  Installing parser: $parser... "
    nvim --headless -c "TSInstallSync $parser" -c "qa" 2>/dev/null && echo "✓" || echo "!"
done

# Update all parsers
nvim --headless -c "TSUpdateSync" -c "qa" 2>/dev/null || true

# Count compiled parsers
PARSER_COUNT=$(find "${NVIM_DATA}/site/parser/" -name "*.so" 2>/dev/null | wc -l)
if [[ $PARSER_COUNT -eq 0 ]]; then
    # Parsers might be in cache if site/parser doesn't exist
    PARSER_COUNT=$(find "$HOME/.cache/nvim/" -name "*.so" 2>/dev/null | wc -l)
fi
ok "Treesitter parsers compiled: $PARSER_COUNT"

log "Step 5: Verify critical components..."

# Check for .cloning files (indicates incomplete installations)
CLONING_COUNT=$(find "${NVIM_DATA}/lazy" -name "*.cloning" 2>/dev/null | wc -l)
if [[ $CLONING_COUNT -gt 0 ]]; then
    warn "Found $CLONING_COUNT .cloning files - some plugins may be incomplete"
fi

# Verify essential Mason packages
REQUIRED_MASON="basedpyright ruff debugpy yaml-language-server json-lsp"
for pkg in $REQUIRED_MASON; do
    if [[ -d "${NVIM_DATA}/mason/packages/$pkg" ]]; then
        ok "Mason package: $pkg"
    else
        warn "Mason package missing: $pkg"
    fi
done

# Verify mason-tool-installer plugin
if [[ -d "${NVIM_DATA}/lazy/mason-tool-installer.nvim" ]]; then
    ok "mason-tool-installer.nvim plugin installed"
else
    warn "mason-tool-installer.nvim plugin NOT found"
fi

log "Step 5b: Compile blink.cmp Rust library..."
# blink.cmp requires a native Rust library for fuzzy matching
BLINK_PATH="${NVIM_DATA}/lazy/blink.cmp"
if [[ -d "$BLINK_PATH" ]]; then
    # Check if already compiled
    if [[ -f "$BLINK_PATH/target/release/libblinkcmp_fuzzy.so" ]] || [[ -f "$BLINK_PATH/target/release/libblinkcmp_fuzzy.dylib" ]]; then
        ok "blink.cmp Rust library already compiled"
    else
        log "Installing Rust and compiling blink.cmp library..."
        # Install Rust temporarily if not present
        if ! command -v cargo &>/dev/null; then
            log "Installing Rust via rustup..."
            if command -v curl &>/dev/null; then
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable 2>&1 || {
                    warn "Failed to install Rust - blink.cmp will use Lua fallback"
                }
            else
                warn "curl not available - cannot install Rust"
            fi
        fi
        
        # Source cargo env if it exists
        if [[ -f "$HOME/.cargo/env" ]]; then
            source "$HOME/.cargo/env"
        fi
        
        # Compile the library
        if command -v cargo &>/dev/null; then
            cd "$BLINK_PATH"
            log "Running cargo build --release..."
            if cargo build --release 2>&1; then
                if [[ -f "target/release/libblinkcmp_fuzzy.so" ]] || [[ -f "target/release/libblinkcmp_fuzzy.dylib" ]]; then
                    ok "blink.cmp Rust library compiled successfully"
                else
                    # Check for alternative library names
                    ls -la target/release/*.so target/release/*.dylib 2>/dev/null || true
                    warn "Cargo build succeeded but library not found"
                fi
            else
                warn "Cargo build failed - blink.cmp will use Lua fallback"
            fi
        else
            warn "Rust not available - blink.cmp will use Lua fallback"
        fi
    fi
else
    warn "blink.cmp not found at $BLINK_PATH"
fi

# Verify LazyVim
if [[ -d "${NVIM_DATA}/lazy/LazyVim" ]]; then
    ok "LazyVim installed"
else
    fail "LazyVim NOT found"
fi

# Verify iron.nvim
if [[ -d "${NVIM_DATA}/lazy/iron.nvim" ]]; then
    ok "iron.nvim installed"
else
    warn "iron.nvim NOT found"
fi

log "Step 5c: Compile fzf-native for telescope..."
# telescope-fzf-native requires compilation for performance
FZF_NATIVE_PATH="${NVIM_DATA}/lazy/telescope-fzf-native.nvim"
if [[ -d "$FZF_NATIVE_PATH" ]]; then
    if [[ -f "$FZF_NATIVE_PATH/build/libfzf.so" ]] || [[ -f "$FZF_NATIVE_PATH/build/libfzf.dylib" ]]; then
        ok "fzf-native already compiled"
    else
        log "Compiling fzf-native..."
        cd "$FZF_NATIVE_PATH"
        make clean 2>/dev/null || true
        make 2>&1 | head -20
        if [[ -f "build/libfzf.so" ]] || [[ -f "build/libfzf.dylib" ]]; then
            ok "fzf-native compiled successfully"
        else
            warn "Failed to compile fzf-native - telescope will use slower fallback"
        fi
    fi
else
    warn "telescope-fzf-native.nvim not found"
fi

log "Step 6: Create bundles..."

# Main data bundle (plugins, mason packages)
tar -czf "${CACHE}/nvim-data.tar.gz" -C "$HOME/.local/share" nvim
ok "nvim-data.tar.gz ($(du -h "${CACHE}/nvim-data.tar.gz" | cut -f1))"

# Cache bundle (treesitter parsers, luac cache)
if [[ -d "$HOME/.cache/nvim" ]]; then
    tar -czf "${CACHE}/nvim-cache.tar.gz" -C "$HOME/.cache" nvim 2>/dev/null || true
    if [[ -f "${CACHE}/nvim-cache.tar.gz" ]]; then
        ok "nvim-cache.tar.gz ($(du -h "${CACHE}/nvim-cache.tar.gz" | cut -f1))"
    fi
fi

# State bundle (Mason registry, lazy state)
if [[ -d "$HOME/.local/state/nvim" ]]; then
    tar -czf "${CACHE}/nvim-state.tar.gz" -C "$HOME/.local/state" nvim 2>/dev/null || true
    if [[ -f "${CACHE}/nvim-state.tar.gz" ]]; then
        ok "nvim-state.tar.gz ($(du -h "${CACHE}/nvim-state.tar.gz" | cut -f1))"
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                   SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Plugins:           $PLUGIN_COUNT"
echo "  Mason packages:     $MASON_COUNT"
echo "  Treesitter parsers: $PARSER_COUNT"
echo "  .cloning files:     $CLONING_COUNT"
echo ""
ls -lh "${CACHE}"/nvim-*.tar.gz 2>/dev/null
echo ""
echo "════════════════════════════════════════════════════════════════"

if [[ $MASON_COUNT -lt 8 ]] || [[ $CLONING_COUNT -gt 0 ]]; then
    echo ""
    warn "Some packages may be incomplete. Review the output above."
    echo ""
fi

echo "Next steps:"
echo "  1. Verify nvim-data.tar.gz contains all expected packages"
echo "  2. Copy to airgap/cache/ in the bundle"
echo "  3. Docker build -f Dockerfile.airgap-final -t airgap-dev ."
