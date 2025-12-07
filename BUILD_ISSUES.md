# Build Issues & Changelog

This document tracks all issues encountered during the vLLM build process for AMD ROCm gfx1151 (Strix Halo) and their resolutions.

## Issue Log

### Issue #1: SSH sudo Password Prompt
**Date**: 2025-12-02  
**Error**: `sudo: a terminal is required to read the password`  
**Root Cause**: SSH doesn't allocate a pseudo-terminal by default for non-interactive commands.  
**Fix**: Add `-t` flag to SSH command:
```bash
ssh -t aimax "cd ~/aimax_build && ./run_setup.sh"
```
**Files Modified**: `TUTORIAL.md`

---

### Issue #2: awk Escaping in Dockerfile
**Date**: 2025-12-02  
**Error**: `awk: cmd. line:1: ... backslash not last character on line`  
**Root Cause**: Dockerfile shell escaping issue with `+` character in awk pattern `/\"+rocm\"/`.  
**Fix**: Replaced `awk` with simpler `sed` command:
```dockerfile
# Before
ROCM_VERSION="$(uv pip show torch | awk '/Version/ {split($2,a,\"+rocm\"); print a[2]}')"
# After
ROCM_VERSION="$(uv pip show torch | grep "Version:" | sed 's/.*+rocm//')"
```
**Files Modified**: `Dockerfile` (line 65)

---

### Issue #3: uv pip uninstall -y Flag
**Date**: 2025-12-03  
**Error**: `error: unexpected argument '-y' found`  
**Root Cause**: The `uv` package manager doesn't support the `-y` (assume yes) flag for `pip uninstall`.  
**Fix**: Removed `-y` flag:
```dockerfile
# Before
uv pip uninstall -y amdsmi || true
# After
uv pip uninstall amdsmi || true
```
**Files Modified**: `Dockerfile` (line 119)

---

### Issue #4: huggingface-hub Extras Don't Exist
**Date**: 2025-12-03  
**Error**: 
```
warning: The package `huggingface-hub==1.1.7` does not have an extra named `hf-transfer`
warning: The package `huggingface-hub==1.1.7` does not have an extra named `cli`
```
**Root Cause**: The `[cli,hf_transfer]` extras don't exist in `huggingface-hub==1.1.7`.  
**Fix**: Install plain `huggingface-hub` without extras:
```dockerfile
# Before
uv pip install "huggingface-hub[cli,hf_transfer]"
# After
uv pip install huggingface-hub
```
**Files Modified**: `Dockerfile` (line 123)

---

### Issue #5: aioprometheus[starlette] Extra Doesn't Exist
**Date**: 2025-12-03  
**Error**: `Because there is no version of aioprometheus[starlette]==0.16.0`  
**Root Cause**: The `[starlette]` extra doesn't exist for `aioprometheus`.  
**Fix**: Removed the extra from `requirements.lock`:
```
# Before
aioprometheus[starlette]==0.16.0
# After
aioprometheus==0.16.0
```
**Files Modified**: `requirements.lock` (line 22)

---

### Issue #6: aioprometheus Version Doesn't Exist
**Date**: 2025-12-03  
**Error**: `Because there is no version of aioprometheus==0.16.0`  
**Root Cause**: `aioprometheus` uses a different versioning scheme (YY.MM.PATCH format, e.g., 23.12.0), not semantic versioning.  
**Fix**: Updated to latest available version:
```
# Before
aioprometheus==0.16.0
# After
aioprometheus==23.12.0
```
**Files Modified**: `requirements.lock` (line 22)  
**Available Versions**: 23.12.0, 23.3.0, 22.5.0, 22.3.0, 21.9.1, etc.

---

### Issue #7: lm-format-enforcer Version Doesn't Exist
**Date**: 2025-12-03  
**Error**: `Because there is no version of lm-format-enforcer==0.4.5`  
**Root Cause**: The pinned version `0.4.5` doesn't exist. The package jumped from 0.4.3 to 0.5.0.  
**Fix**: Updated to latest stable version:
```
# Before
lm-format-enforcer==0.4.5
# After
lm-format-enforcer==0.11.3
```
**Files Modified**: `requirements.lock` (line 27)  
**Available Versions**: 0.11.3, 0.11.2, 0.11.1, 0.10.12, ... 0.4.3, 0.4.2, 0.4.1

