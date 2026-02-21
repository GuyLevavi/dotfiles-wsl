#!/usr/bin/env bash
set -euo pipefail
# 03-install-tools.sh — Install CLI tools from GitHub releases / official sources
# Usage:
#   ./03-install-tools.sh            # online  — fetches latest versions
#   ./03-install-tools.sh --offline  # airgap  — reads from airgap/cache/
#
# Version variables are defined here and sourced by airgap/bundle.sh.
# To pin a specific version, set it before running:
#   NEOVIM_VERSION=0.11.6 ./03-install-tools.sh

# ===== Helper: resolve latest GitHub release tag =====
# Returns the latest release version (without the "v" prefix).
# Falls back to $2 if the API call fails.
gh_latest() {
    local repo="$1" fallback="${2:-}"
    local tag
    tag="$(curl -sL --retry 1 --max-time 5 \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep -o '"tag_name": *"[^"]*"' | head -1 | sed 's/.*"v\?\([^"]*\)".*/\1/')" || true
    if [[ -n "$tag" ]]; then
        echo "$tag"
    elif [[ -n "$fallback" ]]; then
        echo "$fallback" >&2
        echo "   (fallback: GitHub API unreachable, using ${fallback})" >&2
        echo "$fallback"
    else
        echo "ERROR: Could not resolve latest version for ${repo}" >&2
        return 1
    fi
}

# ===== Versions =====
# Each can be overridden via environment variable. Default = latest from GitHub.
# For airgap/bundle.sh: versions are resolved once at bundle time, written to
# versions.lock, and the lock file pins them for offline deploy.
resolve_versions() {
    echo "==> Resolving latest versions..."
    STARSHIP_VERSION="${STARSHIP_VERSION:-$(gh_latest starship/starship)}"
    ZOXIDE_VERSION="${ZOXIDE_VERSION:-$(gh_latest ajeetdsouza/zoxide)}"
    FZF_VERSION="${FZF_VERSION:-$(gh_latest junegunn/fzf)}"
    BAT_VERSION="${BAT_VERSION:-$(gh_latest sharkdp/bat)}"
    EZA_VERSION="${EZA_VERSION:-$(gh_latest eza-community/eza)}"
    RIPGREP_VERSION="${RIPGREP_VERSION:-$(gh_latest BurntSushi/ripgrep)}"
    FD_VERSION="${FD_VERSION:-$(gh_latest sharkdp/fd)}"
    YAZI_VERSION="${YAZI_VERSION:-$(gh_latest sxyazi/yazi)}"
    LAZYGIT_VERSION="${LAZYGIT_VERSION:-$(gh_latest jesseduffield/lazygit)}"
    DELTA_VERSION="${DELTA_VERSION:-$(gh_latest dandavison/delta)}"
    NEOVIM_VERSION="${NEOVIM_VERSION:-$(gh_latest neovim/neovim)}"
    UV_VERSION="${UV_VERSION:-$(gh_latest astral-sh/uv)}"
    GLAB_VERSION="${GLAB_VERSION:-$(gh_latest gitlab-org/cli)}"
    JFROG_CLI_VERSION="${JFROG_CLI_VERSION:-2.72.2}"  # no GitHub releases page
    HELM_VERSION="${HELM_VERSION:-$(gh_latest helm/helm)}"
    OC_VERSION="${OC_VERSION:-4.17}"                  # uses stable-X.Y channel, not a tag
    MARIMO_VERSION="${MARIMO_VERSION:-}"               # empty = latest via uv
}

# Python versions to install via uv
PYTHON_VERSIONS="${PYTHON_VERSIONS:-3.9 3.10 3.11 3.12 3.13}"

# Guard: allow sourcing for version variables without running main
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    resolve_versions
    return 0 2>/dev/null
fi

# ===== Setup =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${HOME}/.local/bin"
TMP="$(mktemp -d)"
CACHE="${SCRIPT_DIR}/../airgap/cache"
OFFLINE=false
[[ "${1:-}" == "--offline" ]] && OFFLINE=true

