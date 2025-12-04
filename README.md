# vLLM Build System for AMD ROCm gfx1151

This repository contains two Dockerfile configurations for building vLLM with ROCm support on gfx1151 (Strix Point/Halo) hardware:

## Dockerfiles

### Dockerfile.fedora (Primary - Red Hat Aligned)
- **Base**: Fedora 43
- **Purpose**: Red Hat/RHEL-aligned build for upstream contribution
- **ROCm**: Installed from AMD's RHEL9 RPM repository
- **Default**: This is the default build target

### Dockerfile.ubuntu (Alternative)
- **Base**: Ubuntu 24.04  
- **Purpose**: Alternative build using AMD's validated platform
- **ROCm**: Installed via `amdgpu-install` script
- **Use Case**: When Fedora/RHEL ROCm packages have issues

## Building

```bash
# Build Fedora version (default)
./build_pipeline.sh

# Build Ubuntu version
DOCKERFILE=Dockerfile.ubuntu ./build_pipeline.sh

# Build both
./build_pipeline.sh && DOCKERFILE=Dockerfile.ubuntu IMAGE_NAME=strix-vllm-ubuntu ./build_pipeline.sh
```

## Configuration

Both builds use the same stable versions defined in `versions.env`:
- ROCm: 6.3 (stable)
- PyTorch: 2.5.0+rocm6.3
- vLLM: v0.10.3
- Python: 3.12

See `antigravity_spec.md` for full version strategy and rationale.
