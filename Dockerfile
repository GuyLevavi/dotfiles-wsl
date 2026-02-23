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
        # Enable EPEL on RHEL-family (no-op on Fedora, which already has all \
        # packages in its main repos). EPEL URL install is used because UBI 9 \
        # doesn't ship epel-release as a dnf package in its default repos. \
        if [ "${ID}" != "fedora" ]; then \
          VER="${VERSION_ID%%.*}" && \
          dnf install -y \
            "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VER}.noarch.rpm" \
          || dnf install -y epel-release || true && \
          /usr/bin/crb enable 2>&1 || true && \
          dnf makecache --quiet; \
        fi && \
        # Core packages — must succeed \
        dnf install -y \
          curl wget unzip tar gzip bzip2 xz which file gawk \
          zsh stow git git-lfs \
          podman buildah skopeo fuse-overlayfs \
          python3-devel python3-pip \
          jq && \
        # Optional packages — skip if not available (UBI has limited repos) \
        dnf install -y procps-ng htop tree tmux nodejs npm ShellCheck \
          2>/dev/null || \
        dnf install -y procps-ng htop nodejs npm \
          2>/dev/null || true && \
        dnf clean all && \
        rm -rf /var/cache/dnf \
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