# In offline mode, read pinned versions from the lock file
if $OFFLINE && [[ -f "${CACHE}/versions.lock" ]]; then
    echo "==> Reading pinned versions from versions.lock"
    while IFS=$' \t' read -r name ver; do
        [[ "$name" =~ ^#.*$ || -z "$name" ]] && continue
        varname="$(echo "${name^^}" | tr '-' '_')_VERSION"
        declare "${varname}=${ver}"
    done < "${CACHE}/versions.lock"
else
    resolve_versions
fi

mkdir -p "${BIN}"
[[ ":${PATH}:" != *":${BIN}:"* ]] && export PATH="${BIN}:${PATH}"
trap 'rm -rf "${TMP}"' EXIT

# Fetch a file: online=curl, offline=copy from cache
fetch() {
    local dest="$1" url="$2"
    if $OFFLINE; then
        cp "${CACHE}/$(basename "$dest")" "$dest"
    else
        curl -fSL --retry 2 -o "$dest" "$url"
    fi
}

# Install a GitHub release tarball: fetch, extract, copy binary
# Usage: gh_tool NAME VERSION URL BINARY [STRIP]
gh_tool() {
    local name="$1" ver="$2" url="$3" bin="$4" strip="${5:-0}"
    echo "==> ${name} ${ver}"
    local archive="${TMP}/${name}.tar.gz"
    fetch "$archive" "$url"
    local d="${TMP}/${name}"
    mkdir -p "$d"
    tar -xf "$archive" -C "$d" --strip-components="$strip"
    install -m 0755 "$d/$bin" "${BIN}/${bin}"
}

# ===== Print resolved versions =====
echo ""
echo "Versions:"
for v in STARSHIP ZOXIDE FZF BAT EZA RIPGREP FD YAZI LAZYGIT DELTA NEOVIM UV GLAB JFROG_CLI HELM OC; do
    var="${v}_VERSION"
    printf "  %-14s %s\n" "$v" "${!var}"
done
echo ""

# ===== Install tools =====

gh_tool starship "$STARSHIP_VERSION" \
    "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
    starship

gh_tool zoxide "$ZOXIDE_VERSION" \
    "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    zoxide

gh_tool fzf "$FZF_VERSION" \
    "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-linux_amd64.tar.gz" \
    fzf

gh_tool bat "$BAT_VERSION" \
    "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat-v${BAT_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    bat 1

gh_tool eza "$EZA_VERSION" \
    "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
    eza

gh_tool ripgrep "$RIPGREP_VERSION" \
    "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep-${RIPGREP_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    rg 1

gh_tool fd "$FD_VERSION" \
    "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/fd-v${FD_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    fd 1

gh_tool lazygit "$LAZYGIT_VERSION" \
    "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    lazygit

gh_tool delta "$DELTA_VERSION" \
    "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    delta 1

gh_tool helm "$HELM_VERSION" \
    "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
    helm 1

# glab — GitLab CLI (has bin/ prefix in tarball)
echo "==> glab ${GLAB_VERSION}"
fetch "${TMP}/glab.tar.gz" "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_amd64.tar.gz"
mkdir -p "${TMP}/glab" && tar -xzf "${TMP}/glab.tar.gz" -C "${TMP}/glab"
install -m 0755 "${TMP}/glab/bin/glab" "${BIN}/glab"

# Yazi — terminal file manager (zip, not tar)
echo "==> yazi ${YAZI_VERSION}"
fetch "${TMP}/yazi.zip" "https://github.com/sxyazi/yazi/releases/download/v${YAZI_VERSION}/yazi-x86_64-unknown-linux-gnu.zip"
unzip -qo "${TMP}/yazi.zip" -d "${TMP}/yazi"
install -m 0755 "${TMP}/yazi/yazi-x86_64-unknown-linux-gnu/yazi" "${BIN}/yazi"
[[ -f "${TMP}/yazi/yazi-x86_64-unknown-linux-gnu/ya" ]] && \
    install -m 0755 "${TMP}/yazi/yazi-x86_64-unknown-linux-gnu/ya" "${BIN}/ya"

# jfrog CLI — single binary download
echo "==> jfrog ${JFROG_CLI_VERSION}"
fetch "${TMP}/jf" "https://releases.jfrog.io/artifactory/jfrog-cli/v2-jf/${JFROG_CLI_VERSION}/jfrog-cli-linux-amd64/jf"
install -m 0755 "${TMP}/jf" "${BIN}/jf"

# Neovim — AppImage (0.11+ uses nvim-linux-x86_64.appimage filename)
echo "==> neovim ${NEOVIM_VERSION}"
fetch "${TMP}/nvim.appimage" "https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/nvim-linux-x86_64.appimage"
cp "${TMP}/nvim.appimage" "${BIN}/nvim.appimage" && chmod +x "${BIN}/nvim.appimage"
cat > "${BIN}/nvim" << 'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/bin/nvim.appimage" --appimage-extract-and-run "$@"
EOF
chmod +x "${BIN}/nvim"

# oc — OpenShift CLI (also bundles kubectl)
echo "==> oc ${OC_VERSION}"
fetch "${TMP}/oc.tar.gz" "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-${OC_VERSION}/openshift-client-linux.tar.gz"
mkdir -p "${TMP}/oc" && tar -xzf "${TMP}/oc.tar.gz" -C "${TMP}/oc"
install -m 0755 "${TMP}/oc/oc" "${BIN}/oc"
[[ -f "${TMP}/oc/kubectl" ]] && install -m 0755 "${TMP}/oc/kubectl" "${BIN}/kubectl"

# uv — fast Python package manager
echo "==> uv ${UV_VERSION}"
fetch "${TMP}/uv.tar.gz" "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"
mkdir -p "${TMP}/uv" && tar -xzf "${TMP}/uv.tar.gz" -C "${TMP}/uv" --strip-components=1
install -m 0755 "${TMP}/uv/uv" "${BIN}/uv"
install -m 0755 "${TMP}/uv/uvx" "${BIN}/uvx"

# Python versions via uv (3.9 through 3.13)
echo "==> Python ${PYTHON_VERSIONS} (via uv)"
if $OFFLINE; then
    echo "   Skipping in offline mode (pre-place Pythons in ~/.local/share/uv/python/)"
    echo "   Set UV_PYTHON_DOWNLOADS=manual in your shell to prevent uv from trying to download."
else
    # shellcheck disable=SC2086
    uv python install $PYTHON_VERSIONS
fi
uv python list --only-installed 2>/dev/null || true

# marimo — reactive Python notebooks
echo "==> marimo ${MARIMO_VERSION:-latest}"
if $OFFLINE; then
    [[ -d "${CACHE}/marimo-wheels" ]] && \
        uv tool install --find-links "${CACHE}/marimo-wheels" "marimo==${MARIMO_VERSION}" || \
        echo "   Skipped (no offline wheels found)"
else
    if [[ -n "${MARIMO_VERSION:-}" ]]; then
        uv tool install "marimo==${MARIMO_VERSION}"
    else
        uv tool install marimo
    fi
fi

# OpenCode — AI coding agent (supports GitHub Copilot, Anthropic, OpenAI, etc.)
echo "==> opencode (latest)"
if $OFFLINE; then
    [[ -f "${CACHE}/opencode" ]] && install -m 0755 "${CACHE}/opencode" "${HOME}/.opencode/bin/opencode" || \
        echo "   Skipped (no offline binary found)"
else
    curl -fsSL https://opencode.ai/install | bash
fi

# Codex CLI — OpenAI coding agent (requires OpenAI API key or ChatGPT login)
echo "==> codex (latest via npm)"
if $OFFLINE; then
    echo "   Skipped (requires npm online install)"
else
    if command -v npm &>/dev/null; then
        npm config set prefix "${HOME}/.npm-global" 2>/dev/null || true
        npm install -g @openai/codex
    else
        echo "   Skipped (npm not found — install Node.js first)"
    fi
fi

# ===== Summary =====
echo ""
echo "All tools installed to ${BIN}"
echo "Verify: ls ${BIN}"
echo "Next: bash bootstrap/04-stow-dotfiles.sh"
