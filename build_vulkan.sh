#!/bin/bash
set -e

echo "🚀 Building Track E: llama.cpp (Vulkan)..."
echo "   Goal: Max prompt processing speed (~884 tok/s)"

podman build \
  -t localhost/llama-vulkan:latest \
  -f Dockerfile.vulkan \
  .

echo "✅ Build Complete!"
echo "Run with: podman run --device /dev/dri --security-opt seccomp=unconfined -p 8080:8080 localhost/llama-vulkan:latest -m /path/to/model.gguf -fa 1 --no-mmap -ngl 999"
