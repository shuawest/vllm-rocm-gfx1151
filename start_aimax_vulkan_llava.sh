#!/bin/bash
set -e

# Configuration
MODEL_DIR="/data/models"
IMAGE="localhost/llama-vulkan:latest"
REPO="cjpais/llava-1.6-mistral-7b-gguf"
FILE="llava-v1.6-mistral-7b.Q4_K_M.gguf"
PROJ="mmproj-model-f16.gguf"

# Ensure model directory exists
mkdir -p "$MODEL_DIR"

# Download Model
if [ ! -f "$MODEL_DIR/$FILE" ]; then
    echo "⬇️  Downloading Model..."
    huggingface-cli download $REPO $FILE --local-dir $MODEL_DIR --local-dir-use-symlinks False
fi

# Download Projector
if [ ! -f "$MODEL_DIR/$PROJ" ]; then
    echo "⬇️  Downloading Projector..."
    huggingface-cli download $REPO $PROJ --local-dir $MODEL_DIR --local-dir-use-symlinks False
fi

echo "🛑 Stopping existing LLaVA containers..."
podman stop llama-vulkan-llava-debug || true
podman rm llama-vulkan-llava-debug || true

echo "🚀 Starting LLaVA 1.6 (Vulkan User Mode)..."
podman run -d --rm \
    --name llama-vulkan-llava-debug \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    -v $MODEL_DIR:/models:Z \
    -p 8001:8001 \
    $IMAGE \
    -m /models/$FILE \
    --mmproj /models/$PROJ \
    --host 0.0.0.0 \
    --port 8001 \
    -n 8192 \
    -ngl 999 \
    -fa 1 \
    --no-mmap

echo "⏳ Waiting for LLaVA to initialize..."
echo "   (Tail logs with: podman logs -f llama-vulkan-llava-debug)"
