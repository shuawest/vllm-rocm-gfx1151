#!/bin/bash
set -e

# Build #34: Nuclear Option (ROCm 6.2)
# Usage: ./build_nuclear_6.2.sh

echo "🚀 Starting Build #34: Nuclear Option (ROCm 6.2)..."
echo "   Target: gfx1151"
echo "   Base: rocm/dev-ubuntu-24.04:6.2.4"
echo "   PyTorch: v2.5.1 (Source)"
echo "   vLLM: v0.10.3 (Source)"

# Build the Docker image
# We use --no-cache to ensure a clean build
podman build \
    -f Dockerfile.nuclear_6.2 \
    -t localhost/strix-vllm:nuclear-6.2 \
    .

echo "✅ Build Complete!"
echo "   Image: localhost/strix-vllm:nuclear-6.2"
