# vLLM on AMD Strix Point (gfx1151)

This repository contains the build system for running **vLLM** on AMD Ryzen AI 300 Series (Strix Point) hardware, specifically the **Ryzen AI 9 HX 370**.

# vLLM on AMD Strix Point (gfx1151)

This repository contains the build system for running **vLLM** on AMD Ryzen AI 300 Series (Strix Point) hardware.

# vLLM on AMD Strix Point (gfx1151)

This repository contains the build system for running **vLLM** on AMD Ryzen AI 300 Series (Strix Point) hardware.

# vLLM on AMD Strix Point (gfx1151)

This repository contains the build system for running **vLLM** on AMD Ryzen AI 300 Series (Strix Point) hardware.

> [!WARNING]
> **Experimental Status**: Both "Hybrid" (Build #32) and "Nuclear" (Build #33) strategies currently result in a **runtime hang/deadlock** during inference.
> The vLLM server starts, but the driver hangs when executing kernels.
> We are investigating driver-level issues.

## Current Status
- **Build #32 (Hybrid/Spoofed)**: Hangs during inference.
- **Build #33 (Nuclear)**: Hangs during inference (confirmed 80+ min deadlock).

## Build Instructions (Experimental)

### Build #33 (Nuclear Option)
This is the active build strategy, but be aware of the runtime hang.

```bash
./build_nuclear.sh
```

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
