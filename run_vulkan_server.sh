#!/bin/bash
set -e

# Configuration
IMAGE="localhost/llama-vulkan:latest"
MODEL_FILE="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
PORT=8080

echo "🚀 Starting Vulkan Inference Server (Track E)..."
echo "   Image: $IMAGE"
echo "   Model: $MODEL_FILE"
echo "   Port:  $PORT"

# Run the container
# Note: No --entrypoint override needed, default is llama-server
podman run --rm -d \
    --name vulkan_server \
    --replace \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    -v $(pwd):/models:Z \
    -p $PORT:$PORT \
    $IMAGE \
    -m /models/$MODEL_FILE \
    --host 0.0.0.0 \
    --port $PORT \
    -n 2048 \
    -ngl 999 \
    -fa 1 \
    --no-mmap

echo "✅ Server started!"
echo "   Test with: curl http://localhost:$PORT/v1/chat/completions ..."
echo "   Logs: podman logs -f vulkan_server"
