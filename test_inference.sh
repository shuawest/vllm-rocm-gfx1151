#!/bin/bash
# Script to run the vLLM container and test inference
set -e

IMAGE_NAME="localhost/strix-vllm:v0.10.3-rocm6.3"
CONTAINER_NAME="vllm_inference_test"
MODEL="facebook/opt-125m" # Small model for quick testing

echo "Stopping any existing container..."
podman stop $CONTAINER_NAME 2>/dev/null || true
podman rm $CONTAINER_NAME 2>/dev/null || true

echo "Starting vLLM container..."
# Note: Using --device /dev/kfd --device /dev/dri for ROCm access
podman run -d \
    --name $CONTAINER_NAME \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --cap-add=SYS_PTRACE \
    --group-add video \
    --ipc=host \
    -p 8000:8000 \
    -e HSA_OVERRIDE_GFX_VERSION="11.0.0" \
    -e VLLM_USE_V1=0 \
    localhost/strix-vllm:amd-hybrid \
    python3 -m vllm.entrypoints.openai.api_server \
    --model Qwen/Qwen2.5-0.5B-Instruct \
    --dtype float16 \
    --max-model-len 2048 \
    --gpu-memory-utilization 0.8

echo "Waiting for vLLM to initialize (this may take a minute)..."
# Loop to check health
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null; then
        echo "vLLM is ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 5
done

echo "Running inference test..."
curl -X POST http://localhost:8000/v1/completions \
    -H "Content-Type: application/json" \
    -d '{
        "model": "'$MODEL'",
        "prompt": "San Francisco is a",
        "max_tokens": 20,
        "temperature": 0
    }'

echo -e "\n\nTest complete. Logs:"
podman logs --tail 20 $CONTAINER_NAME
