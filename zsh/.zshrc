# =============================================================================
#  .zshrc - Interactive shell configuration
#  Tailored for Python CV/ML development with modern CLI tools
# =============================================================================

# -----------------------------------------------------------------------------
#  History
# -----------------------------------------------------------------------------
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY          # share history across sessions
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries
setopt HIST_IGNORE_SPACE      # don't record commands starting with a space
setopt HIST_REDUCE_BLANKS     # trim unnecessary blanks

# -----------------------------------------------------------------------------
#  Performance: disable slow features on /mnt/c (Windows filesystem)
# -----------------------------------------------------------------------------
# The Windows 9p mount (/mnt/c) is ~10-50x slower than native ext4.
# Disable expensive operations when the cwd is on the Windows mount.
__is_slow_fs() { [[ "$PWD" == /mnt/* ]]; }

# -----------------------------------------------------------------------------
#  Zinit plugin manager (auto-install if missing)
# -----------------------------------------------------------------------------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

if [[ ! -d "$ZINIT_HOME" ]]; then
    print -P "%F{yellow}Installing zinit...%f"
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" 2>/dev/null || \
        print -P "%F{red}zinit install failed - plugins will be unavailable%f"
fi

if [[ -d "$ZINIT_HOME" ]]; then
    source "${ZINIT_HOME}/zinit.zsh"

    # Plugins (turbo-loaded for faster shell startup)
    # NOTE: For offline/airgapped environments, pre-cache these plugins by running
    #   zinit update --all
    # once while connected. Zinit stores them in $ZINIT_HOME/../plugins/
    zinit light-mode wait lucid for \
        atinit"zicompinit; zicdreplay" \
            zdharma-continuum/fast-syntax-highlighting \
        atload"_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions \
        blockf atpull"zinit creinstall -q ." \
            zsh-users/zsh-completions

    # fzf-tab: replaces zsh's default completion menu with fzf
    # This makes tab-completion fast and fuzzy instead of doing slow dir scans
    zinit light-mode wait lucid for \
        Aloxaf/fzf-tab
fi

# -----------------------------------------------------------------------------
#  Completions
# -----------------------------------------------------------------------------
autoload -Uz compinit

# Only regenerate completion dump once a day (skip the slow stat check)
if [[ -z "${ZDOTDIR:-}" ]]; then
    _comp_dump="$HOME/.zcompdump"
else
    _comp_dump="$ZDOTDIR/.zcompdump"
fi
if [[ ! -f "$_comp_dump" ]] || [[ $(date +'%j') != $(date -r "$_comp_dump" +'%j' 2>/dev/null) ]]; then
    compinit -d "$_comp_dump"
else
    compinit -C -d "$_comp_dump"  # -C = skip security check (faster)
fi
unset _comp_dump

zstyle ':completion:*' menu select                          # menu-driven completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive matching
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"     # colored completions
zstyle ':completion:*' special-dirs true                    # complete . and ..
zstyle ':completion:*' use-cache on                         # cache expensive completions
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/compcache"

# fzf-tab settings (loaded via zinit above)
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath 2>/dev/null'
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse

# -----------------------------------------------------------------------------
#  Key bindings — vim mode + intuitive navigation keys
# -----------------------------------------------------------------------------
# Vim mode: press Escape to enter normal mode, i/a to return to insert mode.
# This trains the same muscle memory you're building in Neovim.
bindkey -v

# Reduce mode-switch delay from 0.4s to 0.1s (makes Escape feel instant)
export KEYTIMEOUT=10

# Standard navigation keys that "just work" in both insert and normal mode.
# Without these, Home/End/Delete break in vim mode.
bindkey '^[[H'    beginning-of-line     # Home
bindkey '^[[F'    end-of-line           # End
bindkey '^[[3~'   delete-char           # Delete
bindkey '^[[1;5C' forward-word          # Ctrl+Right — jump word forward
bindkey '^[[1;5D' backward-word         # Ctrl+Left  — jump word backward
bindkey '^H'      backward-delete-word  # Ctrl+Backspace — delete word backward
bindkey '^W'      backward-kill-word    # Ctrl+W — same as above (common muscle memory)

# History search with Up/Down arrows (works in both modes)
bindkey '^[[A' history-beginning-search-backward  # Up
bindkey '^[[B' history-beginning-search-forward   # Down

# These also work in vicmd (normal) mode
bindkey -M vicmd '^[[H'  beginning-of-line
bindkey -M vicmd '^[[F'  end-of-line
bindkey -M vicmd '^[[3~' delete-char
bindkey -M vicmd 'k'     history-beginning-search-backward
bindkey -M vicmd 'j'     history-beginning-search-forward

# -----------------------------------------------------------------------------
#  Tool integrations (guarded so nothing breaks if a tool is missing)
# -----------------------------------------------------------------------------

# Starship prompt
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide (smarter cd)
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# fzf key-bindings and completion
if command -v fzf &>/dev/null; then
    # fzf >= 0.48 ships a built-in setup command
    if [[ "$(fzf --version 2>/dev/null | cut -d. -f1-2)" > "0.47" ]]; then
        source <(fzf --zsh 2>/dev/null)
    else
        for f in /usr/share/fzf/key-bindings.zsh \
                 /usr/share/fzf/shell/key-bindings.zsh \
                 "${XDG_DATA_HOME:-$HOME/.local/share}/fzf/key-bindings.zsh"; do
            [[ -f "$f" ]] && source "$f" && break
        done
        for f in /usr/share/fzf/completion.zsh \
                 /usr/share/fzf/shell/completion.zsh \
                 "${XDG_DATA_HOME:-$HOME/.local/share}/fzf/completion.zsh"; do
            [[ -f "$f" ]] && source "$f" && break
        done
    fi

    # Use fd for fzf file search (fast, respects .gitignore)
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

    # Tokyo Night colors for fzf (matches WezTerm + nvim colorscheme)
    export FZF_DEFAULT_OPTS=" \
        --color=bg+:#292e42,bg:#1a1b26,spinner:#bb9af7,hl:#7aa2f7 \
        --color=fg:#c0caf5,header:#7aa2f7,info:#7dcfff,pointer:#bb9af7 \
        --color=marker:#9ece6a,fg+:#c0caf5,prompt:#7dcfff,hl+:#7aa2f7 \
        --color=selected-bg:#364a82 \
        --border --layout=reverse --height=40%"
fi

# bat theme
if command -v bat &>/dev/null; then
    # NOTE: bat doesn't ship a Tokyo Night theme by default.
    # Use "Visual Studio Dark+" (closest built-in) or install a custom theme:
    #   mkdir -p ~/.config/bat/themes && cd ~/.config/bat/themes
    #   curl -LO https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme
    #   bat cache --build
    # Then change this to: export BAT_THEME="tokyonight_night"
    export BAT_THEME="Visual Studio Dark+"
fi

# -----------------------------------------------------------------------------
#  Aliases
# -----------------------------------------------------------------------------

# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ll="eza -la --icons --git"
alias la="eza -a --icons"
alias lt="eza --tree --level=2 --icons"
alias ls="eza --icons"

# File viewing
alias cat="bat --paging=never"
alias catp="bat"  # with paging

# Git shortcuts
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline --graph --decorate -20"
alias gd="git diff"
alias lg="lazygit"

# Python / uv
alias py="python3"
alias pip="uv pip"
alias venv="uv venv"
alias uvr="uv run"

# Container
alias pd="podman"
alias pdr="podman run"
alias pdi="podman images"
alias pdc="podman ps"

# Editor
alias v="nvim"
alias vi="nvim"
alias vim="nvim"

# Yazi - cd to directory on exit
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Kubernetes / OpenShift
alias k="kubectl"
alias kgp="kubectl get pods"
alias oc="oc"
alias hm="helm"

# -----------------------------------------------------------------------------
#  Environment variables
# -----------------------------------------------------------------------------
export PYTHONDONTWRITEBYTECODE=1   # don't litter .pyc files
export UV_LINK_MODE=copy           # better compatibility inside containers
