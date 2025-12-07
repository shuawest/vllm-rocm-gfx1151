# LLM Inference on AMD Ryzen AI Max+ 396 (gfx1151): A Technical Deep Dive

**The gfx1151 architecture is functional but operates at 40% efficiency—Vulkan backends currently outperform HIP by 2.4x, while native rocBLAS kernels run 2-6x slower than gfx1100 equivalents.** AMD's ROCm officially supports Strix Halo via TheRock nightlies and ROCm 6.4+, but the architecture is conspicuously absent from the production compatibility matrix (ROCm 7.1.1). For immediate results, the Vulkan backend in llama.cpp delivers **884 tok/s prompt processing** versus HIP's 349 tok/s—making it the recommended path while AMD optimizes native kernels. Full performance parity likely arrives H2 2026 with ROCm 8.x.

---

## The gfx1151 support paradox: available but not official

AMD announced ROCm support for Strix Halo at Computex 2025, yet the official compatibility matrix lists only gfx950, gfx1201, gfx1200, gfx1101, gfx1100, gfx1030, gfx942, gfx90a, and gfx908—**gfx1151 is missing**. This creates a confusing landscape documented in GitHub issue #5339, where users report contradictory information across AMD documentation.

The actual support pathway exists through several channels. ROCm 6.4.1 (May 2025) added working rocBLAS support for Strix Halo, confirmed by Phoronix benchmarks. ROCm 6.4.4 (September 2025) delivered PyTorch Windows/Linux preview specifically for Ryzen AI MAX APUs. The official nightly pip index at `https://rocm.nightlies.amd.com/v2/gfx1151/` provides ROCm 7.9.0 technology preview builds with gfx1151 kernels.

Community builds fill critical gaps. Scott Tsai (@scottt) and @jammm maintain working PyTorch wheels at `github.com/scottt/rocm-TheRock/releases` featuring PyTorch 2.7.0a0 with ROCm 6.5.0rc and AOTriton 0.9.2 for scaled_dot_product_attention. Docker images from `github.com/weiziqian/rocm_pytorch_docker_gfx1151` bundle Ubuntu 24.04 with ROCm 7.0.0rc and PyTorch 2.7.1.

### Why vLLM fails repeatedly

The 37+ documented failures stem from interconnected issues. **Architecture mismatch errors** occur because official PyTorch Docker images and pip wheels exclude gfx1151 from their LLVM targets. **PyTorch wheel incompatibilities** arise from builds targeting gfx1100/gfx1101 rather than gfx1151. **Runtime hangs** correlate with MES firmware bugs requiring `amdgpu.cwsr_enable=0` as a workaround. The **ROCm 6.2/6.3/7.1 failures** reflect that production ROCm releases don't include gfx1151 kernels—only TheRock nightlies do.

---

## What actually works today: a performance hierarchy

Extensive community testing reveals a clear performance hierarchy for gfx1151. Benchmarks using Llama-2-7B Q4_0 demonstrate dramatic backend differences:

| Backend | Prompt Processing (512 tokens) | Token Generation (128 tokens) |
|---------|-------------------------------|------------------------------|
| **Vulkan + Flash Attention** | **884 tok/s** | **53 tok/s** |
| HIP + rocWMMA + FA | 344 tok/s | 51 tok/s |
| HIP (basic) | 349 tok/s | 49 tok/s |
| CPU-only | 295 tok/s | 29 tok/s |

The Vulkan backend delivers **2.5x faster prompt processing** than HIP on gfx1151, an anomaly explained by unoptimized native HIP kernels. At longer contexts (8K+ tokens), HIP with rocWMMA and Flash Attention maintains near-full token generation speed (51 tok/s) while Vulkan degrades to 32 tok/s, making HIP preferable for extended conversations.

### llama.cpp: the most reliable path

The lemonade-sdk provides nightly ROCm builds at `github.com/lemonade-sdk/llamacpp-rocm` with ROCm 7 bundled—no separate installation required. For building from source with optimal performance:

```bash
# Vulkan backend (fastest for prompt processing)
cmake -B build -DGGML_VULKAN=ON
cmake --build build --config Release

# HIP with rocWMMA Flash Attention (best for long context)
cmake -B build \
  -DGGML_HIP=ON \
  -DGGML_HIP_ROCWMMA_FATTN=ON \
  -DAMDGPU_TARGETS="gfx1151"
cmake --build build --config Release
```

