
podman run -it --rm \
  --network=host \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add=video \
  --group-add=render \
  --ipc=host \
  --security-opt seccomp=unconfined \
  --cap-add=SYS_PTRACE \
  --ulimit memlock=-1:-1 \
  --ulimit stack=67108864:67108864 \
  -e HSA_OVERRIDE_GFX_VERSION=11.5.1 \
  strix-vllm:local


