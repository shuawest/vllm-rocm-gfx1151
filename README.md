# vLLM on AMD Strix Point (gfx1151)

![License](https://img.shields.io/badge/license-Apache%202.0-blue)
![Status](https://img.shields.io/badge/status-verified-success)
![Hardware](https://img.shields.io/badge/hardware-gfx1151-red)

This repository provides working configurations for running LLM inference on AMD **Strix Point** and **Strix Halo** APUs (RDNA 3.5, `gfx1151`).

> [!IMPORTANT]
> **Current Status (Dec 2025)**: The "Spoofing" strategy (Track D) is currently **BLOCKED** by GPU firmware security on Strix Halo. The recommended solution is **Track E (Vulkan)**, which bypasses these restrictions and offers high performance.

---

## 🚀 Quickstart: The Vulkan Speedster (Recommended)

For Strix Halo, the **Vulkan backend** is the only fully verified, high-performance path today. It bypasses the ROCm compute stack entirely.

### 1. Build the Image
```bash
./build_vulkan.sh
```

### 2. Run Inference (CLI)
```bash
./test_vulkan_inference.sh
```

### 3. Run Server (OpenAI Compatible)
```bash
./run_vulkan_server.sh
```

**Performance**: ~237 tok/s (TinyLlama 1.1B) on Strix Halo.

---

## 🏗️ Build Strategies Status

| Track | Name | Strategy | Status | Description |
| :--- | :--- | :--- | :--- | :--- |
| **E** | **Vulkan Speedster** | llama.cpp (Vulkan) | ✅ **Working** | **Primary Solution**. Bypasses firmware blocks. Fast. |
| **F** | **Simple Server** | Ollama | ⚠️ Issues | Works for some, but hits ROCm faults on Strix Halo. |
| **D** | **Locked Spoof** | Custom Docker Image | 🛑 **Blocked** | Blocked by `GCVM_L2_PROTECTION_FAULT` (Firmware Rejection). |
| **C** | **Nightly Spoof** | Runtime Flags | 🛑 **Blocked** | Same firmware rejection issue. |

---

## 🛠️ Troubleshooting

### "No devices found"
- Ensure you are using the **Ubuntu 24.04** based image (Track E).
- Older drivers (Ubuntu 22.04) do not recognize the `gfx1151` ID.

### `GCVM_L2_PROTECTION_FAULT`
- This appears in `dmesg` when using ROCm-based solutions (Track C/D).
- It indicates the GPU firmware is rejecting the compute kernels.
- **Fix**: Switch to Track E (Vulkan).

---

## 📂 Repository Structure

-   `Dockerfile.vulkan`: **The Golden Image**. Ubuntu 24.04 + Vulkan SDK.
-   `test_vulkan_inference.sh`: Verifies GPU access and speed.
-   `apply_kernel_fixes.sh`: Helper for host kernel arguments (optional for Vulkan).
-   `BUILD_ISSUES.md`: Detailed log of all debugging attempts.
-   `ANALYSIS2.md`: Deep dive into Strix Halo inference architecture.

---

## 🌐 Community Resources

-   **Strix Halo HomeLab**: `strixhalo-homelab.d7.wtf`
-   **LLM Tracker**: [llm-tracker.info](https://llm-tracker.info/_TOORG/Strix-Halo)

---

**License**: Apache 2.0
