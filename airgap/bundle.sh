#!/usr/bin/env bash
set -euo pipefail
# bundle.sh — Download everything needed for airgap deployment into a tarball
# Usage: ./bundle.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"

# Source pinned versions (the guard in 03-install-tools.sh prevents execution)
# shellcheck source=../bootstrap/03-install-tools.sh
source "${SCRIPT_DIR}/../bootstrap/03-install-tools.sh"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log()  { echo "==> $*"; }
ok()   { echo "  + $*"; }
skip() { echo "  . $* (cached)"; }

# download URL FILENAME — fetch into cache, skip if exists
download() {
    local url="$1" file="$2" dest="${CACHE}/$2"
    if $DRY_RUN; then
        [[ -f "$dest" ]] && skip "$file" || echo "  ~ [dry] $file"
        return
    fi
    [[ -f "$dest" ]] && { skip "$file"; return; }
    curl -fSL --retry 3 -o "$dest" "$url" && ok "$file"
}

# clone_shallow REPO TARBALL — shallow clone, tar, cache
clone_shallow() {
    local repo="$1" tarball="$2" dest="${CACHE}/$2"
    if $DRY_RUN; then
        [[ -f "$dest" ]] && skip "$tarball" || echo "  ~ [dry] $tarball"
        return
    fi
    [[ -f "$dest" ]] && { skip "$tarball"; return; }
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 "$repo" "$tmp/repo"
    tar -czf "$dest" -C "$tmp" repo && rm -rf "$tmp"
    ok "$tarball"
}

# ===== Pre-flight =====
for cmd in curl git tar; do
    command -v "$cmd" &>/dev/null || { echo "ERROR: $cmd not found"; exit 1; }
done
$DRY_RUN || mkdir -p "$CACHE"

echo "bundle.sh — mode: $($DRY_RUN && echo DRY-RUN || echo LIVE)"
echo ""

# ===== Tool binaries =====
log "Tool binaries"
download "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" starship.tar.gz
download "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" zoxide.tar.gz
download "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" fzf.tar.gz
download "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz" bat.tar.gz
download "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" eza.tar.gz
download "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" ripgrep.tar.gz
download "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" fd.tar.gz
download "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip" yazi.zip
download "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" lazygit.tar.gz
download "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" uv.tar.gz
download "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz" glab.tar.gz
download "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/${JFROG_CLI_VERSION}/jfrog-cli-linux-amd64/jf" jf
download "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" delta.tar.gz
download "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-x86_64.appimage" nvim.appimage
download "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" helm.tar.gz
download "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OC_VERSION}/openshift-client-linux.tar.gz" oc.tar.gz

# ===== Zsh plugins =====
echo ""
log "Zsh plugins"
clone_shallow "https://github.com/zdharma-continuum/zinit.git" zinit.tar.gz
clone_shallow "https://github.com/zdharma-continuum/fast-syntax-highlighting.git" fast-syntax-highlighting.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-autosuggestions.git" zsh-autosuggestions.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-completions.git" zsh-completions.tar.gz

# ===== Neovim plugins (manual step) =====
echo ""
log "Neovim plugins"
if [[ -f "${CACHE}/nvim-data.tar.gz" ]]; then
    ok "nvim-data.tar.gz found"
else
    echo "  ! nvim-data.tar.gz not in cache — lazy.nvim will need connectivity on first launch"
    echo "  ! To fix: run nvim online, then tar ~/.local/{share,state}/nvim into nvim-data.tar.gz"
fi

# ===== versions.lock =====
if ! $DRY_RUN; then
    cat > "${CACHE}/versions.lock" <<EOF
# versions.lock — generated $(date -u '+%Y-%m-%dT%H:%M:%SZ')
starship        ${STARSHIP_VERSION}
zoxide          ${ZOXIDE_VERSION}
fzf             ${FZF_VERSION}
bat             ${BAT_VERSION}
eza             ${EZA_VERSION}
ripgrep         ${RIPGREP_VERSION}
fd              ${FD_VERSION}
yazi            ${YAZI_VERSION}
lazygit         ${LAZYGIT_VERSION}
uv              ${UV_VERSION}
glab            ${GLAB_VERSION}
jfrog-cli       ${JFROG_CLI_VERSION}
delta           ${DELTA_VERSION}
neovim          ${NEOVIM_VERSION}
helm            ${HELM_VERSION}
oc              ${OC_VERSION}
marimo          ${MARIMO_VERSION}
EOF
    ok "versions.lock"
fi

# ===== Create tarball =====
echo ""
if $DRY_RUN; then
    echo "Dry run complete — no tarball created."
else
    bundle="devenv-bundle-$(date '+%Y%m%d').tar.gz"
    tar -czf "${SCRIPT_DIR}/${bundle}" -C "$SCRIPT_DIR" cache
    size="$(du -h "${SCRIPT_DIR}/${bundle}" | cut -f1)"
    echo "Bundle: ${bundle} (${size})"
    echo "Transfer to airgapped host, extract, then run: ./bootstrap/03-install-tools.sh --offline"
fi
