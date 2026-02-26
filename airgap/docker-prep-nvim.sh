#!/usr/bin/env bash
# docker-prep-nvim.sh — Generate nvim data bundle using Docker
# This creates nvim-data.tar.gz by deploying the full environment in a container,
# then running prep-nvim.sh to generate the plugin data.
# Usage: ./docker-prep-nvim.sh [fedora|ubi9|ubuntu] [BUNDLE_PATH]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISTRO="${1:-ubuntu}"
BUNDLE_PATH="${2:-}"
CACHE="${SCRIPT_DIR}/cache"
mkdir -p "$CACHE"

echo "==> Building nvim data bundle using Docker ($DISTRO)"
echo "    Default is now Ubuntu (for RunAI). Use 'fedora' arg for Fedora."
echo "    This will take 5-10 minutes..."
echo ""

# Determine base image
case "$DISTRO" in
    fedora)    BASE_IMAGE="registry.fedoraproject.org/fedora:43" ;;
    ubuntu)    BASE_IMAGE="ubuntu:24.04" ;;
    *)         echo "ERROR: Unknown distro: $DISTRO (use: fedora, ubuntu)"; exit 1 ;;
esac

# Find bundle if not specified
if [[ -z "$BUNDLE_PATH" ]]; then
    BUNDLE_PATH="$(ls -t "$SCRIPT_DIR"/devenv-bundle-*.tar.gz 2>/dev/null | head -1)"
    if [[ -z "$BUNDLE_PATH" ]]; then
        echo "ERROR: No bundle specified and no devenv-bundle-*.tar.gz found in $SCRIPT_DIR"
        echo "Usage: $0 [distro] [path/to/devenv-bundle-YYYYMMDD.tar.gz]"
        exit 1
    fi
    echo "Auto-detected bundle: $BUNDLE_PATH"
fi

if [[ ! -f "$BUNDLE_PATH" ]]; then
    echo "ERROR: Bundle not found: $BUNDLE_PATH"
    exit 1
fi

# Create temporary build directory
BUILD_DIR=$(mktemp -d)

# Copy bundle to build context
cp "$BUNDLE_PATH" "$BUILD_DIR/bundle.tar.gz"

# Copy repo scripts
mkdir -p "$BUILD_DIR/airgap" "$BUILD_DIR/bootstrap"
cp "$SCRIPT_DIR/deploy.sh" "$BUILD_DIR/airgap/"
cp "$SCRIPT_DIR/prep-nvim.sh" "$BUILD_DIR/airgap/"
cp -r "$SCRIPT_DIR/../bootstrap" "$BUILD_DIR/"
cp -r "$SCRIPT_DIR/../nvim" "$BUILD_DIR/"

# Create Dockerfile
cat > "$BUILD_DIR/Dockerfile" << 'DOCKERFILE'
ARG BASE_IMAGE
FROM ${BASE_IMAGE}

# Install sudo and basic tools needed for deploy
RUN if command -v dnf &>/dev/null; then \
        dnf install -y sudo which; \
    elif command -v apt-get &>/dev/null; then \
        apt-get update && apt-get install -y sudo; \
    fi

# Create a working directory
WORKDIR /workspace

# Copy the bundle and scripts
COPY bundle.tar.gz /workspace/
COPY airgap/deploy.sh /workspace/airgap/
COPY airgap/prep-nvim.sh /workspace/airgap/
COPY bootstrap /workspace/bootstrap
COPY nvim /workspace/nvim

# Run deploy.sh to set up the environment
RUN bash /workspace/airgap/deploy.sh --force /workspace/bundle.tar.gz

# Switch to the created user for nvim operations
USER dev
ENV HOME=/home/dev
ENV PATH=/home/dev/.local/bin:$PATH
ENV XDG_CONFIG_HOME=/home/dev/.config
ENV XDG_DATA_HOME=/home/dev/.local/share
ENV XDG_CACHE_HOME=/home/dev/.cache
ENV XDG_STATE_HOME=/home/dev/.local/state

# Run prep-nvim.sh to generate nvim data
RUN bash /workspace/airgap/prep-nvim.sh || echo "prep-nvim completed"

# Bundle the nvim data
RUN mkdir -p /output && \
    tar -czf /output/nvim-data.tar.gz -C /home/dev/.local/share nvim && \
    tar -czf /output/nvim-cache.tar.gz -C /home/dev/.cache nvim 2>/dev/null || true && \
    tar -czf /output/nvim-state.tar.gz -C /home/dev/.local/state nvim 2>/dev/null || true && \
    ls -lh /output/

# Set output as volume
VOLUME /output
DOCKERFILE

# Build Docker image
echo "==> Building Docker image with $BASE_IMAGE..."
echo "    (This will deploy the bundle and generate nvim data)"
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
