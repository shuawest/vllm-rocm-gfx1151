#!/bin/bash
set -e

echo "🚀 Building Locked Spoof Image..."
echo "   Base: rocm/vllm-dev:nightly"
echo "   Config: HSA_OVERRIDE_GFX_VERSION=11.0.0 baked in"

podman build \
  -t localhost/strix-vllm:spoof-locked-v1 \
  -f Dockerfile.spoof_locked \
  .

echo "✅ Build Complete!"
echo "Run with: podman run --device /dev/kfd --device /dev/dri --security-opt seccomp=unconfined -p 8000:8000 localhost/strix-vllm:spoof-locked-v1"
