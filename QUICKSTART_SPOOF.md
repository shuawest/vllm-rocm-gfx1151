# Quickstart: Running vLLM on Strix Point (gfx1151)

**Status: VERIFIED WORKING (2025-12-06)**

This guide describes the "Nightly Spoof" strategy, which allows you to run vLLM on AMD Radeon `gfx1151` (Strix Point/Halo) hardware immediately using the official ROCm nightly container.

## The Strategy
We use the official `rocm/vllm-dev:nightly` image but force the ROCm runtime to treat the GPU as `gfx1100` (Navi 31/Radeon 7900 XTX). Since `gfx1151` (RDNA 3.5) is binary compatible with `gfx1100` (RDNA 3), this allows us to bypass architecture checks and run pre-compiled kernels.

## Prerequisites
- Linux Host with AMD GPU (`gfx1151`)
- Podman or Docker
- AMD GPU Drivers installed

## Running Inference

### 1. Interactive Mode (Quick Test)
Run this command to drop into a container shell:

```bash
podman run -it --rm \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --env HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    --env ROC_ENABLE_PRE_VEGA=1 \
    docker.io/rocm/vllm-dev:nightly \
    /bin/bash
```

Inside the container, you can run python:
```python
import torch
import vllm
print(f"PyTorch: {torch.__version__}")
print(f"vLLM: {vllm.__version__}")
```

### 2. Running the Automated Script
We have provided a script `run_nightly_spoof.sh` that automates the setup.

```bash
./run_nightly_spoof.sh
```

### 3. Running an OpenAI-Compatible Server
To serve a model (e.g., `facebook/opt-125m`) on port 8000:

```bash
podman run --rm -it \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    --env HSA_OVERRIDE_GFX_VERSION=11.0.0 \
    --env ROC_ENABLE_PRE_VEGA=1 \
    -p 8000:8000 \
    docker.io/rocm/vllm-dev:nightly \
    vllm serve facebook/opt-125m
```

## Troubleshooting
- **Permission Denied**: Ensure your user is in the `render` or `video` group.
- **HSA Error**: Verify `HSA_OVERRIDE_GFX_VERSION=11.0.0` is set.
