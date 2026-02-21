#!/usr/bin/env bash
set -euo pipefail
# deploy.sh — Deploy dev environment from an airgap bundle tarball
#
# This script uses TWO locations:
#   1. REPO_ROOT — the dotfiles repo (where this script lives), provides
#      bootstrap scripts and stow packages.
#   2. The bundle tarball — provides pre-downloaded binaries and plugins
#      in a cache/ directory.
#
# Usage: sudo ./deploy.sh [--user USER] [--force] [BUNDLE.tar.gz]

# ===== Args =====
TARGET_USER="" FORCE=false BUNDLE_PATH=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)  TARGET_USER="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --help|-h) echo "Usage: sudo $0 [--user USER] [--force] [BUNDLE.tar.gz]"; exit 0 ;;
        -*) echo "Unknown: $1" >&2; exit 1 ;;
        *)  BUNDLE_PATH="$1"; shift ;;
    esac
done
[[ -z "$TARGET_USER" ]] && TARGET_USER="${SUDO_USER:-${USER:-dev}}"

log()  { echo "==> $*"; }
ok()   { echo "  + $*"; }
warn() { echo "  ! $*" >&2; }
die()  { echo "ERROR: $*" >&2; exit 1; }

run_as_user() {
    if [[ "$(id -u)" -eq 0 && "$TARGET_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" -H -- "$@"
    else
        "$@"
    fi
}
USER_HOME="$(eval echo "~${TARGET_USER}")"

# ===== Locate repo root =====
# deploy.sh lives at <repo>/airgap/deploy.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sanity check: bootstrap scripts must exist in the repo
[[ -f "$REPO_ROOT/bootstrap/03-install-tools.sh" ]] \
    || die "Cannot find bootstrap scripts. Run deploy.sh from the dotfiles repo."

# ===== Find and extract bundle =====
if [[ -z "$BUNDLE_PATH" ]]; then
    BUNDLE_PATH="$(ls -t "$SCRIPT_DIR"/devenv-bundle-*.tar.gz 2>/dev/null | head -1)" \
        || die "No devenv-bundle-*.tar.gz found in $SCRIPT_DIR. Pass the path explicitly."
    [[ -n "$BUNDLE_PATH" ]] || die "No bundle found."
    log "Auto-detected: $BUNDLE_PATH"
fi
[[ -f "$BUNDLE_PATH" ]] || die "Not found: $BUNDLE_PATH"

EXTRACT_DIR="$(mktemp -d /tmp/devenv-deploy.XXXXXX)"
chmod 755 "$EXTRACT_DIR"  # allow target user to read the extracted cache
trap 'rm -rf "$EXTRACT_DIR"; rm -f "$REPO_ROOT/airgap/cache"' EXIT
log "Extracting $BUNDLE_PATH ..."
tar -xzf "$BUNDLE_PATH" -C "$EXTRACT_DIR"

# Bundle tarball contains a cache/ directory — locate it
if [[ -d "$EXTRACT_DIR/cache" ]]; then
    CACHE="$EXTRACT_DIR/cache"
elif top="$(ls "$EXTRACT_DIR")" && [[ "$(echo "$top" | wc -l)" -eq 1 && -d "$EXTRACT_DIR/$top" ]]; then
    CACHE="$EXTRACT_DIR/$top"
else
    die "Unexpected bundle layout — expected cache/ directory inside tarball"
fi

# Symlink cache into the repo so 03-install-tools.sh --offline can find it.
# Remove any existing cache dir first (e.g. if repo was copied with cache/).
rm -rf "$REPO_ROOT/airgap/cache"
ln -sfn "$CACHE" "$REPO_ROOT/airgap/cache"
chmod -R a+rX "$CACHE"  # ensure target user can read cache files
ok "Cache linked: $CACHE"

# ===== Backup existing configs if --force =====
is_update=false
for f in "$USER_HOME/.local/bin/nvim" "$USER_HOME/.zshrc" "$USER_HOME/.config/nvim"; do
    [[ -e "$f" ]] && { is_update=true; break; }
done

if $is_update && $FORCE; then
    backup="$USER_HOME/.dotfiles-backup/deploy-$(date +%Y%m%d-%H%M%S)"
    run_as_user mkdir -p "$backup"
    for f in .zshrc .zprofile .config/nvim .config/starship.toml .config/yazi .gitconfig; do
        [[ -e "$USER_HOME/$f" && ! -L "$USER_HOME/$f" ]] && {
            mkdir -p "$backup/$(dirname "$f")"
            cp -a "$USER_HOME/$f" "$backup/$f"
        }
    done
    ok "Backed up to $backup"
elif $is_update && ! $FORCE; then
    warn "Existing install detected. Use --force to overwrite (backups created automatically)."
fi

# ===== Step 1: Create user =====
log "Step 1/5: User setup"
if [[ "$(id -u)" -eq 0 ]] && ! id "$TARGET_USER" &>/dev/null; then
    [[ -f "$REPO_ROOT/bootstrap/01-create-user.sh" ]] && bash "$REPO_ROOT/bootstrap/01-create-user.sh" "$TARGET_USER"
    ok "User $TARGET_USER created"
else
    ok "User $TARGET_USER exists"
fi

# ===== Step 2: System packages =====
log "Step 2/5: System packages"
if [[ "$(id -u)" -eq 0 && -f "$REPO_ROOT/bootstrap/02-install-packages.sh" ]]; then
    bash "$REPO_ROOT/bootstrap/02-install-packages.sh" --minimal 2>&1 || warn "DNF failed (expected without local repo)"
else
    warn "Skipping DNF (not root or script missing)"
fi

# ===== Step 3: CLI tools (offline) =====
log "Step 3/5: CLI tools"
[[ -d "$CACHE" ]] || die "Cache not found: $CACHE"
run_as_user bash "$REPO_ROOT/bootstrap/03-install-tools.sh" --offline
ok "CLI tools installed"

# ===== Step 4: Stow dotfiles =====
log "Step 4/5: Dotfiles"
if $is_update && ! $FORCE; then
    warn "Skipping stow (use --force)"
elif [[ -f "$REPO_ROOT/bootstrap/04-stow-dotfiles.sh" ]] && command -v stow &>/dev/null; then
    run_as_user bash "$REPO_ROOT/bootstrap/04-stow-dotfiles.sh"
    ok "Dotfiles stowed"
else
    warn "Skipping (stow missing or script not found)"
fi

# ===== Step 5: Shell setup (zsh, zinit, plugins) =====
log "Step 5/5: Shell setup"

# Set default shell to zsh
if command -v zsh &>/dev/null; then
    zsh_path="$(command -v zsh)"
    current="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7 || true)"
    if [[ "$current" != "$zsh_path" && "$(id -u)" -eq 0 ]]; then
        chsh -s "$zsh_path" "$TARGET_USER"
        ok "Shell set to zsh"
    fi
fi

# XDG dirs
for d in .config .cache .local/bin .local/share .local/state; do
    run_as_user mkdir -p "$USER_HOME/$d"
done

# Install zinit from cache
zinit_home="$USER_HOME/.local/share/zinit/zinit.git"
zinit_tar="$CACHE/zinit.tar.gz"
if [[ -f "$zinit_tar" && ( ! -d "$zinit_home" || "$FORCE" == true ) ]]; then
    rm -rf "$zinit_home"
    run_as_user mkdir -p "$(dirname "$zinit_home")"
    tmp="$(mktemp -d)"; chmod 755 "$tmp"; tar -xzf "$zinit_tar" -C "$tmp"
    chmod -R a+rX "$tmp"  # allow target user to read extracted files
    # Handle varying layouts (repo/ subdir from clone_shallow)
    if [[ -d "$tmp/repo" ]]; then
        run_as_user cp -a "$tmp/repo" "$zinit_home"
    else
        run_as_user mkdir -p "$zinit_home"
        run_as_user cp -a "$tmp"/* "$zinit_home/"
    fi
    rm -rf "$tmp"
    ok "zinit installed"
fi

# Install zsh plugins from cache
plugins_dir="$USER_HOME/.local/share/zinit/plugins"
run_as_user mkdir -p "$plugins_dir"
for plugin_tar in "$CACHE"/fast-syntax-highlighting.tar.gz "$CACHE"/zsh-autosuggestions.tar.gz "$CACHE"/zsh-completions.tar.gz; do
    [[ -f "$plugin_tar" ]] || continue
    name="$(basename "$plugin_tar" .tar.gz)"
    target="$plugins_dir/$name"
    if [[ ! -d "$target" || "$FORCE" == true ]]; then
        rm -rf "$target"
        tmp="$(mktemp -d)"; chmod 755 "$tmp"; tar -xzf "$plugin_tar" -C "$tmp"
        chmod -R a+rX "$tmp"
        [[ -d "$tmp/repo" ]] && run_as_user cp -a "$tmp/repo" "$target" \
            || { run_as_user mkdir -p "$target"; run_as_user cp -a "$tmp"/* "$target/"; }
        rm -rf "$tmp"
        ok "Plugin: $name"
    fi
done

# Deploy neovim plugin cache if present
nvim_data="$CACHE/nvim-data.tar.gz"
if [[ -f "$nvim_data" ]]; then
    log "Deploying neovim plugin cache..."
    run_as_user tar -xzf "$nvim_data" -C "$USER_HOME"
    ok "Neovim plugins deployed"
fi

# ===== Fix ownership =====
if [[ "$(id -u)" -eq 0 ]]; then
    group="$(id -gn "$TARGET_USER")"
    for d in .local .config .cache; do
        [[ -d "$USER_HOME/$d" ]] && chown -R "$TARGET_USER:$group" "$USER_HOME/$d"
    done
    for f in .zshrc .zprofile .gitconfig; do
        [[ -e "$USER_HOME/$f" || -L "$USER_HOME/$f" ]] && chown -h "$TARGET_USER:$group" "$USER_HOME/$f"
    done
    ok "Ownership fixed"
fi

# ===== Summary =====
echo ""
echo "Deployment complete for $TARGET_USER ($USER_HOME)"
echo "  1. Log in: su - $TARGET_USER"
echo "  2. Shell is zsh with starship prompt"
echo "  3. Run 'nvim' to verify LazyVim"
echo "  4. Run 'tmux' for multiplexer"
