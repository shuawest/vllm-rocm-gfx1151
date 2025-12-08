#!/bin/bash
set -e

# Configuration
HF_TOKEN=$(cat hf_token.txt)

echo "🛑 Stopping existing LLaVA containers..."
podman stop vllm-llava || true
podman rm vllm-llava || true

echo "🚀 Starting LLaVA 1.6 (User Mode)..."
# Using the specific ROCm tag we found
IMAGE="docker.io/rocm/vllm-dev:rocm6.4.2_navi_ubuntu24.04_py3.12_pytorch_2.7_vllm_0.9.2"

podman run -d --rm \
    --name vllm-llava \
    --device /dev/kfd --device /dev/dri \
    --security-opt label=disable \
    --shm-size=16g \
    -v $HOME/.cache/huggingface:/root/.cache/huggingface \
    -e HUGGING_FACE_HUB_TOKEN="$HF_TOKEN" \
    -e HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    -p 8001:8000 \
    "$IMAGE" \
    python3 -m vllm.entrypoints.openai.api_server \
    --model llava-hf/llava-v1.6-mistral-7b-hf \
    --gpu-memory-utilization 0.30 \
    --trust-remote-code --max-model-len 8192

echo "⏳ Waiting for LLaVA to initialize..."
echo "   (Tail logs with: podman logs -f vllm-llava)"
