#!/usr/bin/env bash
set -euo pipefail
# artifactory-push.sh — Upload airgap cache to JFrog Artifactory
# Usage: ./artifactory-push.sh [--dry-run] [--list]
#
# Config via env vars:
#   ARTIFACTORY_URL          https://artifactory.example.com/artifactory
#   GENERIC_REPO             devtools-generic-local
#   PYPI_REPO                pypi-local
#   ARTIFACTORY_USER/KEY     for curl fallback (jf CLI preferred)

ARTIFACTORY_URL="${ARTIFACTORY_URL:-}"
GENERIC_REPO="${GENERIC_REPO:-devtools-generic-local}"
PYPI_REPO="${PYPI_REPO:-pypi-local}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="${SCRIPT_DIR}/cache"

# Source version variables
[[ -f "${SCRIPT_DIR}/../bootstrap/03-install-tools.sh" ]] && \
    source "${SCRIPT_DIR}/../bootstrap/03-install-tools.sh"

DRY_RUN=false LIST_ONLY=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --list)    LIST_ONLY=true; shift ;;
        --help|-h) echo "Usage: $0 [--dry-run] [--list]"; exit 0 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

# ===== --list mode =====
if $LIST_ONLY; then
    echo "Cache: $CACHE"
    [[ -d "$CACHE" ]] || { echo "(empty)"; exit 0; }
    find "$CACHE" -type f -printf '  %s\t%p\n' | sort -k2
    echo "Total: $(du -sh "$CACHE" | cut -f1)"
    exit 0
fi

[[ -z "$ARTIFACTORY_URL" ]] && { echo "ERROR: ARTIFACTORY_URL not set" >&2; exit 1; }
[[ -d "$CACHE" ]] || { echo "ERROR: $CACHE not found — run bundle.sh first" >&2; exit 1; }
ARTIFACTORY_URL="${ARTIFACTORY_URL%/}"

# Detect upload method: jf CLI or curl
USE_JF=false
if command -v jf &>/dev/null || command -v jfrog &>/dev/null; then
    USE_JF=true
    command -v jf &>/dev/null || alias jf=jfrog
elif command -v curl &>/dev/null; then
    [[ -n "${ARTIFACTORY_USER:-}" && -n "${ARTIFACTORY_API_KEY:-}" ]] \
        || { echo "ERROR: curl fallback needs ARTIFACTORY_USER + ARTIFACTORY_API_KEY" >&2; exit 1; }
else
    echo "ERROR: need jf or curl" >&2; exit 1
fi

# upload LOCAL_PATH REPO REMOTE_PATH
upload() {
    local file="$1" repo="$2" remote="$3" name; name="$(basename "$file")"
    if $DRY_RUN; then echo "  ~ [dry] $name -> $repo/$remote"; return; fi
    if $USE_JF; then
        jf rt upload --flat=false "$file" "$repo/$remote" 2>&1 || { echo "  ! FAIL $name" >&2; return 1; }
    else
        local code; code=$(curl -sS -o /dev/null -w "%{http_code}" \
            -u "${ARTIFACTORY_USER}:${ARTIFACTORY_API_KEY}" \
            -T "$file" "${ARTIFACTORY_URL}/${repo}/${remote}")
        [[ "$code" =~ ^2 ]] || { echo "  ! HTTP $code for $name" >&2; return 1; }
    fi
    echo "  + $name -> $repo/$remote"
}

# Map filename to structured Artifactory path
remote_path() {
    local file="$1"
    local -a map=(
        "starship|starship|${STARSHIP_VERSION:-x}"  "zoxide|zoxide|${ZOXIDE_VERSION:-x}"
        "fzf|fzf|${FZF_VERSION:-x}"                 "bat-|bat|${BAT_VERSION:-x}"
        "eza|eza|${EZA_VERSION:-x}"                  "ripgrep|ripgrep|${RIPGREP_VERSION:-x}"
        "fd-|fd|${FD_VERSION:-x}"                    "yazi|yazi|${YAZI_VERSION:-x}"
        "lazygit|lazygit|${LAZYGIT_VERSION:-x}"      "uv-|uv|${UV_VERSION:-x}"
        "glab|glab|${GLAB_VERSION:-x}"               "jf|jfrog-cli|${JFROG_CLI_VERSION:-x}"
        "delta|delta|${DELTA_VERSION:-x}"             "nvim|neovim|${NEOVIM_VERSION:-x}"
        "helm|helm|${HELM_VERSION:-x}"                "openshift|oc|${OC_VERSION:-x}"
    )
    for m in "${map[@]}"; do
        IFS='|' read -r pat tool ver <<< "$m"
        [[ "$file" == *"$pat"* ]] && { echo "devtools/$tool/$ver/$file"; return; }
    done
    echo "devtools/misc/$file"
}

# ===== Upload =====
echo "artifactory-push.sh — $($DRY_RUN && echo DRY-RUN || echo LIVE)"
echo "  URL:  $ARTIFACTORY_URL"
echo "  Repo: $GENERIC_REPO"
echo ""

uploaded=0 failed=0

# Binary archives
for f in "$CACHE"/*; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    if upload "$f" "$GENERIC_REPO" "$(remote_path "$name")"; then
        uploaded=$((uploaded + 1))
    else
        failed=$((failed + 1))
    fi
done

# Python wheels (optional)
if [[ -d "$CACHE/marimo-wheels" ]]; then
    echo ""
    echo "==> Python wheels"
    for f in "$CACHE/marimo-wheels"/*.whl "$CACHE/marimo-wheels"/*.tar.gz; do
        [[ -f "$f" ]] || continue
        name="$(basename "$f")"
        if upload "$f" "$PYPI_REPO" "$name"; then
            uploaded=$((uploaded + 1))
        else
            failed=$((failed + 1))
        fi
    done
fi

echo ""
echo "Done: $uploaded uploaded, $failed failed"
[[ $failed -gt 0 ]] && exit 1 || exit 0
