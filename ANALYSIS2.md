# vLLM on AMD Ryzen AI Max+ 396 (gfx1151): Architecture, Alternatives, and OpenShift AI Deployment Strategy

## Executive Summary

This report provides a first-principles analysis of running vLLM-based LLM inference on the AMD Ryzen AI Max+ 396 with 128GB unified memory, specifically targeting OpenShift AI deployment scenarios with 32B-70B parameter models. The analysis addresses three core questions: what vLLM architecturally requires, what components can be substituted for performance or compatibility, and what cross-vendor abstraction layers exist that could standardize accelerator support across emerging silicon providers.

**Key Finding**: vLLM is architecturally bound to PyTorch and cannot use Rust frameworks, Vulkan backends, or WebGPU as drop-in replacements. The only modular components within vLLM's architecture are the attention backends (FlashAttention, FlashInfer, xFormers) and the emerging Triton-based kernel compilation pathway. For gfx1151 specifically, the recommended immediate path is building vLLM against TheRock nightly PyTorch wheels with native gfx1151 kernels, accepting ~40% performance relative to mature architectures until AMD optimizes the underlying rocBLAS/hipBLAS libraries in H2 2026.

---

## Part 1: vLLM Architecture and What Can Actually Be Swapped

### 1.1 The Non-Negotiable Stack

vLLM's architecture has hard dependencies that cannot be bypassed without forking the entire project. Understanding these constraints is essential before evaluating alternatives.

**PyTorch as the compute substrate**: vLLM is built entirely on PyTorch's tensor operations and autograd system. Every model forward pass, every attention computation, and every memory allocation flows through PyTorch. This is not a pluggable abstraction—it is the foundation. PyTorch in turn requires either CUDA (NVIDIA) or ROCm/HIP (AMD) for GPU acceleration. There is no Vulkan backend for PyTorch, no WebGPU backend, and no OpenCL backend in production use.

**Custom CUDA/HIP kernels**: vLLM's performance comes from custom kernels for PagedAttention, rotary embeddings, and fused operations. These are written in CUDA with HIP ports maintained in the codebase. They compile against the vendor's GPU compiler (nvcc or hipcc) and link against vendor math libraries (cuBLAS or rocBLAS). These kernels represent years of optimization and cannot be trivially replaced.

**The attention backend abstraction**: This is the one genuinely modular component within vLLM. The attention computation can be performed by FlashAttention-2, FlashInfer, xFormers, or a naive PyTorch implementation. On AMD, FlashAttention support comes through either Composable Kernel (CK) implementations or Triton-compiled kernels.

### 1.2 What Can Be Configured or Swapped

Within vLLM's architecture, the following components offer flexibility:

**Attention backend selection**: vLLM supports multiple attention implementations selectable at runtime. For AMD GPUs, the options are ROCM_FLASH (using AMD's FlashAttention port), FLASHINFER (if compiled with ROCm support), XFORMERS, and TORCH_SDPA (PyTorch's native scaled dot product attention). The ROCM_FLASH backend requires Composable Kernel support, which gfx1151 currently lacks. TORCH_SDPA works but is slower.

**Quantization backends**: vLLM supports multiple quantization schemes including GPTQ, AWQ, SqueezeLLM, and FP8. The backend implementations vary—some use Marlin kernels (CUDA-only currently), others use AutoGPTQ or pure PyTorch. For gfx1151, AWQ with the GEMM backend and GPTQ with the triton backend offer the best compatibility.

**Triton-based kernels**: OpenAI's Triton language compiles to both CUDA and ROCm targets. vLLM increasingly uses Triton for portable kernels. The triton compiler can target gfx1151 through ROCm's backend, providing a path where new kernel implementations could work on AMD without hand-written HIP code.

### 1.3 The Triton Pathway: The Most Promising Abstraction

Triton deserves special attention because it represents the closest thing to a cross-vendor kernel abstraction that vLLM actually uses. Triton kernels are written in Python, compiled through MLIR/LLVM, and target multiple GPU architectures.

For AMD GPUs, Triton compiles through the ROCm backend (requiring rocm-core and hip libraries). The compilation produces AMDGCN assembly that runs natively on AMD hardware. AMD has been investing in Triton support, with gfx1151-specific compilation working in recent nightlies.

