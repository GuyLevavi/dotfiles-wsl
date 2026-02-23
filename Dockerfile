# Dockerfile — Multi-distro base image with all system packages pre-installed.
# Supports Fedora 43, RHEL/UBI 9, and Ubuntu 24.04 via ARG BASE_IMAGE.
#
# This image serves as the foundation for airgap deployments:
#   1. Pull this image on an online machine
#   2. Transfer it to the airgapped network
#   3. Run deploy.sh inside it (only needs the tool binaries bundle)
#
# Build (Fedora 43, default):
#   docker build -t ghcr.io/guylevavi/dotfiles-wsl:latest .
# Build (UBI 9):
#   docker build --build-arg BASE_IMAGE=registry.access.redhat.com/ubi9/ubi:latest \
#                -t ghcr.io/guylevavi/dotfiles-wsl:ubi9 .
# Build (Ubuntu 24.04):
#   docker build --build-arg BASE_IMAGE=ubuntu:24.04 \
#                -t ghcr.io/guylevavi/dotfiles-wsl:ubuntu2404 .
#
# Run:  docker run -it ghcr.io/guylevavi/dotfiles-wsl:latest

ARG BASE_IMAGE=registry.fedoraproject.org/fedora:43
FROM ${BASE_IMAGE}

# Use bash for all RUN commands — bash is pre-installed on all supported base
# images (Fedora 43, UBI 9, Ubuntu 24.04). The default /bin/sh on Ubuntu is
# dash, which lacks 'source' and bash-specific syntax used below.
SHELL ["/bin/bash", "-c"]

# ── System packages ──────────────────────────────────────────────────────────
# Detects the distro from /etc/os-release and uses the appropriate package
# manager. Package lists are kept in sync with 02-install-packages.sh.
# CI validates this via the cache-contract job.
RUN source /etc/os-release && \
    case "${ID:-}" in \
      fedora|rhel|centos|almalinux|rocky) \
        # Enable extra repos on RHEL-family (no-op on Fedora). \
        # UBI 9: enable the built-in AppStream + CRB repos (tmux, tree, stow \
        #   live there), then add EPEL for ShellCheck and other extras. \
        #   EPEL URL install is used because UBI 9 doesn't ship epel-release \
        #   as a dnf package in its default sparse repos. \
        if [ "${ID}" != "fedora" ]; then \
          VER="${VERSION_ID%%.*}" && \
          dnf install -y \
            "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VER}.noarch.rpm" \
            2>/dev/null \
          || dnf install -y epel-release 2>/dev/null \
          || true && \
          dnf config-manager \
            --set-enabled "ubi-${VER}-appstream-rpms" \
            "ubi-${VER}-baseos-rpms" \
            "ubi-${VER}-codeready-builder-rpms" \
            crb powertools \
            2>/dev/null || true && \
          dnf makecache; \
        fi && \
        dnf install -y \
          curl wget unzip tar gzip bzip2 xz which file tree htop procps-ng \
          zsh tmux stow git git-lfs gawk \
          nodejs npm \
          podman buildah skopeo fuse-overlayfs \
          python3-devel python3-pip \
          jq ShellCheck \
        && dnf clean all \
        && rm -rf /var/cache/dnf \
        ;; \
      ubuntu|debian) \
        export DEBIAN_FRONTEND=noninteractive && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
          curl wget unzip tar gzip bzip2 xz-utils file tree htop procps \
          zsh tmux stow git git-lfs gawk \
          nodejs npm \
          python3-dev python3-pip \
          jq shellcheck \
          fuse-overlayfs \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/* \
        ;; \
      *) echo "Unsupported distro: ${ID:-unknown}" >&2; exit 1 ;; \
    esac

# ── Create dev user ──────────────────────────────────────────────────────────
# Detect sudo group name (wheel on RHEL-family, sudo on Ubuntu/Debian)
RUN source /etc/os-release && \
    case "${ID:-}" in \
      ubuntu|debian) SUDO_GROUP=sudo ;; \
      *)             SUDO_GROUP=wheel ;; \
    esac && \
    # Create wheel group if it doesn't exist (RHEL/UBI may not have it) \
    getent group wheel >/dev/null 2>&1 || groupadd wheel && \
    # Create user with zsh shell \
    (command -v zsh >/dev/null 2>&1 && ZSH_PATH=$(command -v zsh) || ZSH_PATH=/usr/bin/zsh) && \
    useradd --create-home --shell "$ZSH_PATH" gl && \
    usermod --append --groups "$SUDO_GROUP" gl && \
    echo "%${SUDO_GROUP} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo-nopasswd && \
    chmod 0440 /etc/sudoers.d/sudo-nopasswd

# ── XDG directories ─────────────────────────────────────────────────────────
USER gl
WORKDIR /home/gl
RUN mkdir -p .local/bin .local/share .local/state .config .cache

# Default shell
ENV SHELL=/usr/bin/zsh
CMD ["/usr/bin/zsh"]
