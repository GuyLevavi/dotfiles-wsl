#!/usr/bin/env bash
set -euo pipefail
# 02-install-packages.sh — Install system packages (DNF or APT)
# Usage:
#   sudo ./02-install-packages.sh                      # full install (online)
#   sudo ./02-install-packages.sh --minimal             # runtime only (online)
#   sudo ./02-install-packages.sh --offline RPM_DIR     # install from local RPMs (Fedora/RHEL)
#   sudo ./02-install-packages.sh --offline DEB_DIR     # install from local DEBs (Ubuntu/Debian)
#
# The --minimal flag skips C/C++ compilers and -devel headers (~250 MB).
# These are only needed if you build Python packages from source (pip install
# with C extensions). If your airgapped network has Artifactory serving
# pre-built wheels, you won't need them.
#
# The --offline flag installs pre-downloaded packages from the given directory.
# Used by airgap/deploy.sh with packages cached by airgap/bundle.sh.

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)." >&2; exit 1; }

MINIMAL=false
OFFLINE=false
PKG_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal) MINIMAL=true; shift ;;
        --offline) OFFLINE=true; PKG_DIR="${2:-}"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

# ── Detect package manager ────────────────────────────────────────────────────
source /etc/os-release
case "${ID:-}" in
    ubuntu|debian)           PKG_MGR=apt ;;
    fedora|rhel|centos|almalinux|rocky) PKG_MGR=dnf ;;
    *)
        if command -v dnf &>/dev/null; then PKG_MGR=dnf
        elif command -v apt-get &>/dev/null; then PKG_MGR=apt
        else echo "ERROR: unsupported distro '${ID:-unknown}'" >&2; exit 1
        fi ;;
esac

# ── Offline mode: install from cached packages ────────────────────────────────
if $OFFLINE; then
    if [[ -z "$PKG_DIR" || ! -d "$PKG_DIR" ]]; then
        echo "ERROR: --offline requires a directory of packages (got: '${PKG_DIR:-}')" >&2
        exit 1
    fi

    if [[ "$PKG_MGR" == "dnf" ]]; then
        rpm_count="$(find "$PKG_DIR" -name '*.rpm' | wc -l)"
        if [[ "$rpm_count" -eq 0 ]]; then
            echo "ERROR: No RPMs found in $PKG_DIR" >&2
            exit 1
        fi
        echo "==> Installing $rpm_count RPMs from $PKG_DIR (offline mode)..."
        dnf install -y --disablerepo='*' "$PKG_DIR"/*.rpm 2>&1 || {
            echo "  ! dnf localinstall failed, trying rpm directly..."
            rpm -Uvh --force --nodeps "$PKG_DIR"/*.rpm 2>&1 || true
        }

    elif [[ "$PKG_MGR" == "apt" ]]; then
        deb_count="$(find "$PKG_DIR" -name '*.deb' | wc -l)"
        if [[ "$deb_count" -eq 0 ]]; then
            echo "ERROR: No DEBs found in $PKG_DIR" >&2
            exit 1
        fi
        echo "==> Installing $deb_count DEBs from $PKG_DIR (offline mode)..."
        DEBIAN_FRONTEND=noninteractive dpkg -i "$PKG_DIR"/*.deb 2>&1 || {
            echo "  ! dpkg install had errors, fixing dependencies..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y --fix-broken 2>&1 || true
        }
    fi

    echo "Done (offline). Next: bash bootstrap/03-install-tools.sh"
    exit 0
fi

# ── Online mode ──────────────────────────────────────────────────────────────

if [[ "$PKG_MGR" == "dnf" ]]; then
    # Enable EPEL on RHEL-family distros (not needed on Fedora)
    # UBI 9 doesn't ship epel-release as a DNF package; install via URL instead.
    case "${ID:-}" in
        almalinux|rocky|centos|rhel)
            VER="${VERSION_ID%%.*}"
            dnf install -y \
                "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VER}.noarch.rpm" \
                2>/dev/null \
            || dnf install -y epel-release 2>/dev/null \
            || true
            dnf config-manager --set-enabled crb 2>/dev/null \
                || dnf config-manager --set-enabled powertools 2>/dev/null || true
            ;;
    esac

    # ── Runtime packages (always installed) ──────────────────────────────────
    # These are needed on both online and offline machines.
    RUNTIME_PKGS=(
        curl wget unzip tar gzip bzip2 xz which file tree htop procps-ng
        zsh tmux stow git git-lfs gawk
        nodejs npm
        podman buildah skopeo fuse-overlayfs
        python3-devel python3-pip
        jq ShellCheck
    )

    # ── Build packages (online only) ─────────────────────────────────────────
    # C/C++ toolchain + library headers for compiling Python C extensions.
    # Skip with --minimal if your airgapped network serves pre-built wheels.
    BUILD_PKGS=(
        gcc gcc-c++ make cmake pkg-config
        openssl-devel zlib-devel libffi-devel readline-devel sqlite-devel
        bzip2-devel xz-devel ncurses-devel
    )

    echo "==> Installing runtime packages (dnf)..."
    dnf install -y "${RUNTIME_PKGS[@]}"

    if $MINIMAL; then
        echo "==> Skipping build packages (--minimal mode)"
    else
        echo "==> Installing build packages (compilers + dev headers)..."
        dnf install -y "${BUILD_PKGS[@]}"
    fi

    dnf clean all

elif [[ "$PKG_MGR" == "apt" ]]; then
    export DEBIAN_FRONTEND=noninteractive

    # ── Runtime packages (Ubuntu/Debian name equivalents) ────────────────────
    # Package name differences vs Fedora/RHEL:
    #   python3-devel  → python3-dev
    #   ShellCheck     → shellcheck
    #   procps-ng      → procps
    #   xz             → xz-utils
    #   podman/buildah/skopeo — available from Ubuntu 22.04+ universe repo
    RUNTIME_PKGS=(
        curl wget unzip tar gzip bzip2 xz-utils file tree htop procps
        zsh tmux stow git git-lfs gawk
        nodejs npm
        podman buildah skopeo fuse-overlayfs
        python3-dev python3-pip python3-venv
        jq shellcheck
    )

    BUILD_PKGS=(
        gcc g++ make cmake pkg-config
        libssl-dev zlib1g-dev libffi-dev libreadline-dev libsqlite3-dev
        libbz2-dev liblzma-dev libncurses-dev
    )

    apt-get update

    echo "==> Installing runtime packages (apt)..."
    apt-get install -y --no-install-recommends "${RUNTIME_PKGS[@]}"

    if $MINIMAL; then
        echo "==> Skipping build packages (--minimal mode)"
    else
        echo "==> Installing build packages (compilers + dev headers)..."
        apt-get install -y --no-install-recommends "${BUILD_PKGS[@]}"
    fi

    apt-get clean
    rm -rf /var/lib/apt/lists/*
fi

echo "Done. Next: bash bootstrap/03-install-tools.sh"