---

### Issue #8: sentencepiece Compilation Failure
**Date**: 2025-12-03  
**Error**: `error: 'uint32_t' does not name a type` during C++ compilation  
**Root Cause**: `sentencepiece==0.1.99` has C++ compilation issues with newer compilers (missing `<cstdint>` include).  
**Fix**: Updated to newer version with the fix:
```
# Before
sentencepiece==0.1.99
# After
sentencepiece==0.2.0
```
**Files Modified**: `requirements.lock` (line 16)  
**Available Versions**: 0.2.1, 0.2.0, 0.1.99 (broken), 0.1.98, etc.

---

### Issue #9: Double Free Corruption with numpy 2.x
**Date**: 2025-12-03  
**Error**: `double free or corruption (!prev)` when CMake tries to locate torch path  
**Root Cause**: numpy was being upgraded to 2.x by dependencies after we initially installed numpy<2. PyTorch ROCm nightly builds are not compatible with numpy 2.x.  
**Fix**: Moved `numpy<2` installation to AFTER all other dependencies to ensure it stays below 2.x:
```dockerfile
# Before: Install numpy<2 early, then other deps upgrade it
uv pip install "numpy<2" && ... && uv pip install -r requirements.lock

# After: Install all deps first, then force numpy<2
... && uv pip install -r requirements.lock && \
uv pip install "numpy<2" && \
python setup.py develop
```
**Files Modified**: `Dockerfile` (lines 118-130)

---

### Issue #10: setup.py develop Crashes During CMake Torch Detection
**Date**: 2025-12-03  
**Error**: `double free or corruption (!prev)` when CMake runs Python to locate torch path  
**Root Cause**: `python setup.py develop` triggers CMake which crashes when trying to detect torch installation path. This appears to be a memory corruption bug in the CMake/Python interaction.  
**Fix**: Switched from `setup.py develop` to `pip install --no-build-isolation -e .`:
```dockerfile
# Before
python setup.py develop

# After  
uv pip install --no-build-isolation -e .
```
**Files Modified**: `Dockerfile` (lines 129-131)

---

### Issue #11: Ubuntu 24.04 ROCm Apt Repository Dependency Conflicts
**Date**: 2025-12-03  
**Error**: `Depends: hipcc (= 1.1.1.60304-76~24.04) but 5.7.1-3 is to be installed`  
**Root Cause**: ROCm 6.3.4 packages in AMD's apt repository have version conflicts with Ubuntu 24.04's system packages (hipcc, rocm-cmake).  
**Fix**: Use `amdgpu-install` script instead of direct apt installation:
```dockerfile
# Before: Direct apt install (broken)
apt-get install -y rocm-dev rocm-libs

# After: Use amdgpu-install script
wget https://repo.radeon.com/amdgpu-install/6.3/ubuntu/noble/amdgpu-install_6.3.60300-1_all.deb
amdgpu-install -y --usecase=rocm --no-dkms
```
**Files Modified**: `Dockerfile` (lines 33-39)

---

### Issue #12: PyTorch Version String Format Incompatible with Index URL
**Date**: 2025-12-03  
**Error**: `Because there is no version of torch==2.5.0+rocm6.3`  
**Root Cause**: PyTorch's `--index-url` doesn't support version strings with `+rocm` suffix. The ROCm-specific index already filters by ROCm version.  
**Fix**: Remove version constraint and let the index determine the version:
```dockerfile
# Before: Version constraint fails
--index-url https://download.pytorch.org/whl/rocm6.3
torch==2.5.0+rocm6.3

# After: Let index determine latest
--index-url https://download.pytorch.org/whl/rocm6.3  
torch torchvision torchaudio
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu` (line ~56)

---

### Issue #13: vLLM Version Tag Doesn't Exist  
**Date**: 2025-12-03  
**Error**: `pathspec 'v0.10.3' did not match any file(s) known to git`  
**Root Cause**: vLLM tag `v0.10.3` doesn't exist. Latest in v0.10 series is `v0.10.2`.  
**Fix**: Updated to actual latest stable release:
```bash
# Before
VLLM_VERSION="v0.10.3"

# After
VLLM_VERSION="v0.10.2"  # Verified tag exists
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu`, `versions.env` (line 14)

---

