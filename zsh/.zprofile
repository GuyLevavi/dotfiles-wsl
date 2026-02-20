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
