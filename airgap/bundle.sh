#!/usr/bin/env bash
set -euo pipefail
# bundle.sh — Download everything needed for airgap deployment into a tarball
# Usage: ./bundle.sh [--dry-run]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"

# Source pinned versions (the guard in 03-install-tools.sh prevents execution)
# shellcheck source=../bootstrap/03-install-tools.sh
source "${SCRIPT_DIR}/../bootstrap/03-install-tools.sh"

# Resolve versions now (bundle.sh is executed, not sourced)
resolve_versions

# Debug: print tool versions
echo ""
echo "DEBUG: Tool versions after resolve:"
echo "  K9S_VERSION=${K9S_VERSION:-unset}"
echo "  LAZYDOCKER_VERSION=${LAZYDOCKER_VERSION:-unset}"
echo "  BTOP_VERSION=${BTOP_VERSION:-unset}"
echo ""

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log()  { echo "==> $*"; }
ok()   { echo "  + $*"; }
skip() { echo "  . $* (cached)"; }
warn() { echo "  ! $*" >&2; }

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
download "https://github.com/fastfetch-cli/fastfetch/releases/download/${FASTFETCH_VERSION}/fastfetch-linux-amd64.tar.gz" fastfetch.tar.gz
download "https://dl.min.io/client/mc/release/linux-amd64/archive/mc.${MC_VERSION}" mc

# New TUI tools
download "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_linux_amd64.tar.gz" k9s.tar.gz
download "https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz" lazydocker.tar.gz
download "https://github.com/aristocratos/btop/releases/download/v${BTOP_VERSION}/btop-x86_64-linux.tbz" btop.tbz
download "https://github.com/tstack/lnav/releases/download/v${LNAV_VERSION}/lnav-${LNAV_VERSION}-x86_64-linux-musl.zip" lnav.zip
download "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_Linux_x86_64.tar.gz" glow.tar.gz

# Zig C compiler
download "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" zig.tar.xz

# ===== System packages (RPMs or DEBs depending on host distro) =====
# Download RUNTIME_PKGS so they can be installed offline.
# Must be run on the target distro family (Fedora/RHEL for RPMs, Ubuntu/Debian for DEBs).
echo ""
log "System packages"

# Detect host distro
source /etc/os-release 2>/dev/null || true
case "${ID:-}" in
    ubuntu|debian) HOST_PKG_MGR=apt ;;
    fedora|rhel|centos|almalinux|rocky) HOST_PKG_MGR=dnf ;;
    *)
        if command -v dnf &>/dev/null; then HOST_PKG_MGR=dnf
        elif command -v apt-get &>/dev/null; then HOST_PKG_MGR=apt
        else HOST_PKG_MGR=unknown
        fi ;;
esac

# RPM packages (Fedora/RHEL names)
RUNTIME_PKGS_RPM=(
    curl wget unzip tar gzip bzip2 xz which file tree htop procps-ng
    zsh tmux stow git git-lfs gawk
    nodejs npm
    podman buildah skopeo fuse-overlayfs
    python3-devel python3-pip
    jq ShellCheck
)

# DEB packages (Ubuntu/Debian name equivalents)
RUNTIME_PKGS_DEB=(
    curl wget unzip tar gzip bzip2 xz-utils file tree htop procps
    zsh tmux stow git git-lfs gawk
    nodejs npm
    podman buildah skopeo fuse-overlayfs
    python3-dev python3-pip
    jq shellcheck
)

if [[ "$HOST_PKG_MGR" == "dnf" ]]; then
    RPM_DIR="${CACHE}/rpms"
    if $DRY_RUN; then
        if [[ -d "$RPM_DIR" && "$(ls -A "$RPM_DIR" 2>/dev/null)" ]]; then
            skip "rpms/ ($(ls "$RPM_DIR"/*.rpm 2>/dev/null | wc -l) RPMs cached)"
        else
            echo "  ~ [dry] rpms/ (${#RUNTIME_PKGS_RPM[@]} packages to download)"
        fi
    else
        if [[ -d "$RPM_DIR" && "$(ls -A "$RPM_DIR" 2>/dev/null)" ]]; then
            skip "rpms/ ($(ls "$RPM_DIR"/*.rpm 2>/dev/null | wc -l) RPMs)"
        else
            mkdir -p "$RPM_DIR"
            echo "  Downloading RPMs (this may take a minute)..."
            dnf download --resolve --alldeps --destdir="$RPM_DIR" "${RUNTIME_PKGS_RPM[@]}" 2>&1 \
                | tail -1
            ok "rpms/ ($(ls "$RPM_DIR"/*.rpm 2>/dev/null | wc -l) RPMs)"
        fi
    fi

