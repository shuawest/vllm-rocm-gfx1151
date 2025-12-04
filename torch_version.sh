
podman run --rm strix-vllm:local \
  bash -lc "uv pip show torch | grep Version"
