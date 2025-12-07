# Project Spec: Continuous Build for PyTorch & vLLM on ROCm (gfx1151)

## Goal
Establish a robust, **reproducible** continuous build system for PyTorch and vLLM targeting AMD ROCm on **gfx1151** (Strix Point/Halo) hardware. The build should align with **Red Hat/Fedora** standards where possible, serving as a potential upstream contribution path.

## Hardware & Environment
-   **Target Hardware**: AMD Radeon gfx1151 (RDNA 3.5).
-   **Build Environment**: Docker/Podman container.
    -   **Base Image**: Fedora 43 (Rawhide/latest) or UBI 9 (if feasible). *Decision: Fedora 43 is chosen as the upstream for RHEL, providing the latest kernel/glibc needed for bleeding-edge ROCm.*
-   **Host**: `aimax` server.

## Components & Versioning Strategy (Reproducibility)

**Update (2025-12-03)**: After encountering persistent "double free or corruption" errors during build, research revealed critical insights about version stability and compatibility.

### Root Cause Analysis

The build failures stem from a **known incompatibility between TheRock-based PyTorch distributions and ROCm's `amdsmi` package**. When TheRock PyTorch is installed alongside standard `amdsmi`, importing torch triggers a "double free" segmentation fault. This is caused by incorrect symbol resolution (requires patching `rocm_sdk/__init__.py` to set `rtld_global: False`).

### Recommended Version Strategy  

**Option A: Use AMD's Official Pre-built vLLM Docker Image (RECOMMENDED)**
- Image: `rocm/vllm-dev:rocm7.1.1_navi_ubuntu24.04_py3.12_pytorch_2.8_vllm_0.10.2rc1`
- Benefits: Pre-tested, validated configuration
- ROCm: 7.1.1 (stable release with gfx1151 support)
- PyTorch: 2.8
- vLLM: 0.10.2rc1
- Status: **Best path forward for production use**

**Option B: Build from Source with Stable Versions**
- **ROCm**: Use **ROCm 6.3 or 6.4** stable releases (NOT nightlies)
  - ROCm 6.3 has validated PyTorch support
  - ROCm 6.4.1 added gfx1151 support
  - Avoid bleeding-edge 7.x nightlies until stability improves
  
- **PyTorch**: Use **PyTorch 2.5.0 to 2.8.0** (stable or nightly)
  - Confirmed working: `PyTorch 2.5.0a0` with ROCm 6.3.4 on Fedora
  - Confirmed working: `PyTorch 2.8.0` with ROCm 7.1.1
  - Avoid very recent nightlies (post-Oct 2024) due to amdsmi conflicts
  
- **vLLM**: Use **vLLM 0.10.x** release branch
  - Latest: 0.10.2 or 0.10.3
  - Avoid bleeding-edge `main` until 0.11.x stabilizes
  
- **Flash Attention**: Use ROCm flash-attention `main_perf` branch
  - Commit from late 2024 (stable, pre-dates recent breaking changes)

### Current Configuration Issues

Our current pinned versions are **too bleeding-edge**:
- ❌ ROCm 7.10.0a20251015 (nightly, unstable)
- ❌ PyTorch 2.10.0a0+rocm7.10.0a20251015 (nightly, amdsmi conflict)
- ❌ vLLM main branch at recent commit (may have instability)

### Revised Pinning Strategy

To ensure reproducibility, all components must be pinned to specific versions/commits/digests.

### 1. ROCm
-   **Source**: AMD Official Releases (NOT TheRock nightlies)
-   **Strategy**: Use ROCm **6.3.4** or **6.4.1** stable
-   **Target**: ROCm 6.3.4 (proven stable with PyTorch 2.5+)

### 2. PyTorch
-   **Source**: PyTorch official ROCm wheels
-   **Strategy**: Pin to PyTorch **2.5.0 or 2.8.0** with ROCm 6.3/6.4
-   **Example**: `torch==2.5.0+rocm6.3` or use AMD Docker base

### 3. vLLM
-   **Source**: `https://github.com/vllm-project/vllm.git`
-   **Strategy**: Pin to vLLM **v0.10.2** or **v0.10.3** tag/release
-   **Alignment**: Check for Red Hat patches, use release tags for stability

### 4. Flash Attention
-   **Source**: `https://github.com/ROCm/flash-attention.git`
-   **Strategy**: Pin to a stable commit from `main_perf` branch (late 2024)

## Red Hat Alignment
-   **Container Engine**: Use `podman` by default.
-   **Base Image**: Fedora.
-   **Packaging**: While not building RPMs yet, the Dockerfile structure should mirror Red Hat's AI containers (e.g., installing dependencies via `dnf`, keeping the environment clean).