elif [[ "$HOST_PKG_MGR" == "apt" ]]; then
    DEB_DIR="${CACHE}/debs"
    if $DRY_RUN; then
        if [[ -d "$DEB_DIR" && "$(ls -A "$DEB_DIR" 2>/dev/null)" ]]; then
            skip "debs/ ($(ls "$DEB_DIR"/*.deb 2>/dev/null | wc -l) DEBs cached)"
        else
            echo "  ~ [dry] debs/ (${#RUNTIME_PKGS_DEB[@]} packages to download)"
        fi
    else
        if [[ -d "$DEB_DIR" && "$(ls -A "$DEB_DIR" 2>/dev/null)" ]]; then
            skip "debs/ ($(ls "$DEB_DIR"/*.deb 2>/dev/null | wc -l) DEBs)"
        else
            mkdir -p "$DEB_DIR"
            echo "  Downloading DEBs (this may take a minute)..."
            apt-get update -qq 2>&1 | tail -1 || true
            # apt-get download doesn't resolve deps; use apt-rdepends or just install with --download-only
            apt-get install --download-only -y --reinstall "${RUNTIME_PKGS_DEB[@]}" 2>&1 | tail -1 || true
            # apt caches to /var/cache/apt/archives — copy to our DEB_DIR
            find /var/cache/apt/archives -name '*.deb' -exec cp {} "$DEB_DIR/" \;
            ok "debs/ ($(ls "$DEB_DIR"/*.deb 2>/dev/null | wc -l) DEBs)"
        fi
    fi

else
    warn "No supported package manager found — skipping system package download"
    warn "Bundle must be created on a Fedora/RHEL or Ubuntu/Debian host"
fi

# ===== Python wheels for airgap (optional) =====
# Tools like harlequin, posting, marimo need their deps bundled for offline install
echo ""
log "Python wheels (optional - for offline uv tool install)"
WHEEL_DIR="${CACHE}/wheels"
if command -v pip3 &>/dev/null && ! $DRY_RUN; then
    mkdir -p "$WHEEL_DIR"
    echo "  Downloading wheels for Python tools..."
    # Core tools that need bundling
    pip3 download harlequin --only-binary :all: -d "$WHEEL_DIR" 2>/dev/null || true
    pip3 download harlequin-postgres --only-binary :all: -d "$WHEEL_DIR" 2>/dev/null || true
    pip3 download posting --only-binary :all: -d "$WHEEL_DIR" 2>/dev/null || true
    pip3 download marimo --only-binary :all: -d "$WHEEL_DIR" 2>/dev/null || true
    pip3 download pytest --only-binary :all: -d "$WHEEL_DIR" 2>/dev/null || true
    WHEEL_COUNT=$(ls "$WHEEL_DIR"/*.whl 2>/dev/null | wc -l)
    if [[ $WHEEL_COUNT -gt 0 ]]; then
        ok "wheels/ ($WHEEL_COUNT wheels downloaded)"
    else
        echo "  ~ No wheels downloaded (pip may not be available or tools have no wheels)"
    fi
else
    echo "  ~ pip3 not available, skipping wheel download"
    echo "  ~ To bundle wheels manually: pip download <tool> -d airgap/cache/wheels/"
fi

# ===== Zsh plugins =====
echo ""
log "Zsh plugins"
clone_shallow "https://github.com/zdharma-continuum/zinit.git" zinit.tar.gz
clone_shallow "https://github.com/zdharma-continuum/fast-syntax-highlighting.git" fast-syntax-highlighting.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-autosuggestions.git" zsh-autosuggestions.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-completions.git" zsh-completions.tar.gz
clone_shallow "https://github.com/Aloxaf/fzf-tab.git" fzf-tab.tar.gz

# ===== Neovim plugins (manual step) =====
echo ""
log "Neovim plugins"
NVIM_DATA="${CACHE}/nvim-data.tar.gz"
if [[ -f "$NVIM_DATA" ]]; then
    ok "nvim-data.tar.gz found ($(du -h "$NVIM_DATA" | cut -f1))"
else
    echo "  ! nvim-data.tar.gz not in cache"
    echo "  ! To enable: run nvim online, then tar ~/.local/{share,state}/nvim into nvim-data.tar.gz"
    # Skip automatic plugin download for now - it has issues in Docker/CI environments
    # The nvim plugin sync requires a proper TTY and may fail in various container scenarios
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
fastfetch       ${FASTFETCH_VERSION}
mc              ${MC_VERSION}
marimo          ${MARIMO_VERSION}
k9s             ${K9S_VERSION}
lazydocker      ${LAZYDOCKER_VERSION}
btop            ${BTOP_VERSION}
lnav            ${LNAV_VERSION}
glow            ${GLOW_VERSION}
zig             ${ZIG_VERSION}
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
