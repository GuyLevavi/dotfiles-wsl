# .zprofile - runs on login shells only
# Sets up environment variables that should be inherited by all child processes.
# For interactive shell config (aliases, prompt, etc.), see .zshrc

# --- PATH ---
typeset -U path
path=(
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    $path
)
export PATH

# --- Default programs ---
export EDITOR="nvim"
export VISUAL="nvim"

# --- XDG Base Directories ---
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# --- uv: prevent auto-downloading Python in airgapped environments ---
export UV_PYTHON_DOWNLOADS=manual

# --- zig cc: standalone C compiler for treesitter and Python libs ---
export CC="${HOME}/.local/bin/zig"
export CXX="${HOME}/.local/bin/zig"
# Use zig cc wrapper for C compilation (no system deps needed)
alias cc="zig cc"
alias c++="zig c++"
export CFLAGS=""
export LDFLAGS=""
