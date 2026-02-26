#!/usr/bin/env bash
# docker-prep-nvim-simple.sh — Generate nvim data bundle using Docker (simplified version)
# This creates nvim-data.tar.gz by running prep-nvim.sh in a clean Docker environment.
# Only requires nvim AppImage to be available, doesn't need full bundle deployment.
# Usage: ./docker-prep-nvim-simple.sh [fedora|ubi9|ubuntu]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO="${1:-fedora}"
CACHE="${SCRIPT_DIR}/cache"
mkdir -p "$CACHE"

echo "==> Building nvim data bundle using Docker ($DISTRO) - Simplified"
echo "    This will take 5-10 minutes..."
echo ""

# Determine base image
case "$DISTRO" in
    fedora)    BASE_IMAGE="registry.fedoraproject.org/fedora:43" ;;
    ubi9)      BASE_IMAGE="registry.access.redhat.com/ubi9/ubi:latest" ;;
    ubuntu)    BASE_IMAGE="ubuntu:24.04" ;;
    *)         echo "ERROR: Unknown distro: $DISTRO (use: fedora, ubi9, ubuntu)"; exit 1 ;;
esac

# Create temporary build directory
BUILD_DIR=$(mktemp -d)

# Copy just the necessary files
cp "$SCRIPT_DIR/prep-nvim.sh" "$BUILD_DIR/"
cp -r "$SCRIPT_DIR/../nvim" "$BUILD_DIR/"

# Create Dockerfile
cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install required dependencies
RUN if command -v dnf &>/dev/null; then \
        dnf install -y curl git nodejs npm tar gzip which; \
    elif command -v apt-get &>/dev/null; then \
        apt-get update && apt-get install -y curl git nodejs npm tar gzip; \
    fi

# Create test user and directories
RUN useradd --create-home --shell /bin/bash testuser && \
    mkdir -p /home/testuser/.local/bin && \
    chown -R testuser:testuser /home/testuser

# Download nvim AppImage (updated to 0.11.2 for LazyVim compatibility)
RUN curl -L -o /home/testuser/.local/bin/nvim.appimage \
    "https://github.com/neovim/neovim/releases/download/v0.11.2/nvim-linux-x86_64.appimage" && \
    chmod +x /home/testuser/.local/bin/nvim.appimage && \
    chown testuser:testuser /home/testuser/.local/bin/nvim.appimage

# Create nvim wrapper
RUN echo '#!/bin/bash' > /home/testuser/.local/bin/nvim && \
    echo 'exec /home/testuser/.local/bin/nvim.appimage --appimage-extract-and-run "$@"' >> /home/testuser/.local/bin/nvim && \
    chmod +x /home/testuser/.local/bin/nvim && \
    chown testuser:testuser /home/testuser/.local/bin/nvim

# Copy nvim config
COPY nvim/.config/nvim /home/testuser/.config/nvim
RUN chown -R testuser:testuser /home/testuser

# Install tree-sitter-cli
RUN npm install -g tree-sitter-cli

# Set up environment
USER testuser
ENV HOME=/home/testuser
ENV PATH=/home/testuser/.local/bin:$PATH
ENV XDG_CONFIG_HOME=/home/testuser/.config
ENV XDG_DATA_HOME=/home/testuser/.local/share
ENV XDG_CACHE_HOME=/home/testuser/.cache
ENV XDG_STATE_HOME=/home/testuser/.local/state

# Bootstrap lazy.nvim
RUN mkdir -p /home/testuser/.local/share/nvim/lazy && \
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
        --branch=stable /home/testuser/.local/share/nvim/lazy/lazy.nvim

# Copy and run prep-nvim.sh
COPY prep-nvim.sh /tmp/prep-nvim.sh
RUN bash /tmp/prep-nvim.sh || echo "prep-nvim completed with warnings"

# Bundle the nvim data
RUN mkdir -p /output && \
    tar -czf /output/nvim-data.tar.gz -C /home/testuser/.local/share nvim && \
    tar -czf /output/nvim-cache.tar.gz -C /home/testuser/.cache nvim 2>/dev/null || true && \
    tar -czf /output/nvim-state.tar.gz -C /home/testuser/.local/state nvim 2>/dev/null || true && \
    ls -lh /output/

VOLUME /output
DOCKERFILE

# Build Docker image
echo "==> Building Docker image with $BASE_IMAGE..."
if ! docker build --build-arg BASE_IMAGE="$BASE_IMAGE" -t nvim-prep-$DISTRO -f "$BUILD_DIR/Dockerfile" "$BUILD_DIR" 2>&1; then
    echo "ERROR: Docker build failed"
    rm -rf "$BUILD_DIR"
    exit 1
fi

# Extract the bundles
echo ""
echo "==> Extracting nvim bundles from container..."
docker create --name nvim-extract nvim-prep-$DISTRO

docker cp nvim-extract:/output/nvim-data.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-data.tar.gz not found"
docker cp nvim-extract:/output/nvim-cache.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-cache.tar.gz not found (optional)"
docker cp nvim-extract:/output/nvim-state.tar.gz "$CACHE/" 2>/dev/null || echo "  ! nvim-state.tar.gz not found (optional)"

# Cleanup
docker rm nvim-extract 2>/dev/null || true
docker rmi nvim-prep-$DISTRO 2>/dev/null || true
rm -rf "$BUILD_DIR"

# Report results
echo ""
echo "==> Results:"
ls -lh "$CACHE"/nvim-*.tar.gz 2>/dev/null || echo "  No bundles created"

if [[ -f "$CACHE/nvim-data.tar.gz" ]]; then
    echo ""
    echo "✓ nvim-data.tar.gz is ready!"
    echo "  Size: $(du -h "$CACHE/nvim-data.tar.gz" | cut -f1)"
    echo "  Location: $CACHE/nvim-data.tar.gz"
    echo ""
    echo "To add to airgap bundle:"
    echo "  cp $CACHE/nvim-data.tar.gz airgap/cache/"
    echo "  bash airgap/bundle.sh  # Rebuilds with nvim data"
else
    echo ""
    echo "✗ Failed to create nvim-data.tar.gz"
    exit 1
fi
