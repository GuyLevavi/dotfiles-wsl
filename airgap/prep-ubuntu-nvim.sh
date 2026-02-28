#!/usr/bin/env bash
# prep-ubuntu-nvim.sh — Generate nvim data bundle for Ubuntu 24.04
# This creates nvim-data.tar.gz by setting up nvim with all plugins,
# compiling blink.cmp, fzf-native, and treesitter parsers.
#
# Usage:
#   ./prep-ubuntu-nvim.sh              # Run locally
#   docker run -v $(pwd):/output ubuntu:24.04 bash -c 'apt-get update && apt-get install -y docker-cli && ./prep-ubuntu-nvim.sh'
#
# Output: airgap/cache/nvim-data.tar.gz
#
# This script is used by CI to build nvim-data as part of the full bundle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"
mkdir -p "$CACHE"

log()  { echo "==> $*"; }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*" >&2; }

# Detect if running in Docker
IN_DOCKER=false
if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
    IN_DOCKER=true
fi

log "Building nvim data for Ubuntu 24.04"
log "Running in Docker: $IN_DOCKER"

# Create a test user if running as root (Docker)
if [[ $(id -u) == 0 ]] && ! $IN_DOCKER; then
    warn "Running as root - will create 'testuser' for nvim operations"
    CREATE_USER=true
elif [[ $(id -u) == 0 ]] && $IN_DOCKER; then
    CREATE_USER=true
    USER_NAME="testuser"
else
    CREATE_USER=false
    USER_NAME="${USER:-$(whoami)}"
fi

# Build directories
if $CREATE_USER; then
    USER_NAME="${USER_NAME:-testuser}"
    BUILD_HOME="/home/${USER_NAME}"
    if ! id "$USER_NAME" &>/dev/null; then
        log "Creating user: $USER_NAME"
        useradd --create-home --shell /bin/bash "$USER_NAME"
    fi
    chown -R "$USER_NAME:$USER_NAME" "$BUILD_HOME"
else
    BUILD_HOME="${HOME}"
fi

# Ensure build directories exist
mkdir -p "${BUILD_HOME}/.local/bin"
mkdir -p "${BUILD_HOME}/.local/share"
mkdir -p "${BUILD_HOME}/.config"
mkdir -p "${BUILD_HOME}/.cache"
mkdir -p "${BUILD_HOME}/.local/state"

# Install build dependencies (if apt-get available)
if command -v apt-get &>/dev/null; then
    log "Installing build dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends \
        curl git gcc make nodejs npm ca-certificates \
        2>/dev/null || warn "Some packages failed to install"
fi

# Install Rust if not present (needed for blink.cmp)
# Use specific version 1.82.0 for compatibility with frizbee (blink.cmp's fuzzy matcher)
RUST_VERSION="1.82.0"
if ! command -v cargo &>/dev/null; then
    log "Installing Rust ${RUST_VERSION}..."
    if command -v curl &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "${RUST_VERSION}" 2>/dev/null || {
            warn "Failed to install Rust - blink.cmp will use Lua fallback"
        }
    fi
elif command -v rustup &>/dev/null; then
    log "Installing Rust ${RUST_VERSION}..."
    rustup install "${RUST_VERSION}" 2>/dev/null || warn "Failed to install Rust ${RUST_VERSION}"
    rustup default "${RUST_VERSION}" 2>/dev/null || true
fi

# Source cargo env if installed
if [[ -f "${BUILD_HOME}/.cargo/env" ]]; then
    source "${BUILD_HOME}/.cargo/env"
fi

# Set environment variables
export HOME="$BUILD_HOME"
export PATH="${BUILD_HOME}/.local/bin:$PATH"
export XDG_CONFIG_HOME="${BUILD_HOME}/.config"
export XDG_DATA_HOME="${BUILD_HOME}/.local/share"
export XDG_CACHE_HOME="${BUILD_HOME}/.cache"
export XDG_STATE_HOME="${BUILD_HOME}/.local/state"

# Download and set up Neovim
NVIM_VERSION="0.11.2"
if ! command -v nvim &>/dev/null; then
    log "Downloading Neovim ${NVIM_VERSION}..."
    mkdir -p "${BUILD_HOME}/.local/bin"
    curl -fSL --retry 3 -o "${BUILD_HOME}/.local/bin/nvim.appimage" \
        "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-x86_64.appimage"
    chmod +x "${BUILD_HOME}/.local/bin/nvim.appimage"
    
    # Create wrapper script
    cat > "${BUILD_HOME}/.local/bin/nvim" << 'WRAPPER'
#!/usr/bin/env bash
NVIM_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
exec "${NVIM_DIR}/nvim.appimage" --appimage-extract-and-run "$@"
WRAPPER
    chmod +x "${BUILD_HOME}/.local/bin/nvim"
fi

ok "Neovim ready: $(nvim --version | head -1)"

