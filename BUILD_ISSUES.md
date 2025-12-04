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
- [ ] Update this log with resolution timestamps once build succeeds