Critical runtime flags that prevent hangs: `llama-server -m model.gguf -fa 1 --no-mmap -ngl 999`. The `-fa 1` enables Flash Attention while `--no-mmap` prevents memory-mapped loading issues specific to Strix Halo's unified memory architecture.

### Ollama offers the simplest deployment

Ollama gained official gfx1151 support in v0.6.2. The critical configuration addresses VRAM detection bugs where Ollama reports only 512MB instead of available unified memory:

```bash
OLLAMA_GPU_MEMORY=96GB ollama run llama3.3:70b
```

GitHub issue #12062 tracks this detection problem. Users running kernel 6.16.9+ report automatic resolution of the 15.5GB visibility limitation (ROCm issue #5444), but manual memory specification remains necessary for Ollama itself.

---

## The kernel and driver foundation

**Linux kernel 6.16.9+ is essential** for proper unified memory visibility on Strix Halo. Earlier kernels exhibit a critical bug where ROCm detects only 15.5-62GB instead of the full 96-128GB allocation. This single kernel upgrade resolves the most common memory visibility complaints without requiring manual GTT configuration.

For kernels before 6.16.9, manual configuration in `/etc/modprobe.d/amdgpu_llm.conf`:

```bash
options amdgpu gttsize=120000
options ttm pages_limit=31457280
```

MES firmware version 0x80 (latest as of November 2025) still exhibits hangs under heavy compute loads. The workaround `amdgpu.cwsr_enable=0` in kernel parameters disables compute wave store/resume, preventing most MES-related crashes at the cost of some context-switching efficiency.

### Mesa and Rusticl provide OpenCL alternatives

Mesa 24.1+ includes GFX1151 enablement for RadeonSI/RADV, with Mesa 25.x delivering full graphics support. The Rust-based Rusticl OpenCL implementation competes with ROCm 7.0 OpenCL on several workloads:

```bash
export RUSTICL_ENABLE=radeonsi
clinfo  # Shows rusticl platform alongside ROCm
```

Phoronix benchmarks show Rusticl winning some compute workloads while ROCm wins others—providing a viable alternative for OpenCL-based inference tools.

---

## Leveraging 128GB unified memory for large models

The Strix Halo's unified memory architecture enables loading 70B+ parameter models that would be impossible on discrete GPUs with limited VRAM. The key insight: **CPU and GPU share the same physical LPDDR5X pool**, eliminating explicit data transfers between host and device.

Enable HMM-based shared virtual memory by setting `HSA_XNACK=1` in your environment. This allows page fault handling and recoverable memory migration between CPU and GPU contexts. The hipMallocManaged API then provides transparent unified memory access:

```c
hipMallocManaged(&ptr, size);
hipMemPrefetchAsync(ptr, size, deviceId, stream);
```

Measured bandwidth reaches **212 GB/s** (versus 256 GB/s theoretical) within the GPU memory domain, with ~84 GB/s for CPU-GPU transfers. For loading 70B models like Llama 3.1-70B quantized to Q4_K_M (~40GB), the unified memory architecture provides more than adequate bandwidth for inference workloads.

