#!/bin/bash
set -e

IMAGE_NAME="localhost/strix-vllm:nuclear"
DOCKERFILE="Dockerfile.nuclear"

echo "☢️  Starting NUCLEAR Build (PyTorch + vLLM Source)..."
echo "Image: $IMAGE_NAME"
echo "Dockerfile: $DOCKERFILE"
echo "WARNING: This will take several hours."

podman build -t $IMAGE_NAME -f $DOCKERFILE .

echo "✅ Nuclear Build Complete!"
