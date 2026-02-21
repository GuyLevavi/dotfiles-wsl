#!/usr/bin/env bash
set -euo pipefail
# 02-install-packages.sh — Install system packages via DNF
# Usage:
#   sudo ./02-install-packages.sh              # full install (online machine)
#   sudo ./02-install-packages.sh --minimal    # runtime only (airgap target)
#
# The --minimal flag skips C/C++ compilers and -devel headers (~250 MB).
# These are only needed if you build Python packages from source (pip install
# with C extensions). If your airgapped network has Artifactory serving
# pre-built wheels, you won't need them.

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)." >&2; exit 1; }

MINIMAL=false
[[ "${1:-}" == "--minimal" ]] && MINIMAL=true

# Enable EPEL on RHEL-family distros (not needed on Fedora)
source /etc/os-release
case "${ID:-}" in
    almalinux|rocky|centos|rhel)
        dnf install -y epel-release
        dnf config-manager --set-enabled crb 2>/dev/null \
            || dnf config-manager --set-enabled powertools 2>/dev/null || true
        ;;
esac

# ── Runtime packages (always installed) ──────────────────────────────────────
# These are needed on both online and offline machines.
RUNTIME_PKGS=(
    curl wget unzip tar gzip bzip2 xz which file tree htop procps-ng
    zsh tmux stow git git-lfs gawk
    nodejs npm
    podman buildah skopeo fuse-overlayfs
    python3-devel python3-pip
    jq ShellCheck
)

# ── Build packages (online only) ─────────────────────────────────────────────
# C/C++ toolchain + library headers for compiling Python C extensions.
# Skip with --minimal if your airgapped network serves pre-built wheels.
BUILD_PKGS=(
    gcc gcc-c++ make cmake pkg-config
    openssl-devel zlib-devel libffi-devel readline-devel sqlite-devel
    bzip2-devel xz-devel ncurses-devel
)

echo "==> Installing runtime packages..."
dnf install -y "${RUNTIME_PKGS[@]}"

if $MINIMAL; then
    echo "==> Skipping build packages (--minimal mode)"
else
    echo "==> Installing build packages (compilers + dev headers)..."
    dnf install -y "${BUILD_PKGS[@]}"
fi

dnf clean all
echo "Done. Next: bash bootstrap/03-install-tools.sh"
