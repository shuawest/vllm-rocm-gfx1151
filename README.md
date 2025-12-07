# vLLM on AMD Strix Point (gfx1151)

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Status](https://img.shields.io/badge/status-verified-success)
![Hardware](https://img.shields.io/badge/hardware-gfx1151-red)

This repository provides a working configuration for running **vLLM** on AMD **Strix Point** and **Strix Halo** APUs (RDNA 3.5, `gfx1151`).

Since `gfx1151` is not yet officially supported in upstream ROCm/vLLM builds, this project utilizes the binary compatibility with `gfx1100` (RDNA 3) to enable inference on this hardware. This is an experimental workaround that bypasses architecture checks to run pre-compiled kernels.

> [!IMPORTANT]
> **Host Kernel Requirement**: For Strix Halo (Ryzen AI Max 300), ensure your host is running Linux Kernel **6.16.9+**. This is critical for proper unified memory visibility (fixing the 16GB cap issue). Fedora 43 (Rawhide) is recommended.

---

## 🚀 Quickstart (The "Happy Path")

The easiest way to get started is to use our **Verified Locked Image**. This image is automatically tested on real `gfx1151` hardware and pinned to a known-good version.

### Option 1: Run the Pre-built Container
We publish a production-ready image to GitHub Container Registry. It comes with the necessary environment variables baked in.

```bash
# Pull and run the server (serving OPT-125M as an example)
podman run -it --rm \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    -p 8000:8000 \
    ghcr.io/shuawest/vllm-gfx1151-spoof-locked:latest \
    vllm serve facebook/opt-125m
```

### Option 2: Use the Helper Script
Clone this repository and use the provided script, which handles device permissions and flags for you.

```bash
git clone https://github.com/shuawest/vllm-rocm-gfx1151.git
cd vllm-rocm-gfx1151
./run_nightly_spoof.sh
```

---

## 🛠️ How It Works

### The "Spoofing" Strategy (Track C/D)
Since RDNA 3.5 (`gfx1151`) shares the same ISA as RDNA 3 (`gfx1100`), we can force the ROCm runtime to load kernels compiled for the latter.

-   **Base Image**: Official `rocm/vllm-dev:nightly` (pinned to a verified digest).
-   **Environment Overrides**:
    -   `HSA_OVERRIDE_GFX_VERSION=11.0.0`: Tells ROCm to treat the GPU as `gfx1100`.
    -   `ROC_ENABLE_PRE_VEGA=1`: Sometimes required for APU compatibility.

We maintain a **Continuous Verification** pipeline:
1.  A script (`verify_and_update_nightly.sh`) runs on a physical `gfx1151` machine.
2.  It pulls the latest nightly and runs a real inference test.
3.  If successful, it updates the `Dockerfile.spoof_locked` and pushes to this repo.
4.  GitHub Actions builds and publishes the new stable image.

---

## 🏗️ Build Strategies (Advanced)

We are actively developing and testing multiple build tracks to ensure long-term stability.

| Track | Name | Strategy | Status | Description |
| :--- | :--- | :--- | :--- | :--- |
| **D** | **Locked Spoof** | Custom Docker Image | ✅ **Recommended** | Extends verified nightly with baked-in config. Reproducible. |
| **C** | **Nightly Spoof** | Runtime Flags | ✅ **Working** | Running `rocm/vllm-dev:nightly` directly with env vars. Good for testing latest features. |
| **A** | **Nuclear Option** | Source Build | 🔄 Building | Full compilation of PyTorch & vLLM from source. Extremely slow (~4h) but theoretically most stable. |
| **B** | **Hybrid Option** | PyTorch Wheels | ⚠️ Experimental | Uses official ROCm wheels + vLLM source. Faster build, but debugging dependency issues. |

### Building from Source
If you wish to build the "Locked" image yourself:

```bash
./build_spoof_locked.sh
```

---

## 📂 Repository Structure

-   `Dockerfile.spoof_locked`: The recipe for the production image.
-   `run_nightly_spoof.sh`: Helper script for local testing.
-   `verify_and_update_nightly.sh`: The CI script that runs on hardware to verify new versions.
-   `QUICKSTART_SPOOF.md`: Detailed documentation for the spoofing strategy.
-   `antigravity_spec.md`: Technical specification and project journal.

## 🤝 Contributing

We welcome contributions! If you have `gfx1151` hardware, you can help by running the verification script and reporting issues.

1.  Fork the repo.
2.  Run `./verify_and_update_nightly.sh` to test the latest upstream changes.
3.  Submit a PR if you find a new working configuration.

---

**Maintainer**: [Your Name/Handle]
**License**: Apache 2.0
