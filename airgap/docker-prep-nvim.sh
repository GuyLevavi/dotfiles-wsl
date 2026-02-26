#!/usr/bin/env bash
# docker-prep-nvim.sh — Generate nvim data bundle using Docker (for when CI fails or local generation needed)
# Usage: ./docker-prep-nvim.sh [fedora|ubi9|ubuntu]
# This creates nvim-data.tar.gz that can be added to the airgap bundle

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO="${1:-fedora}"
CACHE="${SCRIPT_DIR}/cache"
mkdir -p "$CACHE"

echo "==> Building nvim data bundle using Docker ($DISTRO)"
echo "    This will take 5-10 minutes..."
echo ""

# Determine base image
 case "$DISTRO" in
    fedora)    BASE_IMAGE="registry.fedoraproject.org/fedora:43" ;;
    ubi9)      BASE_IMAGE="registry.access.redhat.com/ubi9/ubi:latest" ;;
    ubuntu)    BASE_IMAGE="ubuntu:24.04" ;;
    *)         echo "ERROR: Unknown distro: $DISTRO (use: fedora, ubi9, ubuntu)"; exit 1 ;;
esac

# Create temporary Dockerfile
DOCKERFILE=$(mktemp)
cat > "$DOCKERFILE" << 'EOF'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install common dependencies
RUN if command -v dnf &>/dev/null; then \
        dnf install -y curl git tar gzip nodejs npm python3 python3-pip; \
    elif command -v apt-get &>/dev/null; then \
        apt-get update && apt-get install -y curl git tar gzip nodejs npm python3 python3-pip; \
    fi

# Create test user
RUN useradd --create-home --shell /bin/bash testuser

# Download nvim AppImage
RUN curl -L -o /home/testuser/.local/bin/nvim.appimage \
    "https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.appimage" && \
    chmod +x /home/testuser/.local/bin/nvim.appimage && \
    chown -R testuser:testuser /home/testuser/.local

# Create nvim wrapper
RUN cat > /home/testuser/.local/bin/nvim << 'WRAPPER'
#!/bin/bash
exec /home/testuser/.local/bin/nvim.appimage --appimage-extract-and-run "$@"
WRAPPER
chmod +x /home/testuser/.local/bin/nvim

# Copy nvim config
COPY nvim/.config/nvim /home/testuser/.config/nvim
RUN chown -R testuser:testuser /home/testuser

# Set up environment
ENV HOME=/home/testuser
ENV PATH=/home/testuser/.local/bin:$PATH
ENV XDG_CONFIG_HOME=/home/testuser/.config
ENV XDG_DATA_HOME=/home/testuser/.local/share
ENV XDG_CACHE_HOME=/home/testuser/.cache
ENV XDG_STATE_HOME=/home/testuser/.local/state

# Install tree-sitter-cli
RUN npm install -g tree-sitter-cli

# Run prep-nvim.sh as testuser
USER testuser
WORKDIR /home/testuser

# Install uv for Python tools
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/home/testuser/.local/bin:$PATH

# Bootstrap lazy.nvim and sync plugins
RUN mkdir -p /home/testuser/.local/share/nvim/lazy && \
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable /home/testuser/.local/share/nvim/lazy/lazy.nvim

# Copy prep script
COPY airgap/prep-nvim.sh /tmp/prep-nvim.sh

# Run preparation (this downloads all plugins, Mason packages, treesitter)
RUN bash /tmp/prep-nvim.sh || echo " prep-nvim completed with warnings"

# Create output directory
RUN mkdir -p /output

# Bundle the data
RUN tar -czf /output/nvim-data.tar.gz -C /home/testuser/.local/share nvim 2>/dev/null || true
RUN tar -czf /output/nvim-cache.tar.gz -C /home/testuser/.cache nvim 2>/dev/null || true
RUN tar -czf /output/nvim-state.tar.gz -C /home/testuser/.local/state nvim 2>/dev/null || true

# List what we created
RUN ls -lh /output/
EOF

# Build Docker image
echo "==> Building Docker image with $BASE_IMAGE..."
docker build --build-arg BASE_IMAGE="$BASE_IMAGE" -t nvim-prep-$DISTRO -f "$DOCKERFILE" "$SCRIPT_DIR/.." || {
    echo "ERROR: Docker build failed"
    rm -f "$DOCKERFILE"
    exit 1
}

# Extract the bundles
echo ""
echo "==> Extracting nvim bundles from container..."
docker create --name nvim-extract nvim-prep-$DISTRO
docker cp nvim-extract:/output/nvim-data.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-data.tar.gz not found"
docker cp nvim-extract:/output/nvim-cache.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-cache.tar.gz not found"
docker cp nvim-extract:/output/nvim-state.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-state.tar.gz not found"

# Cleanup
docker rm nvim-extract
docker rmi nvim-prep-$DISTRO
rm -f "$DOCKERFILE"

# Report results
echo ""
echo "==> Results:"
ls -lh "$CACHE"/nvim-*.tar.gz 2>/dev/null || echo "  No bundles created"

if [[ -f "$CACHE/nvim-data.tar.gz" ]]; then
    echo ""
    echo "✓ nvim-data.tar.gz is ready!"
    echo "  Size: $(du -h "$CACHE/nvim-data.tar.gz" | cut -f1)"
    echo ""
    echo "To add to airgap bundle:"
    echo "  cp $CACHE/nvim-data.tar.gz airgap/cache/"
    echo "  bash airgap/bundle.sh"
else
    echo ""
    echo "✗ Failed to create nvim-data.tar.gz"
    echo "  Check Docker logs above for errors"
fi
