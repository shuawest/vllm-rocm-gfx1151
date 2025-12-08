#!/bin/bash
set -e

# Configuration
SERVICE_DIR="/etc/systemd/system"
CONFIG_DIR="/etc/vllm"
HF_CACHE="/home/jowest/.cache/huggingface"

# Ensure directories exist
echo "📂 Creating directories..."
sudo mkdir -p "$CONFIG_DIR"
mkdir -p "$HF_CACHE"
sudo chown -R jowest:jowest "$HF_CACHE"

# Install Service Template (if not exists, we assume vllm@.service is compatible or we create a specific one)
# We'll use a specific vllm-rocm@.service for AMD to avoid confusion with NVIDIA
echo "⚙️  Installing systemd service template..."

cat <<EOF | sudo tee "$SERVICE_DIR/vllm-rocm@.service" > /dev/null
[Unit]
Description=vLLM ROCm Inference Service - %i
After=network.target

[Service]
Type=simple
User=jowest
Group=jowest
EnvironmentFile=/etc/vllm/%i.env
ExecStartPre=-/usr/bin/podman stop vllm-%i
ExecStartPre=-/usr/bin/podman rm vllm-%i
ExecStart=/usr/bin/podman run --rm \\
    --name vllm-%i \\
    --device /dev/kfd --device /dev/dri \\
    --security-opt label=disable \\
    --shm-size=16g \\
    -v /home/jowest/.cache/huggingface:/root/.cache/huggingface \\
    -e HUGGING_FACE_HUB_TOKEN=\${HF_TOKEN} \\
    -p \${PORT}:8000 \\
    \${IMAGE_NAME} \\
    --model \${MODEL_NAME} \\
    --gpu-memory-utilization \${GPU_MEM_FRACTION} \\
    \${EXTRA_ARGS}
ExecStop=/usr/bin/podman stop vllm-%i
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload

# Helper to create config
create_config() {
    local NAME=$1
    local IMAGE=$2
    local PORT=$3
    local MEM_FRAC=$4
    local MODEL_NAME=$5
    local EXTRA=$6
    
    # Check for HF Token
    if [ -z "$HF_TOKEN" ]; then
        if [ -f "hf_token.txt" ]; then
            HF_TOKEN=$(cat hf_token.txt)
        else
            echo "⚠️  HF_TOKEN not set! Models might fail to download."
        fi
    fi

    echo "📝 Generating config: $CONFIG_DIR/$NAME.env"
    
    {
        echo "IMAGE_NAME=$IMAGE"
        echo "PORT=$PORT"
        echo "GPU_MEM_FRACTION=$MEM_FRAC"
        echo "MODEL_NAME=$MODEL_NAME"
        echo "HF_TOKEN=$HF_TOKEN"
        if [ -n "$EXTRA" ]; then
            echo "EXTRA_ARGS=\"$EXTRA\""
        fi
    } | sudo tee "$CONFIG_DIR/$NAME.env" > /dev/null
    
    sudo systemctl enable "vllm-rocm@$NAME"
    echo "✅ Configured $NAME on port $PORT"
}

# --- Define Models ---

# 1. LLaVA 1.6 Mistral 7B
# Using rocm/vllm-dev image or official vllm/vllm-rocm if available. 
# Official: vllm/vllm-rocm:latest
create_config "llava" \
    "docker.io/rocm/vllm-dev:rocm6.4.2_navi_ubuntu24.04_py3.12_pytorch_2.7_vllm_0.9.2" \
    8001 \
    0.30 \
    "llava-hf/llava-v1.6-mistral-7b-hf" \
    "--trust-remote-code --max-model-len 8192"

echo "---------------------------------------------------"
echo "🎉 Setup complete!"
echo "To start services:"
echo "  sudo systemctl start vllm-rocm@llava"