A known issue (llama.cpp #15018) causes slow model weight loading past the ~64GB mark when using the HIP backend—the Vulkan backend loads at full speed regardless of model size.

---

## Rust frameworks and the ROCm bypass strategy

For developers willing to avoid the ROCm stack entirely, several frameworks offer viable paths through Vulkan/WebGPU backends.

**Burn** (github.com/tracel-ai/burn) provides the most mature Rust-native option with WGPU backend support. WGPU targets Vulkan, Metal, DirectX, and WebGPU, working on gfx1151 through the Mesa RADV driver without ROCm userspace dependencies. The framework supports ONNX model import and automatic GPU memory management.

**Ratchet** (github.com/huggingface/ratchet) from Hugging Face delivers WebGPU-powered inference running both natively and in browsers. Currently supporting Whisper and Phi models, LLM capabilities are expanding rapidly.

**Tinygrad** presents the most intriguing alternative. Its "AM" backend implements a ~600-line userspace driver targeting RDNA3/RDNA4, completely bypassing ROCm. While gfx1151 isn't explicitly supported yet, the AMD backend using the kernel driver has been tested on RDNA2 and RDNA3. The tinygrad team notes: "If this gains traction in apps like ComfyUI or Ollama, we will invest into CI for a wide spectrum of AMD cards."

**Candle** (Hugging Face's Rust ML framework) currently lacks AMD support, with GitHub issues #346 and #2938 tracking requests. WebGPU support is on the roadmap, which would enable AMD GPU usage indirectly.

---

## Community resources and working configurations

The **Strix Halo HomeLab** community at `strixhalo-homelab.d7.wtf` provides the most comprehensive resources, including a Discord server for live troubleshooting. Their wiki documents technical details, setup guides, and continuously updated benchmarks.

**kyuz0's Strix Halo Toolboxes** (github.com/kyuz0/amd-strix-halo-toolboxes) offer pre-built Docker images:

```bash
toolbox create llama-rocm-7.1-rocwmma \
  --image docker.io/kyuz0/amd-strix-halo-toolboxes:rocm-7.1-rocwmma \
  -- --device /dev/dri --device /dev/kfd \
  --group-add video --group-add render
```

Available tags include `vulkan-radv`, `rocm-6.4.4-rocwmma`, and `rocm-7.1-rocwmma`.

**lhl's strix-halo-testing repository** (github.com/lhl/strix-halo-testing) provides complete build instructions, performance benchmarks across backends, rocWMMA Flash Attention patches, and vLLM build scripts that address common failures.

### Critical GitHub issues to monitor

| Issue | Problem | Status |
|-------|---------|--------|
| ROCm#4748 | rocBLAS/hipBLAS **2-6x performance regression** vs gfx1100 | Under investigation |
| ROCm#5444 | Only 15.5GB VRAM visible | **Solved** (kernel 6.16.9+) |
| ROCm#5643 | hipBLASLt "unsupported architecture" fallback | Closed |
| ROCm#5665 | AI + video encoding simultaneously causes GPU hang | Open |
| TheRock#655 | Community PyTorch wheels discussion | Active |

---

## The HSA_OVERRIDE_GFX_VERSION workaround

For applications lacking gfx1151 kernels, forcing gfx1100 emulation often doubles performance:

```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
```

This approach leverages the fact that gfx1100 kernels are **2-6x faster** than current native gfx1151 kernels due to optimization maturity. Some applications additionally require symlinking TensileLibrary:

```bash
sudo ln -sf /opt/rocm/lib/rocblas/library/TensileLibrary_lazy_gfx1101.dat \
            /opt/rocm/lib/rocblas/library/TensileLibrary.dat
```

**Caveat**: This workaround leads to MES/kernel errors during extended use and isn't recommended for production workloads. It's useful for testing whether an application would work if proper gfx1151 kernels existed.

---

## Timeline for proper support

AMD stated in GitHub discussion #4276: "The next major version of ROCm will begin to incorporate this change of approach and you will see that in the first half of 2026. Minor versions will enable additional targets as they become release ready at a cadence of every 6 weeks."

Based on historical patterns—RDNA3/gfx1100 took 12-18 months from basic to full PyTorch support—realistic estimates for gfx1151:

- **Now (December 2025)**: Basic functionality via TheRock nightlies; 40% theoretical efficiency
- **Q1 2026**: ROCm 8.0 expected with improved consumer GPU approach
- **Mid-2026**: TheRock technology preview becomes production stream
- **H2 2026**: Realistic target for hipBLASLt and Composable Kernel support

The Composable Kernel (CK) team is working on RDNA3/4 support with "ETA of end of year" according to AMD staff—once CK supports gfx1151, performance should approach theoretical peaks.

---

## Actionable recommendations by priority

**Immediate solutions (work today)**:

1. Use **llama.cpp with Vulkan backend** for fastest prompt processing (884 tok/s)
2. Use **llama.cpp with HIP + rocWMMA + FA** for long context workloads (maintains 51 tok/s at 8K context)
3. Deploy **Ollama** with `OLLAMA_GPU_MEMORY=96GB` for simple model serving
4. Install **kernel 6.16.9+** to resolve memory visibility issues automatically

**Short-term improvements (1-3 months)**:

1. Monitor TheRock releases for performance improvements to gfx1151 kernels
2. Test **tinygrad AMD backend** if they add gfx1151 support
3. Follow ROCm#4748 for hipBLAS performance regression fixes

**Long-term outlook (6-12 months)**:

1. Wait for ROCm 8.x (H1 2026) for official production support
2. hipBLASLt gfx1151 kernels expected mid-2026
3. Consider Modular/Mojo if they expand to consumer AMD GPUs

The unified memory architecture makes Strix Halo exceptionally capable for large model inference—the 128GB pool accommodates models impossible on discrete GPUs. Current software limitations are significant but temporary, with clear upstream momentum toward resolution.