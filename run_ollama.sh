#!/bin/bash
set -e

echo "🦙 Running Track F: Ollama (Official)..."
echo "   Config: OLLAMA_GPU_MEMORY=96GB (Fixes visibility issue)"

# Ensure the user has the render group permissions
if ! groups | grep -q "render"; then
    echo "⚠️  Warning: Current user is not in 'render' group. You may need to add it or use sudo."
fi

podman run -d --rm \
    --name ollama_gfx1151 \
    --device /dev/kfd \
    --device /dev/dri \
    --security-opt seccomp=unconfined \
    -v ollama_data:/root/.ollama \
    -p 11434:11434 \
    -e OLLAMA_GPU_MEMORY=96GB \
    docker.io/ollama/ollama:latest

echo "✅ Ollama started!"
echo "Try running a model: podman exec -it ollama_gfx1151 ollama run llama3.2"
