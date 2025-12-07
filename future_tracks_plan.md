# Future Tracks Exploration Plan (Based on ANALYSIS.md)

## Overview
The `ANALYSIS.md` document highlights that while our current "Spoof" strategy (Track C/D) works for vLLM, it may not be the most performant option for all workloads. Specifically, the Vulkan backend in `llama.cpp` offers significantly higher prompt processing speeds.

## Potential New Tracks

### Track E: The Vulkan Speedster (llama.cpp)
- **Goal**: Maximize prompt processing speed (targeting ~884 tok/s).
- **Method**: Build `llama.cpp` with `GGML_VULKAN=ON`.
- **Pros**: 2.5x faster prompt processing than HIP.
- **Cons**: Slower token generation than HIP; different ecosystem than vLLM.
- **Action**: Create `Dockerfile.vulkan` and build script.

### Track F: The Simple Server (Ollama)
- **Goal**: Easiest deployment for general use.
- **Method**: Run official Ollama container with `OLLAMA_GPU_MEMORY=96GB` env var.
- **Pros**: Extremely simple; official support in v0.6.2.
- **Cons**: Less control than vLLM; manual memory config required.
- **Action**: Create `run_ollama.sh` helper script.

### Track G: The Rust Alternative (Burn/Ratchet)
- **Goal**: Explore non-ROCm dependencies.
- **Method**: Build a Rust-based inference container using WGPU/Vulkan.
- **Pros**: Bypasses ROCm stack entirely.
- **Cons**: Immature ecosystem compared to PyTorch/vLLM.
- **Action**: Low priority research task.

## Recommendation
1. **Finish Track B**: Let the current vLLM hybrid build finish.
2. **Reboot**: User updates kernel to 6.17+.
3. **Implement Track E (Vulkan)**: This complements vLLM by offering a high-throughput alternative for specific workloads.