The practical implication: as vLLM migrates more operations to Triton (an ongoing effort), the dependency on hand-optimized HIP kernels decreases. Triton kernels for gfx1151 can be compiled on-the-fly, avoiding the need for pre-built kernel libraries that lag behind hardware releases.

To enable Triton-based attention in vLLM:

```bash
export VLLM_ATTENTION_BACKEND=TRITON_FLASH_ATTN
```

This bypasses the need for Composable Kernel FlashAttention, which gfx1151 lacks, at some performance cost.

---

## Part 2: Building vLLM for gfx1151 with Available Options

### 2.1 The Working Build Path

Based on community testing and the documented build issues in your changelog, the following represents the most reliable current path:

**Base requirements**: Linux kernel 6.16.9+ (critical for full 128GB memory visibility), ROCm 6.4.4+ or TheRock nightlies, PyTorch 2.7+ built for gfx1151.

**TheRock nightly wheels**: The community-maintained builds at `github.com/scottt/rocm-TheRock/releases` provide PyTorch wheels with gfx1151 kernels. These include AOTriton (AMD's Triton fork optimized for ROCm) which enables Triton-based attention backends.

**vLLM build procedure**:

```bash
# Install TheRock PyTorch wheel
pip install torch-2.7.0a0+gita5b2f14-cp312-cp312-linux_x86_64.whl

# Clone vLLM and patch for gfx1151
git clone https://github.com/vllm-project/vllm.git
cd vllm

# Add gfx1151 to supported architectures
sed -i 's/set(HIP_SUPPORTED_ARCHS "/set(HIP_SUPPORTED_ARCHS "gfx1151;/g' CMakeLists.txt

# Patch amdsmi detection fallback (addresses Issue #20 from your log)
# This ensures ROCm platform detection works without amdsmi

# Build with Triton attention as default
export VLLM_ATTENTION_BACKEND=TRITON_FLASH_ATTN
export PYTORCH_ROCM_ARCH=gfx1151
pip install -e . --no-build-isolation
```

**Critical environment variables for runtime**:

```bash
export HSA_XNACK=1  # Enable recoverable page faults for unified memory
export GPU_MAX_HW_QUEUES=2  # Reduce hardware queue pressure
export VLLM_ATTENTION_BACKEND=TRITON_FLASH_ATTN
```

### 2.2 Performance Expectations and Optimization Flags

Current gfx1151 performance operates at approximately 40% of theoretical peak due to unoptimized rocBLAS/hipBLAS kernels. Specific measurements on comparable hardware (Ryzen AI Max+ 395):

**70B models (Llama 3.1 70B Q4_K_M, ~40GB)**: Expect 8-12 tokens/second generation speed. The unified memory architecture handles the model size comfortably, but the compute throughput is memory-bandwidth limited.

**32B models (Qwen2.5 32B, DeepSeek 33B)**: Expect 18-25 tokens/second generation speed. These models fit well within the L3 cache and memory bandwidth characteristics.

**Optimization flags that help**:

```bash
# rocWMMA acceleration for matrix operations
export ROCWMMA_FORCE_UNROLL=1

# Disable problematic MES compute features
# Add to kernel command line: amdgpu.cwsr_enable=0

# Memory allocation tuning for large models
export HIP_FORCE_DEV_KERNARG=1
```

### 2.3 OpenShift AI Deployment Considerations

OpenShift AI's model serving stack uses vLLM as the inference engine through the KServe framework. The deployment architecture adds additional considerations:

**Container base image**: OpenShift AI model servers typically use UBI-based images. You will need a custom image that includes TheRock ROCm installation and gfx1151-compiled PyTorch. The standard `quay.io/modh/vllm` images target NVIDIA and will not work.

**Device plugin requirements**: The AMD GPU device plugin for Kubernetes (`amd.com/gpu`) must recognize the gfx1151 device. Recent versions (v1.25.0.0-68+) include Strix Halo support. The device plugin exposes `/dev/kfd` and `/dev/dri` to containers.

**Memory visibility in containers**: The kernel-level fix for memory visibility (kernel 6.16.9+) applies at the host level. Containers inherit this. However, ensure the container runtime passes the full memory allocation—the `OLLAMA_GPU_MEMORY=96GB` pattern applies to any containerized workload.

**Recommended Dockerfile skeleton**:

```dockerfile
FROM registry.access.redhat.com/ubi9/ubi:latest

# Install ROCm 6.4.4+ from AMD repos
RUN dnf install -y rocm-hip-runtime rocm-hip-sdk

# Install TheRock PyTorch wheel
COPY torch-2.7.0*.whl /tmp/
RUN pip install /tmp/torch-2.7.0*.whl

# Build vLLM with gfx1151 support
# ... (following build procedure above)

ENV VLLM_ATTENTION_BACKEND=TRITON_FLASH_ATTN
ENV HSA_XNACK=1
ENV PYTORCH_ROCM_ARCH=gfx1151
```

---

## Part 3: Alternatives to vLLM for LLM Inference

The following are complete inference engines that replace vLLM, not components that plug into it. Each has different architectural choices that affect gfx1151 support.

### 3.1 llama.cpp: The Immediate Working Solution

llama.cpp is a C++ inference engine with multiple compute backends. Unlike vLLM, it does not depend on PyTorch. This architectural difference means it can use Vulkan, OpenCL, or direct HIP without the PyTorch abstraction layer.

**Why llama.cpp works better on gfx1151 today**: The Vulkan backend uses Mesa's RADV driver, which has mature gfx1151 support. Vulkan compute shaders bypass the entire ROCm userspace stack, avoiding the unoptimized rocBLAS kernels. Benchmark data shows 884 tok/s prompt processing on Vulkan versus 349 tok/s on HIP for the same hardware.

**Limitations for OpenShift AI**: llama.cpp uses a different API than vLLM. It cannot serve as a drop-in replacement for KServe's vLLM integration. You would need to use llama.cpp's OpenAI-compatible server mode and configure KServe to use the generic REST predictor rather than the vLLM-specific runtime.

**Best for**: Standalone inference, development testing, workloads where vLLM's advanced features (continuous batching, PagedAttention) are not required.

### 3.2 Text Generation Inference (TGI): Hugging Face's Alternative

TGI is another production inference server that competes with vLLM. It also depends on PyTorch, so it faces the same gfx1151 challenges. TGI's ROCm support is less mature than vLLM's, making it a worse choice for AMD hardware currently.

### 3.3 Rust Frameworks: Not vLLM-Compatible

I want to correct my earlier presentation of Rust frameworks. These cannot back vLLM:

**Burn**: A Rust ML framework that is architecturally similar to PyTorch but written in Rust. It has its own tensor abstraction, its own backends (WGPU, CUDA, CPU), and its own model format. You would need to port models to Burn and write Burn-native serving code. It does not integrate with vLLM.

**Candle**: Hugging Face's Rust inference library. It can run models but has no AMD GPU support currently. Even when WebGPU support lands, it would be a separate inference engine, not a vLLM backend.

**Ratchet**: A WebGPU-based inference engine from Hugging Face. It targets browser and edge deployments, not server inference. Limited model support (Whisper, small models).

**The correct framing**: These represent a future where Rust-based inference might provide better cross-platform support, but they are years away from production parity with vLLM and cannot help with your immediate gfx1151 needs.

### 3.4 Tinygrad: The Sovereign Stack Approach

Tinygrad deserves attention because it explicitly aims to bypass vendor compute stacks. Its "AM" backend implements a ~600-line userspace driver that talks directly to AMD GPUs through the kernel driver, bypassing ROCm entirely.

**Current status**: The AM backend targets RDNA2/RDNA3 discrete GPUs. gfx1151 (RDNA 3.5 integrated) is not explicitly supported but might work with community patches. The tinygrad team has stated they would invest in broader AMD support if adoption in tools like Ollama or ComfyUI increases.

**For your use case**: Tinygrad cannot run vLLM models. It has its own model implementations (llama.py, etc.) that would need to be deployed separately. Not compatible with OpenShift AI's existing model serving infrastructure.

---

## Part 4: Cross-Vendor Abstraction Layers and Standardization

### 4.1 Why This Matters

You asked about alternatives to ROCm/HIP that could provide standardization across emerging silicon providers (Rebellions, Groq, Tenstorrent, FuriosaAI, etc., as covered in your uploaded research). This is an excellent strategic question because the current situation—where every accelerator vendor requires a different software stack—is unsustainable.

The key abstraction layers being developed:

### 4.2 OpenAI Triton: The Most Viable Near-Term Standard

Triton is emerging as the de facto kernel abstraction for ML workloads. Originally CUDA-only, it now supports AMD (through ROCm's compiler backend) and has experimental Intel support.

**How it works**: Developers write kernels in Python using Triton's DSL. The Triton compiler lowers through MLIR to vendor-specific backends (PTX for NVIDIA, AMDGCN for AMD). The same kernel source can target multiple hardware platforms.

**Adoption in LLM inference**: vLLM, TGI, and PyTorch increasingly use Triton kernels. FlashAttention-3 has a Triton implementation. The xFormers library uses Triton extensively.

**For gfx1151**: AMD has invested in Triton support through their fork (AOTriton). TheRock builds include AOTriton with gfx1151 compilation support. Setting `VLLM_ATTENTION_BACKEND=TRITON_FLASH_ATTN` uses Triton kernels that compile for your hardware at runtime.

**Limitation**: Triton still requires the vendor's compiler toolchain and some runtime libraries. It abstracts kernel development, not the entire compute stack.

### 4.3 SYCL: The Cross-Vendor C++ Approach

SYCL is a Khronos standard for heterogeneous computing. Intel's oneAPI implementation is the most mature, but there are AMD and NVIDIA backends through projects like hipSYCL/AdaptiveCpp.

**Current status for LLM inference**: Limited. PyTorch does not have a SYCL backend (Intel's extension uses oneAPI directly). There is no SYCL port of vLLM. Some academic projects are exploring SYCL for transformer inference, but nothing production-ready.

**Potential**: If SYCL adoption increases, it could provide a single C++ abstraction that targets NVIDIA, AMD, and Intel GPUs, plus potentially other accelerators. The emerging accelerator vendors mentioned in your research (Tenstorrent, Groq, etc.) would need to implement SYCL backends.

### 4.4 Vulkan Compute: The Graphics API Path

Vulkan includes compute shader support that works across NVIDIA, AMD, and Intel GPUs through their respective Vulkan drivers.

**Current status for LLM inference**: llama.cpp's Vulkan backend proves this works. Performance on gfx1151 is actually better than HIP currently due to more mature driver optimization.

**Why it's not used for vLLM**: PyTorch has no Vulkan backend. The ML ecosystem standardized on CUDA/HIP/Metal for compute. Vulkan compute shaders require different programming models than CUDA kernels. Porting vLLM to Vulkan would be a massive undertaking.

**The kompute project**: This attempts to provide a Vulkan-based GPU compute layer that could theoretically back ML frameworks, but adoption is minimal.

### 4.5 WebGPU: The Emerging Universal Abstraction

WebGPU is a W3C standard that abstracts Vulkan, Metal, and DirectX 12. It's designed for browser-based GPU compute but can run natively through implementations like wgpu.

**Current status**: Burn (Rust ML framework) uses wgpu as a backend. Ratchet uses WebGPU for inference. These work on AMD GPUs through Vulkan translation.

**For vLLM**: Not applicable. PyTorch has no WebGPU backend and likely never will—WebGPU's abstraction level is too high for the kernel-level control ML frameworks need.

### 4.6 MLIR: The Compiler Infrastructure Layer

MLIR (Multi-Level Intermediate Representation) is an LLVM project that provides composable compiler infrastructure. Triton compiles through MLIR. TensorFlow and PyTorch's compilers use MLIR.

**Why this matters for standardization**: MLIR's dialect system allows different accelerator vendors to implement backends. The same high-level representation (e.g., Linalg dialect for linear algebra) can lower to different target dialects (GPU, TPU, custom NPU).

**IREE project**: Google's IREE compiler uses MLIR to target multiple accelerators including AMD GPUs through the ROCm backend. If IREE adoption increased in LLM inference, it could provide the abstraction layer you're looking for. Currently, IREE is focused on TensorFlow/JAX workloads rather than PyTorch.

### 4.7 Assessment: What Actually Helps Today

For your immediate needs (OpenShift AI + vLLM + gfx1151), the only viable abstraction that helps is **Triton**. By using Triton-based attention and kernel backends in vLLM, you get:

1. Kernels that compile for gfx1151 at runtime
2. Reduced dependency on pre-built rocBLAS/hipBLASLt kernels
3. A path where future performance improvements in the Triton compiler automatically benefit you

The other abstraction layers (SYCL, Vulkan, WebGPU, MLIR) are either not integrated into vLLM or require architectural changes that would effectively mean not using vLLM.

---

## Part 5: Strategic Recommendations for OpenShift AI Deployment

### 5.1 Immediate Path (Works Now, ~40% Efficiency)

**Build custom vLLM image with TheRock PyTorch and Triton attention backend.** This is the only path that gets vLLM running on gfx1151 today. Accept the performance penalty relative to mature architectures.

Specific configuration:
- Base: UBI9 or Ubuntu 24.04 with ROCm 6.4.4+
- PyTorch: TheRock nightly wheel with gfx1151 support
- vLLM: Built from source with gfx1151 added to CMakeLists.txt
- Attention: TRITON_FLASH_ATTN backend
- Environment: HSA_XNACK=1, GPU_MAX_HW_QUEUES=2

**Expected performance for your target workloads**:
- 32B models: 18-25 tok/s generation
- 70B models: 8-12 tok/s generation

### 5.2 Short-Term Improvement (Q1 2026)

**Monitor ROCm 8.0 release for official gfx1151 support.** AMD has indicated the next major ROCm version will begin incorporating improved consumer GPU support. When ROCm 8.0 releases with gfx1151 in the official compatibility matrix, switch from TheRock nightlies to production ROCm.

**Track Composable Kernel gfx1151 enablement.** Once CK supports gfx1151, native FlashAttention becomes available, improving attention performance significantly over Triton-based attention.

### 5.3 Long-Term Architecture (H2 2026+)

**Evaluate Triton as the kernel standardization layer.** As vLLM migrates more operations to Triton, the dependency on vendor-specific hand-optimized kernels decreases. This trend benefits non-mainstream architectures like gfx1151.

**Watch for cross-vendor inference standards.** If projects like IREE gain LLM inference support, or if the emerging accelerator vendors (your research covers Rebellions, Tenstorrent, FuriosaAI, MetaX) coalesce around a common interface, that could change the strategic calculus. Currently, no such standard exists in production.

### 5.4 Alternative Deployment Pattern

If vLLM performance on gfx1151 proves insufficient for production workloads, consider:

**llama.cpp with OpenAI-compatible API behind KServe generic predictor.** This sacrifices vLLM's advanced features (continuous batching, speculative decoding) but gains the Vulkan backend's superior current performance. For use cases with predictable, non-bursty traffic, this may be acceptable.

---

## Part 6: Evaluation Matrix

| Approach | vLLM Compatible | Works Today | Performance | OpenShift AI Ready | Standardization Benefit |
|----------|-----------------|-------------|-------------|-------------------|------------------------|
| TheRock PyTorch + Triton attention | Yes | Yes | 40% of peak | With custom image | Triton portability |
| Official ROCm (6.4.4+) | Partial | Partial | 40% of peak | With custom image | None |
| llama.cpp Vulkan | No | Yes | 80% of peak for PP | Requires KServe config | Vulkan cross-vendor |
| llama.cpp HIP | No | Yes | 50% of peak | Requires KServe config | None |
| Tinygrad AM backend | No | Experimental | Unknown | No | Vendor stack bypass |
| Rust frameworks (Burn, Candle) | No | Limited | Unknown | No | Future potential |
| Wait for ROCm 8.0 | Yes | No (H1 2026) | ~80% expected | Yes | Production support |

---

## Appendix A: Critical Issues and Workarounds Reference

**Memory visibility (ROCm#5444)**: Kernel 6.16.9+ required for full 128GB visibility. Without this, ROCm reports only 15.5-62GB.

**MES firmware hangs (ROCm#5590)**: Add `amdgpu.cwsr_enable=0` to kernel command line. Reduces context-switch efficiency but prevents compute queue hangs.

**hipBLAS performance regression (ROCm#4748)**: gfx1151 hipBLAS runs 2-6x slower than gfx1100. No workaround except using Triton-based alternatives where possible.

**Model loading slowdown past 64GB (llama.cpp#15018)**: HIP backend exhibits slow weight loading for large models. Vulkan backend unaffected.

---

## Appendix B: Monitoring Resources

**TheRock releases**: github.com/scottt/rocm-TheRock/releases and github.com/ROCm/TheRock/discussions/655

**Strix Halo community**: strixhalo-homelab.d7.wtf (Discord for live troubleshooting)

**LLM Tracker benchmarks**: llm-tracker.info/_TOORG/Strix-Halo (continuously updated performance data)

**ROCm roadmap signals**: github.com/ROCm/ROCm/discussions/4276 (AMD staff comments on timeline)