# Dockerfile — Fedora 43 base image with all system packages pre-installed
# This image serves as the foundation for airgap deployments:
#   1. Pull this image on an online machine
#   2. Transfer it to the airgapped network
#   3. Run deploy.sh inside it (only needs the tool binaries bundle)
#
# Build:  docker build -t ghcr.io/guylevavi/dotfiles-wsl:latest .
# Run:    docker run -it ghcr.io/guylevavi/dotfiles-wsl:latest
#
# The image includes:
#   - All RUNTIME_PKGS from bootstrap/02-install-packages.sh
#   - User 'gl' with sudo, zsh as default shell
#   - XDG directories pre-created
#   - Ready for deploy.sh --user gl --force <bundle.tar.gz>

FROM registry.fedoraproject.org/fedora:43

# ── System packages ──────────────────────────────────────────────────────────
# Keep in sync with bootstrap/02-install-packages.sh RUNTIME_PKGS array.
# CI validates this via the cache-contract job.
RUN dnf install -y \
        curl wget unzip tar gzip bzip2 xz which file tree htop procps-ng \
        zsh tmux stow git git-lfs gawk \
        nodejs npm \
        podman buildah skopeo fuse-overlayfs \
        python3-devel python3-pip \
        jq ShellCheck \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# ── Create dev user ──────────────────────────────────────────────────────────
RUN useradd --create-home --shell /usr/bin/zsh gl \
    && usermod --append --groups wheel gl \
    && echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd \
    && chmod 0440 /etc/sudoers.d/wheel-nopasswd

# ── XDG directories ─────────────────────────────────────────────────────────
USER gl
WORKDIR /home/gl
RUN mkdir -p .local/bin .local/share .local/state .config .cache

# Default shell
ENV SHELL=/usr/bin/zsh
CMD ["/usr/bin/zsh"]