### Issue #14: Missing setuptools_scm Build Dependency
**Date**: 2025-12-03  
**Error**: `ModuleNotFoundError: No module named 'setuptools_scm'`  
**Root Cause**: vLLM uses `setuptools_scm` to determine version from git tags. When using `--no-build-isolation`, build dependencies must be manually installed.  
**Fix**: Added `setuptools_scm` to pre-build installation:
```dockerfile
# Before
uv pip install setuptools wheel ninja

# After
uv pip install setuptools setuptools_scm wheel ninja
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu` (line ~78)

---

### Issue #15: Missing requirements-rocm.txt
**Date**: 2025-12-03  
**Error**: `File not found: requirements-rocm.txt`  
**Root Cause**: In vLLM v0.10.x, requirements files are located in the `requirements/` subdirectory.  
**Fix**: Updated path in Dockerfile:
```dockerfile
# Before
RUN uv pip install -r requirements-rocm.txt

# After
RUN uv pip install -r requirements/rocm.txt
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu` (line ~76)

---

### Issue #16: Unsupported ROCm Architecture (gfx1151)
**Date**: 2025-12-03  
**Error**: `None of the detected ROCm architectures: gfx1151 is supported.`  
**Root Cause**: vLLM v0.10.2's CMake configuration has a hardcoded list of supported architectures that excludes `gfx1151` (Strix Point).  
**Fix**: Patched `CMakeLists.txt` to add `gfx1151` to `HIP_SUPPORTED_ARCHS`:
```dockerfile
sed -i 's/set(HIP_SUPPORTED_ARCHS "/set(HIP_SUPPORTED_ARCHS "gfx1151;/g' CMakeLists.txt
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu` (line ~72)

---

### Issue #18: GCC 15 Incompatibility (Fedora 43)
**Date**: 2025-12-03  
**Error**: `error: reference to __host__ function '__glibcxx_assert_fail' in __host__ __device__ function`  
**Root Cause**: Fedora 43 uses GCC 15. The C++ standard library assertions are host-only, causing compilation errors in ROCm device code.  
**Fix**: Switched to `Dockerfile.ubuntu` (Ubuntu 24.04 uses GCC 13) which is compatible.  
**Alternative Fix**: Install `gcc-13` on Fedora.
**Files Modified**: Switched build target to `Dockerfile.ubuntu`

---

### Issue #19: Missing `rsync` Dependency (Ubuntu 24.04)
**Date**: 2025-12-03  
**Error**: `amdgpu-install : Depends: rsync but it is not installable`  
**Root Cause**: `amdgpu-install` requires `rsync`, which is not included in the base Ubuntu image.  
**Fix**: Added `rsync` and `dialog` to the initial `apt-get install` list in `Dockerfile.ubuntu`.
**Files Modified**: `Dockerfile.ubuntu` (line ~25)

---

### Issue #20: vLLM Platform Detection Failure (Missing `amdsmi`)
**Date**: 2025-12-03  
**Error**: `RuntimeError: Failed to infer device type`  
**Root Cause**: vLLM relies on `amdsmi` to detect ROCm, but the package is missing in the container.  
**Fix**: Patched `vllm/platforms/__init__.py` to fallback to `torch.version.hip` if `amdsmi` fails.
```dockerfile
sed -i 's/return "vllm.platforms.rocm.RocmPlatform" if is_rocm else None/import torch; return "vllm.platforms.rocm.RocmPlatform" if (is_rocm or torch.version.hip) else None/g' vllm/platforms/__init__.py
```
**Files Modified**: `Dockerfile.fedora`, `Dockerfile.ubuntu`

---

