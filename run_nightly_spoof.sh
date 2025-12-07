#!/bin/bash
set -e

echo "🚀 Starting Track C: Nightly Spoof..."
echo "   Image: rocm/vllm-dev:nightly"
echo "   Spoofing: gfx1100 (Navi31)"

# Use HSA_OVERRIDE_GFX_VERSION to trick the runtime into thinking we are on a supported architecture
# 11.0.0 = gfx1100 (Radeon 7900 XTX) which is close to gfx1151 (Strix Point)
# 10.3.0 = gfx1030 (Radeon 6800)

export HSA_OVERRIDE_GFX_VERSION=11.0.0
export ROC_ENABLE_PRE_VEGA=1

echo "Running vLLM with spoofing..."
podman run -it --rm \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --env HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    --env ROC_ENABLE_PRE_VEGA=1 \
    docker.io/rocm/vllm-dev:nightly \
    python3 -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}'); import vllm; print(f'vLLM: {vllm.__version__}')"
