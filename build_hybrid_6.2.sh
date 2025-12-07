#!/bin/bash
set -e

# Build the Hybrid 6.2 image
echo "🚀 Starting Build #35: Hybrid Option (ROCm 6.2)..."
echo "   Target: gfx1151"
echo "   Base: rocm/dev-ubuntu-24.04:6.2.4"
echo "   PyTorch: Official Wheels (ROCm 6.2)"
echo "   vLLM: v0.10.3 (Source)"

podman build \
  -t localhost/strix-vllm:hybrid-6.2 \
  -f Dockerfile.hybrid_6.2 \
  .

echo "✅ Build #35 Complete!"
