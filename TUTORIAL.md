# Continuous Build Tutorial: vLLM & PyTorch on ROCm gfx1151

This guide explains how to use the **reproducible** continuous build system to compile vLLM and PyTorch from source for AMD Radeon gfx1151 (Strix Point/Halo) hardware.

## Prerequisites

### Host System (aimax)
-   **OS**: Linux (Fedora/RHEL/Ubuntu)
-   **ROCm Drivers**: Ensure kernel-level ROCm drivers are installed and loaded (`/dev/kfd` exists).
-   **Firmware**: Ensure `amdgpu` firmware is up-to-date.

### User System (macOS)
-   SSH access to `aimax`.
-   `ansible` (optional, script will attempt to install or run on host).

## Pre-Flight Checklist (Critical)

Before running the build or vLLM, ensure the following:

1.  **BIOS VRAM Allocation**: Strix Halo uses Unified Memory. Go to your BIOS (usually under "IO Ports" -> "Integrated Graphics") and set "UMA Frame Buffer Size" to the maximum available (e.g., 64GB+). "Auto" may not allocate enough for large models.
2.  **Swap Space**: Compiling vLLM is memory-intensive. Ensure you have at least 32GB of swap space active.
    ```bash
    free -h
    ```
3.  **Permissions**: Ensure your user is in the `video` and `render` groups (handled by `run_setup.sh`, but requires a re-login).

## Quick Start

1.  **Connect to the server**:
    ```bash
    ssh user@aimax
    cd /path/to/aimax/repo
    ```

2.  **Run Host Setup (One-time)**:
    We use Ansible to configure the host (install Podman, set permissions).
    ```bash
    ssh -t user@aimax "cd ~/aimax_build && ./run_setup.sh"
    ```
    *Note: The `-t` flag is required to enter your sudo password remotely.*

3.  **Build the Image**:
    Use the new hybrid build script:
    ```bash
    ./build_amd.sh
    ```
    This creates `localhost/strix-vllm:amd-hybrid`.

4.  **Run Inference**:
    Use the test script which handles all the complex environment variables:
    ```bash
    ./test_inference.sh
    ```
    
    **Manual Run Command (for reference):**
    ```bash
    podman run -it \
        --device=/dev/kfd --device=/dev/dri --group-add video \
        --security-opt seccomp=unconfined \
        -p 8000:8000 \
        -e HSA_OVERRIDE_GFX_VERSION="11.0.0" \
        -e LD_LIBRARY_PATH="/opt/venv/lib/python3.12/site-packages/torch/lib:$LD_LIBRARY_PATH" \
        localhost/strix-vllm:amd-hybrid
    ```

## Maintenance & Updates

### Updating Versions
All versions are pinned in `versions.env`. To update:

1.  **Edit `versions.env`**:
    ```bash
    nano versions.env
    ```
2.  **Update ROCm/PyTorch**:
    -   Check [TheRock Nightlies](https://rocm.nightlies.amd.com/v2/gfx1151/) for new versions.
    -   Update `TORCH_VERSION`, `TORCHAUDIO_VERSION`, etc.
3.  **Update vLLM/Flash Attention**:
    -   Find the new git commit hash you want to build.
    -   Update `VLLM_COMMIT` and `FLASH_ATTENTION_COMMIT`.
4.  **Rebuild**:
    ```bash
    ./build_pipeline.sh --no-cache
    ```

### Reproducibility
-   **Lockfiles**: Python dependencies are pinned in `requirements.lock`. If you need to add/update dependencies, edit this file.
-   **Commits**: We use full git commit hashes, not branches (like `main`), to ensure the code doesn't change under our feet.

### Logging & Debugging
The build pipeline now automatically logs all output to a file (e.g., `build_log_YYYYMMDD_HHMMSS.txt`).

To fetch these logs from the remote server to your local machine for review:
```bash
./fetch_logs.sh
```
This will download all build logs to a local `./logs` directory.

## Usage

Once built, you can run the container manually:

```bash
podman run -it \
    --device=/dev/kfd --device=/dev/dri --group-add video \
    --security-opt seccomp=unconfined \
    -p 8000:8000 \
    strix-vllm:local
```

## Troubleshooting

-   **Build Fails on PyTorch**: The nightly version specified in `versions.env` might be gone (they rotate). Check the URL in the file and update it.
-   **"Invalid Device Function"**: This usually means the code wasn't compiled for `gfx1151`. Ensure `PYTORCH_ROCM_ARCH="gfx1151"` is set (it is by default in the Dockerfile).
-   **Flash Attention Build Failures**: Flash Attention is very sensitive to compiler versions. If it fails, try disabling it by commenting out the relevant section in the Dockerfile or using a different `FLASH_ATTENTION_COMMIT`.

## Resources & Troubleshooting

### Common Issues
-   **"Invalid Device Function"**: Ensure `VLLM_TARGET_DEVICE="rocm"` was set during build (it is in our Dockerfile) and `PYTORCH_ROCM_ARCH="gfx1151"` is set at runtime.
-   **Memory Errors**: Strix Halo's unified memory can be fragmented. If you see OOM or allocation failures, try reducing `max-num-seqs` or adjusting `amdgpu` kernel parameters.
-   **HIP Crashes**: If `hipBLASLt` causes instability, set `TORCH_BLAS_PREFER_HIPBLASLT=0`.
-   **Device Not Found**: As a last resort, try spoofing a supported architecture: `export HSA_OVERRIDE_GFX_VERSION=11.0.0` (though `gfx1151` support should be native).

### Watchlist & Links
Keep an eye on these for upstream fixes:
-   [ROCm Issue #5339](https://github.com/ROCm/ROCm/issues/5339) - General ROCm tracking.
-   [ROCm 7.0.2 Compatibility Guide](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html#rocm-7-0-2)
-   [Framework Community Guide](https://community.frame.work/t/compiling-vllm-from-source-on-strix-halo/77241)
