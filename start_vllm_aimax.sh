#!/bin/bash
set -e

MODEL_PATH=$1
PORT=${2:-8000}

if [ -z "$MODEL_PATH" ]; then
    echo "Usage: $0 <path_to_quantized_model> [port]"
    exit 1
fi

echo "🚀 Starting vLLM with model: $MODEL_PATH on port $PORT"

# Ensure /dev/kfd exists (ROCm requirement)
if [ ! -e /dev/kfd ]; then
    echo "❌ Error: /dev/kfd not found. ROCm driver might not be loaded."
    exit 1
fi

podman run -it --rm \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --group-add video \
    -v $MODEL_PATH:/app/model:Z \
    -p $PORT:8000 \
    -e HIP_VISIBLE_DEVICES=0 \
    -e HSA_OVERRIDE_GFX_VERSION=11.5.1 \
    aimax-vllm \
    python3 -m vllm.entrypoints.openai.api_server \
    --model /app/model \
    --quantization awq \
    --dtype float16 \
    --host 0.0.0.0 \
    --port 8000