### Issue #21: PyTorch Version Mismatch / Segfaults (ROCm 6.3)
**Date**: 2025-12-03  
**Error**: `Memory access fault` / `invalid device function` with PyTorch `2.9.1+rocm6.3`.  
**Root Cause**: The PyTorch wheel for ROCm 6.3 appears to be unstable or mislabeled (2.9.1 doesn't exist), causing segfaults on Strix Point.  
**Fix**: Downgraded to **ROCm 6.2** and **PyTorch 2.5.1** (Stable).
**Files Modified**: `versions.env`, `Dockerfile.ubuntu`

---

### Issue #22: CMake Version Incompatibility (ROCm 6.2)
**Date**: 2025-12-03  
**Error**: `Compatibility with CMake < 3.5 has been removed from CMake` in `hiprtc-config.cmake`.  
**Root Cause**: `uv` installed CMake 4.x (bleeding edge), which dropped support for older CMake policies used by ROCm 6.2 config files.  
**Fix**: Pinned `cmake==3.29.0` in `Dockerfile.ubuntu`.
**Files Modified**: `Dockerfile.ubuntu`

---

### Issue #23: Python 3.12 Type Annotation Incompatibility
**Date**: 2025-12-03  
**Error**: `ValueError: Parameter block_size has unsupported type list[int]` in `torch._library.infer_schema`.  
**Root Cause**: PyTorch 2.5.1 (ROCm) internal schema inference fails with Python 3.12's generic alias types (`list[int]`) during vLLM model inspection.  
**Fix**: Downgraded to **Python 3.10** (Stable ML standard).
**Files Modified**: `versions.env`, `Dockerfile.ubuntu`

---

### Issue #24: Missing Python 3.10 on Ubuntu 24.04
**Date**: 2025-12-03  
**Error**: `Unable to locate package python3.10-dev`.  
**Root Cause**: Ubuntu 24.04 defaults to Python 3.12. Python 3.10 requires the `deadsnakes` PPA.  
**Fix**: Added `ppa:deadsnakes/ppa` to `Dockerfile.ubuntu`.
**Files Modified**: `Dockerfile.ubuntu`

---

### Issue #25: PyTorch 2.5.1 Schema Inference Error with `list[int]`
**Date**: 2025-12-03  
**Error**: `ValueError: infer_schema(func): Parameter block_size has unsupported type list[int]`.  
**Root Cause**: PyTorch 2.5.1's `torch.library.infer_schema` does not support PEP 585 `list[int]` type hints in custom op registration, even on Python 3.10.  
**Fix**: Patched `vllm/model_executor/layers/quantization/utils/fp8_utils.py` to use `typing.List[int]`.
**Files Modified**: `Dockerfile.ubuntu`

---

### Issue #26: SyntaxError in Platform Detection Patch
**Date**: 2025-12-03  
**Error**: `SyntaxError: invalid syntax` in `vllm/platforms/__init__.py`.  
**Root Cause**: Incorrect `sed` command created invalid Python code when patching `import amdsmi`.  
**Fix**: Corrected `sed` command to properly wrap the import in a `try/except` block.
**Files Modified**: `Dockerfile.ubuntu`

---

### Issue #27: HIP Error: Invalid Device Function (Architecture Mismatch)
**Date**: 2025-12-04  
**Error**: `RuntimeError: HIP error: invalid device function` during inference (RotaryEmbedding).  
**Root Cause**: The official PyTorch 2.5.1+rocm6.2 wheel likely does not contain kernels compiled for `gfx1151` (Strix Point).  
**Fix**: Investigating `HSA_OVERRIDE_GFX_VERSION` to spoof a supported architecture (e.g., `gfx1100`).
**Status**: Failed. `HSA_OVERRIDE_GFX_VERSION="11.0.0"` still results in `invalid device function` on simple PyTorch ops (suspected).
**Files Modified**: `test_inference.sh`

---

### Issue #28: Stable PyTorch Incompatible with gfx1151
**Date**: 2025-12-04  
**Error**: `RuntimeError: HIP error: invalid device function` (with stable wheel) and Segfault (with spoofing).  
**Root Cause**: Official PyTorch wheels lack `gfx1151` kernels. Spoofing `gfx1100` causes binary incompatibility crashes.  
**Fix**: Pivoting to "Hybrid" strategy: Use TheRock nightlies (which support `gfx1151`) + vLLM Patches (to fix `amdsmi` crash).
**Status**: Failed. `invalid device function` persists.
**Files Modified**: `versions.env`, `Dockerfile.ubuntu`

---

### Issue #29: Hybrid Build (TheRock) Invalid Device Function
**Date**: 2025-12-04
**Error**: `RuntimeError: HIP error: invalid device function` during inference.
**Root Cause**: Even with TheRock nightlies (supposedly gfx1151), PyTorch fails. Suspect wrong wheel installed or driver mismatch.
**Fix**: Debugging `torch.cuda.get_arch_list()` to verify installed wheel capabilities.
**Status**: Failed. Segfault (Memory access fault) with TheRock nightlies.
**Files Modified**: None.

---

### Issue #30: All Wheels Fail - Pivoting to AMD Base Image
**Date**: 2025-12-04
**Error**: Segfaults with Nightlies, Invalid Device with Stable.
**Root Cause**: Likely driver/kernel mismatch or specific Strix Point requirement not met by standard wheels.
**Fix**: Pivoting to use AMD's official `rocm/vllm-dev` image as the base. This image is validated for Radeon (Navi).
**Files Modified**: `Dockerfile` (planned)

---

### Issue #29: Runtime `ModuleNotFoundError: No module named 'vllm._C'`
- **Status**: **FIXED**
- **Description**: After successfully compiling vLLM for `gfx1100` (spoofed), the inference container failed to start with an import error for the C++ extension, even though `_C.abi3.so` existed.
- **Root Cause**: The compiled extension was missing RPATH entries to locate the PyTorch shared libraries (`libtorch.so`, `libc10.so`) which were located in `/opt/venv/lib/python3.12/site-packages/torch/lib`.
- **Fix**: Explicitly added the PyTorch library path to `LD_LIBRARY_PATH` in the runtime environment.
    ```bash
    export LD_LIBRARY_PATH="/opt/venv/lib/python3.12/site-packages/torch/lib:$LD_LIBRARY_PATH"
    ```

## Final Working Configuration (Build #32)
- **Hardware**: AMD Ryzen AI 9 HX 370 (Strix Point / gfx1151)
- **Base Image**: `rocm/vllm-dev:rocm7.1.1_navi_ubuntu24.04_py3.12_pytorch_2.8_vllm_0.10.2rc1`
- **PyTorch**: Pre-installed v2.8 (Nightly)
- **vLLM**: Compiled from source (v0.10.2)
- **Compilation Target**: `gfx1100` (Navi 31) - *Spoofed*
- **Runtime Override**: `HSA_OVERRIDE_GFX_VERSION="11.0.0"`
- **Critical Environment Var**: `LD_LIBRARY_PATH` including torch libs.

---

## Change Summary

### Dockerfile
- Line 65: Replaced `awk` with `sed` for ROCm version extraction
- Line 119: Removed `-y` flag from `uv pip uninstall`
- Line 120-128: Reordered numpy installation to prevent version upgrade
- Line 123: Removed extras from `huggingface-hub` installation

### requirements.lock
- Line 16: Updated `sentencepiece==0.1.99` → `sentencepiece==0.2.0`
- Line 22: Updated `aioprometheus[starlette]==0.16.0` → `aioprometheus==23.12.0`
- Line 27: Updated `lm-format-enforcer==0.4.5` → `lm-format-enforcer==0.11.3`

### TUTORIAL.md
- Added note about using `ssh -t` for interactive sudo prompts

---

## Lessons Learned

1. **uv vs pip differences**: The `uv` package manager doesn't support all `pip` flags (e.g., `-y`).
2. **Package extras verification**: Always verify that package extras exist before pinning them in lockfiles.
3. **Version scheme variations**: Some packages (like `aioprometheus`) use non-standard versioning schemes.
4. **Dockerfile escaping**: Complex shell constructs in Dockerfiles can have unexpected escaping issues; simpler is better.
5. **Lockfile version validation**: Pinned versions in lockfiles can become stale; always verify they exist before using.
6. **Compilation compatibility**: Older package versions may have C++ compilation issues with modern compilers.
7. **Dependency installation order**: When forcing specific versions, install them AFTER all dependencies to prevent upgrades.

---

## Next Steps

- [ ] Monitor build progress after `aioprometheus` fix
- [ ] Document any additional issues as they arise
### Issue #30: Runtime Hang/Deadlock on gfx1151 (ROCm 7.1)
- **Status**: **CONFIRMED**
- **Description**: Both "Hybrid" (Build #32) and "Nuclear" (Build #33) builds hang indefinitely during inference with 100% CPU usage.
- **Diagnosis**: PyTorch stress test (matrix multiplication) also hangs. This confirms a fundamental driver/kernel instability with ROCm 7.1 on Strix Point.
- **Attempted Fix**: Enabled `amdgpu.cwsr_enable=1` (Compute Wave Save Restore).
- **Outcome**: Failed. Deadlock persisted.
- **Resolution**: Pivot to "Nuclear Option" with **ROCm 6.2.4** (Stable LTS).

---

### Issue #31: SSH Hostname Resolution Failure
- **Date**: 2025-12-05
- **Error**: `ssh: Could not resolve hostname aimax`
- **Root Cause**: Local DNS or mDNS issue.
- **Fix**: Switched to using IP address `192.168.88.12`.

---

### Issue #32: Missing `python3-venv` in ROCm 6.2 Base
- **Date**: 2025-12-05
- **Error**: `The virtual environment was not created successfully because ensurepip is not available.`
- **Root Cause**: `rocm/dev-ubuntu-24.04:6.2.4` is a minimal image lacking `python3-venv`.
- **Fix**: Added `python3-venv` to `apt-get install` in `Dockerfile.nuclear_6.2`.

---

### Issue #33: Missing `rocrand` (CMake Error)
- **Date**: 2025-12-05
- **Error**: `Could not find a package configuration file provided by "rocrand"`
- **Root Cause**: Base image lacks ROCm math libraries.
- **Fix**: Added `rocrand-dev`, `rocprim-dev`, `hiprand-dev`.

---

### Issue #34: Missing `rocblas` (CMake Error)
- **Date**: 2025-12-06
- **Error**: `Could not find a package configuration file provided by "rocblas"`
- **Root Cause**: More missing math libraries.
- **Fix**: Added `rocblas-dev`, `hipblas-dev`, `rocfft-dev`, `rocsolver-dev`, `rocsparse-dev`, `miopen-hip-dev`.

---

### Issue #35: Missing `hipblaslt` (CMake Error)
- **Date**: 2025-12-06
- **Error**: `Could not find a package configuration file provided by "hipblaslt"`
- **Fix**: Added `hipblaslt-dev`, `rccl-dev`.

---

### Issue #36: Missing `hipfft` (CMake Error)
- **Date**: 2025-12-06
- **Error**: `Could not find a package configuration file provided by "hipfft"`
- **Fix**: Added `hipfft-dev`, `hipsolver-dev`, `hipsparse-dev`, `rocthrust-dev`, `hipcub-dev`.

---

### Issue #37: Linker Error (Relocation out of range)
- **Date**: 2025-12-06
- **Error**: `relocation R_X86_64_PC32 out of range` linking `libaotriton_v2.so`
- **Root Cause**: `aotriton` binary exceeded 2GB because it was building kernels for ALL AMD architectures (MI200, MI300, etc.).
- **Fix**: 
    1. Set `ENV AOTRITON_GPU_TARGETS="gfx1151"` to build only for Strix Point.
    2. Added `ENV CXXFLAGS="-mcmodel=medium"` as a safeguard.

### Issue #38: Track D (Locked Spoof) Blocked by Firmware Faults
- **Date**: 2025-12-06
- **Error**: `GCVM_L2_PROTECTION_FAULT_STATUS:0x00800932` / `PERMISSION_FAULTS: 0x3` in `dmesg`.
- **Root Cause**: The GPU firmware on Strix Halo (`gfx1151`) rejects memory access from compute kernels spoofing `gfx1100`. This is a security/hardware-level block that cannot be bypassed with kernel flags (`amdgpu.noretry=0`, `iommu=pt`) or privileged containers.
- **Resolution**: **SUSPENDED**. Requires official ROCm 8.0 support or a firmware update.
- **Workaround**: Pivoted to Track E (Vulkan).

---

### Issue #39: Vulkan Build Failure (Missing `glslc`)
- **Date**: 2025-12-06
- **Error**: `Could NOT find Vulkan (missing: glslc)` during CMake configuration.
- **Root Cause**: The default `vulkan-sdk` package in Ubuntu 24.04 (Noble) does not include the shader compiler `glslc`.
- **Fix**: Added the **LunarG Noble** repository to `Dockerfile.vulkan` to install the full SDK.
- **Files Modified**: `Dockerfile.vulkan`

---

### Issue #40: Vulkan Inference "Invalid Argument"
- **Date**: 2025-12-06
- **Error**: `error: invalid argument: /app/llama.cpp/build/bin/llama-cli`
- **Root Cause**: The container's default `ENTRYPOINT` was `llama-server`, so passing the CLI path as an argument caused a conflict.
- **Fix**: Overrode the entrypoint using `--entrypoint` in the run command.
- **Files Modified**: `test_vulkan_inference.sh`
