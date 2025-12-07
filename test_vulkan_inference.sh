#!/bin/bash
set -e

# Configuration
MODEL_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
MODEL_FILE="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
IMAGE="localhost/llama-vulkan:latest"

echo "🚀 Testing Track E: Vulkan Inference"

# 1. Download Model if needed
if [ ! -f "$MODEL_FILE" ]; then
    echo "📥 Downloading TinyLlama (669MB)..."
    wget -q --show-progress "$MODEL_URL" -O "$MODEL_FILE"
else
    echo "✅ Model found: $MODEL_FILE"
fi

# 2. Run Inference
echo "🔥 Running Inference on gfx1151 (Vulkan)..."
echo "   Command: llama-cli -m $MODEL_FILE -p 'Hello, how are you?' -n 128 -ngl 999 -fa 1"

podman run --rm \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    -v $(pwd):/models \
    $IMAGE \
    /app/llama.cpp/build/bin/llama-cli \
    -m /models/$MODEL_FILE \
    -p "User: Hello! Assistant:" \
    -n 128 \
    -ngl 999 \
    -fa 1 \
    --no-mmap

echo "✅ Test Complete!"
