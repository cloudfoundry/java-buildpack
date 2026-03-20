#!/bin/bash

set -euo pipefail

# Script to package the Java buildpack using a container
# This allows building on Fedora or any system without installing Ruby/bundler locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILDPACK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Detect container runtime (podman or docker)
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found. Please install one of them."
    exit 1
fi

echo "Using container runtime: ${CONTAINER_CMD}"
echo "Buildpack directory: ${BUILDPACK_DIR}"

# Use the CI Dockerfile to build a container image
IMAGE_NAME="java-buildpack-builder:local"

# Check if image exists, if not build it
if ! ${CONTAINER_CMD} images | grep -q "${IMAGE_NAME}"; then
    echo ""
    echo "Building container image (this will take a few minutes)..."
    ${CONTAINER_CMD} build -t "${IMAGE_NAME}" -f "${BUILDPACK_DIR}/ci/Dockerfile" "${BUILDPACK_DIR}/ci"
else
    echo "Using existing container image: ${IMAGE_NAME}"
fi

echo ""
echo "Packaging buildpack in container..."
${CONTAINER_CMD} run --rm \
    -v "${BUILDPACK_DIR}:/workspace:z" \
    -w /workspace \
    -e BUNDLE_GEMFILE=/workspace/Gemfile \
    "${IMAGE_NAME}" \
    bash -c '
        set -euo pipefail
        echo "Installing Ruby dependencies..."
        eval "$(rbenv init -)"
        bundle install --jobs=4 --retry=3 >/dev/null 2>&1
        
        echo "Cleaning previous builds..."
        bundle exec rake clean >/dev/null 2>&1
        
        echo "Packaging buildpack (OFFLINE mode)..."
        bundle exec rake package OFFLINE=true 2>&1 | grep -E "(Creating|Downloaded|Pinning|^-rw)" || true
        
        # Find the generated zip file
        ZIP_FILE=$(ls -t build/*.zip 2>/dev/null | head -1)
        if [ -z "$ZIP_FILE" ]; then
            echo "Error: No buildpack zip file found in build/"
            exit 1
        fi
        
        echo ""
        echo "Generated: $ZIP_FILE"
        ls -lh "$ZIP_FILE"
    '

# The buildpack is now in build/java-buildpack-dev.zip
BUILDPACK_FILE="${BUILDPACK_DIR}/build/java-buildpack-dev.zip"
if [ -f "${BUILDPACK_FILE}" ]; then
    echo ""
    echo "Success! Buildpack is available at: ${BUILDPACK_FILE}"
    echo "Size: $(du -h "${BUILDPACK_FILE}" | cut -f1)"
else
    echo "Error: Failed to create buildpack"
    exit 1
fi
