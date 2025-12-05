# vLLM on AMD Strix Point (gfx1151)

This repository contains the build system for running **vLLM** on AMD Ryzen AI 300 Series (Strix Point) hardware, specifically the **Ryzen AI 9 HX 370**.

## 🚀 Quick Start (Working Configuration)

The only configuration currently confirmed to work is the **AMD Hybrid Strategy** (Build #32), which uses architecture spoofing to run `gfx1100` (Navi 31) kernels on `gfx1151` hardware.

### 1. Build the Image
Run this on the `aimax` host:

```bash
./build_amd.sh
```
*This builds `localhost/strix-vllm:amd-hybrid` using the official AMD ROCm 7.1 base image and compiles vLLM from source.*

### 2. Run Inference
Start the server and run a test query:

```bash
./test_inference.sh
```
*This script sets the critical environment variables for spoofing and library paths.*

---

## Technical Details

### The "Hybrid + Spoofing" Strategy
- **Base Image**: `rocm/vllm-dev:rocm7.1.1...` (Official AMD)
- **PyTorch**: Pre-installed v2.8 (Nightly)
- **vLLM**: Compiled from source for `gfx1100`
- **Spoofing**: `HSA_OVERRIDE_GFX_VERSION="11.0.0"` forces the runtime to treat the iGPU as a Radeon 7900 XTX.
- **Fixes**: `LD_LIBRARY_PATH` is patched at runtime to locate PyTorch libraries.

### Other Strategies (Reference)
- **Fedora/Ubuntu**: Deprecated. Stable PyTorch wheels do not support `gfx1151`.
- **TheRock Nightlies**: Failed due to binary incompatibility (double free errors).
- **Nuclear Option**: Full source build of PyTorch + vLLM (available in `Dockerfile.nuclear` but untested/slow).
