#!/usr/bin/env bash
set -euo pipefail
# 02-install-packages.sh — Install system packages via DNF
# Usage:
#   sudo ./02-install-packages.sh                      # full install (online)
#   sudo ./02-install-packages.sh --minimal             # runtime only (online)
#   sudo ./02-install-packages.sh --offline RPM_DIR     # install from local RPMs
#
# The --minimal flag skips C/C++ compilers and -devel headers (~250 MB).
# These are only needed if you build Python packages from source (pip install
# with C extensions). If your airgapped network has Artifactory serving
# pre-built wheels, you won't need them.
#
# The --offline flag installs pre-downloaded RPMs from RPM_DIR (no network).
# Used by airgap/deploy.sh with RPMs cached by airgap/bundle.sh.

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)." >&2; exit 1; }

MINIMAL=false
OFFLINE=false
RPM_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --minimal) MINIMAL=true; shift ;;
        --offline) OFFLINE=true; RPM_DIR="${2:-}"; shift 2 ;;
        *) echo "Unknown: $1" >&2; exit 1 ;;
    esac
done

# ── Offline mode: install from cached RPMs ───────────────────────────────────
if $OFFLINE; then
    if [[ -z "$RPM_DIR" || ! -d "$RPM_DIR" ]]; then
        echo "ERROR: --offline requires a directory of RPMs (got: '${RPM_DIR:-}')" >&2
        exit 1
    fi
    rpm_count="$(find "$RPM_DIR" -name '*.rpm' | wc -l)"
    if [[ "$rpm_count" -eq 0 ]]; then
        echo "ERROR: No RPMs found in $RPM_DIR" >&2
        exit 1
    fi
    echo "==> Installing $rpm_count RPMs from $RPM_DIR (offline mode)..."
    dnf install -y --disablerepo='*' "$RPM_DIR"/*.rpm 2>&1 || {
        echo "  ! dnf localinstall failed, trying rpm directly..."
        rpm -Uvh --force --nodeps "$RPM_DIR"/*.rpm 2>&1 || true
    }
    echo "Done (offline). Next: bash bootstrap/03-install-tools.sh"
    exit 0
fi

# ── Online mode ──────────────────────────────────────────────────────────────

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
