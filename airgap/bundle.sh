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

# ===== Zsh plugins =====
echo ""
log "Zsh plugins"
clone_shallow "https://github.com/zdharma-continuum/zinit.git" zinit.tar.gz
clone_shallow "https://github.com/zdharma-continuum/fast-syntax-highlighting.git" fast-syntax-highlighting.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-autosuggestions.git" zsh-autosuggestions.tar.gz
clone_shallow "https://github.com/zsh-users/zsh-completions.git" zsh-completions.tar.gz
clone_shallow "https://github.com/Aloxaf/fzf-tab.git" fzf-tab.tar.gz

# ===== Neovim plugins (auto-generated) =====
echo ""
log "Neovim plugins"
NVIM_DATA="${CACHE}/nvim-data.tar.gz"
if [[ -f "$NVIM_DATA" ]]; then
    ok "nvim-data.tar.gz found"
else
    if [[ -z "${NEOVIM_VERSION:-}" ]]; then
        source "${SCRIPT_DIR}/../bootstrap/03-install-tools.sh" 2>/dev/null || true
    fi

    NVIM_HOME=$(mktemp -d)
    export HOME="$NVIM_HOME"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.config/nvim"

    EXTRACT_DIR="$NVIM_HOME/squashfs-root"
    if [[ -f "${CACHE}/nvim.appimage" ]]; then
        chmod +x "${CACHE}/nvim.appimage"
        if "${CACHE}/nvim.appimage" --appimage-extract >/dev/null 2>&1 && [[ -d "$EXTRACT_DIR" ]]; then
            ln -sf "$EXTRACT_DIR/usr/bin/nvim" "$HOME/.local/bin/nvim"
            ok "nvim.appimage extracted"
        else
            warn "nvim.appimage extraction failed"
            rm -rf "$NVIM_HOME"
            die "Cannot proceed without working nvim - fix appimage extraction first"
        fi
    else
        die "nvim.appimage not in cache — run with online host first"
    fi

    if [[ -d "${SCRIPT_DIR}/../nvim/.config/nvim" ]]; then
        cp -r "${SCRIPT_DIR}/../nvim/.config/nvim" "$HOME/.config/"
        ok "nvim config copied"
    fi

    if command -v git &>/dev/null; then
        ln -sf "$(command -v git)" "$HOME/.local/bin/git"
    fi
    if command -v zsh &>/dev/null; then
        ln -sf "$(command -v zsh)" "$HOME/.local/bin/zsh"
    fi

    export PATH="$HOME/.local/bin:$PATH"
    echo "  Running LazySync to download plugins..."
    
    LAZY_OUTPUT=$("$HOME/.local/bin/nvim" --headless +LazySync +qa 2>&1) || true
    echo "$LAZY_OUTPUT" | tail -10
    
    PLUGIN_DIR="$HOME/.local/share/nvim/lazy"
    if [[ -d "$PLUGIN_DIR" && "$(ls -A "$PLUGIN_DIR" 2>/dev/null)" ]]; then
        PLUGIN_COUNT=$(find "$PLUGIN_DIR" -maxdepth 1 -type d | wc -l | tr -d ' ')
        echo "  Found $PLUGIN_COUNT plugins in lazy dir"
        
        cd "$HOME/.local"
        tar -czf "$NVIM_DATA" share/nvim state/nvim
        cd - >/dev/null
        
        if [[ -s "$NVIM_DATA" ]]; then
            ok "nvim-data.tar.gz created ($(du -h "$NVIM_DATA" | cut -f1), $PLUGIN_COUNT plugins)"
        else
            rm -f "$NVIM_DATA"
            die "nvim-data.tar.gz is empty after packing"
        fi
    else
        rm -f "$NVIM_DATA"
        die "LazyVim plugin download FAILED — no plugins in $PLUGIN_DIR. Output: $LAZY_OUTPUT"
    fi

    rm -rf "$NVIM_HOME"
fi

    # Create a temporary home for nvim to download plugins into
    NVIM_HOME=$(mktemp -d)
    export HOME="$NVIM_HOME"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state"
    mkdir -p "$HOME/.config/nvim"

    # Install nvim to temp home
    if [[ -f "${CACHE}/nvim.appimage" ]]; then
        chmod +x "${CACHE}/nvim.appimage"
        "$CACHE/nvim.appimage" --appimage-extract >/dev/null 2>&1
        ln -sf "$NVIM_HOME/squashfs-root/usr/bin/nvim" "$HOME/.local/bin/nvim"
    else
        warn "nvim.appimage not in cache — cannot download LazyVim plugins"
    fi

    # Link or copy nvim config from this repo
    if [[ -d "${SCRIPT_DIR}/../nvim/.config/nvim" ]]; then
        cp -r "${SCRIPT_DIR}/../nvim/.config/nvim" "$HOME/.config/"
    fi

    # Also need zsh for lazy.nvim's health checks
    if command -v zsh &>/dev/null; then
        ln -sf "$(command -v zsh)" "$HOME/.local/bin/zsh"
    fi

    # Run LazySync to download all plugins
    echo "  Downloading LazyVim plugins (this takes ~30s)..."
    export PATH="$HOME/.local/bin:$PATH"
    if "$HOME/.local/bin/nvim" --headless +LazySync +qa 2>&1 | tail -3; then
        echo "  LazyVim plugins downloaded"
        # Create nvim-data.tar.gz from the plugin dirs
        cd "$HOME/.local"
        tar -czf "$NVIM_DATA" share/nvim state/nvim 2>/dev/null || true
        cd - >/dev/null
        if [[ -s "$NVIM_DATA" ]]; then
            ok "nvim-data.tar.gz created ($(du -h "$NVIM_DATA" | cut -f1))"
        else
            rm -f "$NVIM_DATA"
            warn "nvim-data.tar.gz is empty —LazyVim may have failed"
        fi
    else
        warn "LazyVim plugin download failed — nvim will need network on first launch"
    fi

    rm -rf "$NVIM_HOME"
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
