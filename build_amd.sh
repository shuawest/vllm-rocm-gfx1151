#!/bin/bash
set -e

IMAGE_NAME="localhost/strix-vllm:amd-hybrid"
DOCKERFILE="Dockerfile.amd"

echo "🚀 Starting AMD Hybrid Build..."
echo "Image: $IMAGE_NAME"
echo "Dockerfile: $DOCKERFILE"

podman build -t $IMAGE_NAME -f $DOCKERFILE .

echo "✅ Build Complete!"