# Clone dotfiles and stow nvim config
if [[ ! -d "${BUILD_HOME}/.config/nvim" ]]; then
    log "Cloning dotfiles and stowing nvim..."
    TEMP_DOTFILES=$(mktemp -d)
    git clone --depth 1 https://github.com/GuyLevavi/dotfiles-wsl.git "$TEMP_DOTFILES"
    cd "$TEMP_DOTFILES"
    
    # Stow nvim
    if command -v stow &>/dev/null; then
        stow -v -t "$BUILD_HOME" nvim 2>/dev/null || true
    else
        # Manual copy if stow not available
        mkdir -p "${BUILD_HOME}/.config/nvim"
        cp -r nvim/.config/nvim/* "${BUILD_HOME}/.config/nvim/"
    fi
    
    rm -rf "$TEMP_DOTFILES"
fi

ok "Nvim config ready"

# Check nvim minimum version
NVIM_VER=$(nvim --version | head -1 | grep -oP 'v\K[0-9.]+')
if [[ "$(printf '%s\n' "0.11.2" "$NVIM_VER" | sort -V | head -n1)" != "0.11.2" ]]; then
    warn "LazyVim requires Neovim >= 0.11.2, you have $NVIM_VER"
fi

# Ensure XDG directories exist for nvim
mkdir -p "${XDG_DATA_HOME}/nvim/lazy"
mkdir -p "${XDG_CACHE_HOME}/nvim"
mkdir -p "${XDG_STATE_HOME}/nvim"

# Check for tree-sitter-cli
if ! command -v tree-sitter &>/dev/null; then
    log "Installing tree-sitter-cli..."
    if command -v npm &>/dev/null; then
        npm install -g tree-sitter-cli 2>/dev/null || warn "Failed to install tree-sitter-cli"
    fi
fi

# Bootstrap lazy.nvim
LAZY_PATH="${XDG_DATA_HOME}/nvim/lazy/lazy.nvim"
if [[ ! -d "$LAZY_PATH" ]]; then
    log "Bootstrapping lazy.nvim..."
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable "$LAZY_PATH"
fi
ok "lazy.nvim ready"

# Sync all lazy plugins
log "Syncing lazy plugins (this may take a few minutes)..."
nvim --headless -c "lua require('lazy').sync({wait=true})" -c "qa" 2>&1 || {
    warn "Lazy sync had issues, continuing..."
}
PLUGIN_COUNT=$(ls "${XDG_DATA_HOME}/nvim/lazy/" 2>/dev/null | wc -l)
ok "Lazy plugins: $PLUGIN_COUNT"

# Install Mason packages via mason-tool-installer
log "Installing Mason packages..."
nvim --headless -c "sleep 3" -c "MasonToolsInstallSync" -c "qa" 2>&1 || {
    warn "MasonToolsInstallSync had issues"
}
sleep 5
MASON_COUNT=$(ls "${XDG_DATA_HOME}/nvim/mason/packages/" 2>/dev/null | wc -l)
ok "Mason packages: $MASON_COUNT}"

# Install treesitter parsers
log "Installing treesitter parsers..."
PARSERS="python lua bash dockerfile json jsonc yaml toml markdown markdown_inline html css vim vimdoc regex gitcommit gitignore git_rebase diff helm requirements"
for parser in $PARSERS; do
    echo -n "  $parser... "
    nvim --headless -c "TSInstallSync $parser" -c "qa" 2>/dev/null && echo "✓" || echo "!"
done
nvim --headless -c "TSUpdateSync" -c "qa" 2>/dev/null || true
PARSER_COUNT=$(find "${XDG_DATA_HOME}/nvim/site/parser/" -name "*.so" 2>/dev/null | wc -l)
ok "Treesitter parsers: $PARSER_COUNT"

# Compile blink.cmp Rust library
BLINK_PATH="${XDG_DATA_HOME}/nvim/lazy/blink.cmp"
if [[ -d "$BLINK_PATH" ]]; then
    if [[ -f "$BLINK_PATH/target/release/libblinkcmp_fuzzy.so" ]] || [[ -f "$BLINK_PATH/target/release/libblinkcmp_fuzzy.dylib" ]]; then
        ok "blink.cmp Rust library already compiled"
    else
        log "Compiling blink.cmp Rust library..."
        if command -v cargo &>/dev/null; then
            cd "$BLINK_PATH"
            if cargo build --release 2>&1; then
                ok "blink.cmp compiled successfully"
            else
                warn "blink.cmp compilation failed - using Lua fallback"
            fi
        else
            warn "Rust not available - blink.cmp using Lua fallback"
        fi
    fi
fi

# Compile fzf-native for telescope
FZF_PATH="${XDG_DATA_HOME}/nvim/lazy/telescope-fzf-native.nvim"
if [[ -d "$FZF_PATH" ]]; then
    if [[ -f "$FZF_PATH/build/libfzf.so" ]] || [[ -f "$FZF_PATH/build/libfzf.dylib" ]]; then
        ok "fzf-native already compiled"
    else
        log "Compiling fzf-native..."
        cd "$FZF_PATH"
        make clean 2>/dev/null || true
        if make 2>&1; then
            ok "fzf-native compiled"
        else
            warn "fzf-native compilation failed"
        fi
    fi
fi

# Create bundles
log "Creating nvim data bundles..."

# Main data bundle
tar -czf "${CACHE}/nvim-data.tar.gz" -C "$BUILD_HOME/.local/share" nvim
ok "nvim-data.tar.gz ($(du -h "${CACHE}/nvim-data.tar.gz" | cut -f1))"

# Cache bundle (optional)
if [[ -d "${BUILD_HOME}/.cache/nvim" ]]; then
    tar -czf "${CACHE}/nvim-cache.tar.gz" -C "$BUILD_HOME/.cache" nvim 2>/dev/null || true
    [[ -f "${CACHE}/nvim-cache.tar.gz" ]] && ok "nvim-cache.tar.gz"
fi

# State bundle (optional)
if [[ -d "${BUILD_HOME}/.local/state/nvim" ]]; then
    tar -czf "${CACHE}/nvim-state.tar.gz" -C "$BUILD_HOME/.local/state" nvim 2>/dev/null || true
    [[ -f "${CACHE}/nvim-state.tar.gz" ]] && ok "nvim-state.tar.gz"
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "                   SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  Plugins:           $PLUGIN_COUNT"
echo "  Mason packages:    $MASON_COUNT"
echo "  Treesitter:        $PARSER_COUNT"
echo ""
ls -lh "${CACHE}"/nvim-*.tar.gz 2>/dev/null
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Next: bash airgap/bundle.sh  # Combines with CLI tools"