### Track C: The Nightly Spoof (Instant)
- **Status**: **VERIFIED WORKING (2025-12-06)**
- **Goal**: Immediate verification.
- **Method**: Run the existing `rocm/vllm-dev:nightly` image with aggressive hardware spoofing.
- **Key Config**: `HSA_OVERRIDE_GFX_VERSION=11.0.0` (Spoof `gfx1100`/Navi31).
- **Pros**: Zero build time.
- **Cons**: High risk of illegal instruction crashes; relies on binary compatibility between RDNA3 and RDNA3.5.
- **Artifacts**: `run_nightly_spoof.sh`, `QUICKSTART_SPOOF.md`.

### Track D: The Locked Spoof (Reproducible)
- **Status**: **DEFINED**
- **Goal**: Production-ready reproducibility.
- **Method**: Custom Docker image extending a pinned `rocm/vllm-dev` digest with baked-in spoofing variables.
- **Base Digest**: `sha256:a92fa9cb915027468e85e147f4dd1c87f026d7974610280546a2a1f94a146889`
- **Artifacts**: `Dockerfile.spoof_locked`, `build_spoof_locked.sh`.

### Track E: The Vulkan Speedster (llama.cpp)
- **Status**: **DEFINED**
- **Goal**: Maximum prompt processing throughput (~884 tok/s).
- **Method**: Build `llama.cpp` from source with `GGML_VULKAN=ON`.
- **Pros**: 2.5x faster prompt processing than HIP; no ROCm kernel dependency issues.
- **Cons**: Slower token generation than HIP; different API than vLLM.
- **Artifacts**: `Dockerfile.vulkan`, `build_vulkan.sh`.

### Track F: The Simple Server (Ollama)
- **Status**: **DEFINED**
- **Goal**: Easiest possible deployment.
- **Method**: Official Ollama container with memory overrides.
- **Key Config**: `OLLAMA_GPU_MEMORY=96GB`.
- **Pros**: Official support in v0.6.2; extremely simple.
- **Cons**: Manual memory config required; less control.
- **Artifacts**: `run_ollama.sh`.

## Automation Requirements
-   **Lockfiles**: Python dependencies must be frozen in a `requirements.lock` or `uv.lock` file.
-   **Build Script**: `build_pipeline.sh` must accept specific versions/hashes as arguments but *default* to a known-good pinned configuration.
-   **Metadata**: The resulting image should contain labels with the git hashes and versions used.

## Deliverables
1.  **Spec File**: This document.
2.  **Pinned Configuration**: A file (e.g., `versions.env`) defining the known-good set.
3.  **Automated Build Scripts**: `build_pipeline.sh` using the pinned config.
4.  **Tutorial**: `TUTORIAL.md` with sections on how to update the pins.

### 4. Lessons Learned & Best Practices
- **Architecture Allow-listing**: New hardware (like Strix Point `gfx1151`) often requires explicit addition to CMake allowlists in upstream projects (vLLM, PyTorch) before official support lands. "Unsupported architecture" errors are often just configuration checks.
- **Patch Robustness**: When patching upstream code in Dockerfiles, use robust regex anchors or inspect the file content first. Hardcoded context lines can break easily between versions.
- **Stable vs. Bleeding Edge**: While nightlies offer latest hardware support, they introduce instability (e.g., TheRock/amdsmi conflict). Backporting specific hardware support (like the `gfx1151` patch) to stable versions is often safer than using unstable nightlies.
- **Dual Build Strategy**: Maintaining both Fedora (RH-aligned) and Ubuntu (Vendor-aligned) build options provides a fallback when distro-specific package conflicts arise.

### 5. Known Issues & Watchlist

The following issues and resources are critical for tracking the stability of vLLM on gfx1151.

### Critical Issues to Watch
-   **ROCm 7.0.2 Compatibility**: [Native Linux Compatibility Guide](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html#rocm-7-0-2) - Watch for official gfx1151 support updates.
-   **ROCm Issue #5339**: [GitHub Issue #5339](https://github.com/ROCm/ROCm/issues/5339) - Tracks specific ROCm bugs that may affect model execution.
-   **"Invalid Device Function"**: Users often report this on gfx1151 with ROCm 6.4.1+. Requires `VLLM_TARGET_DEVICE="rocm"` and correct `PYTORCH_ROCM_ARCH`.
-   **Memory Fragmentation**: `amdgpu` TTM memory manager may limit large allocations. Workaround: Adjust `pages_limit`.

### Community Resources
-   [Framework Community: Compiling vLLM on Strix Halo](https://community.frame.work/t/compiling-vllm-from-source-on-strix-halo/77241)
-   [LLM Tracker: Strix Halo Compatibility](https://llm-tracker.info/strix-halo)
