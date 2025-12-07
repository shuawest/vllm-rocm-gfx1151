#!/bin/bash
set -e

# Configuration
MODEL_DIR="/data/models"
CONFIG_DIR="/etc/llama-vulkan"

# Ensure tools are available
if ! command -v huggingface-cli &> /dev/null; then
    echo "📦 Installing huggingface-cli..."
    pip install -U "huggingface_hub[cli]"
fi

# Helper function to setup a model
setup_model() {
    local NAME=$1
    local REPO=$2
    local FILE=$3
    local PORT=$4
    local CTX=$5
    
    echo "---------------------------------------------------"
    echo "🚀 Setting up: $NAME"
    echo "   Repo: $REPO"
    echo "   File: $FILE"
    
    # 1. Download
    if [ ! -f "$MODEL_DIR/$FILE" ]; then
        echo "⬇️  Downloading..."
        huggingface-cli download $REPO $FILE --local-dir $MODEL_DIR --local-dir-use-symlinks False
    else
        echo "✅ Model file already exists."
    fi

    # 2. Create Config
    echo "📝 Generating config: $CONFIG_DIR/$NAME.env"
    cat <<EOF | sudo tee $CONFIG_DIR/$NAME.env > /dev/null
MODEL_FILE=$FILE
PORT=$PORT
CTX_SIZE=$CTX
N_GPU_LAYERS=999
EOF

    echo "✅ Ready! Start with: sudo systemctl start llama-vulkan@$NAME"
}

# --- Model Definitions ---

# 1. Qwen 3 Coder 30B (Coding Specialist)
setup_model "qwen3-coder-30b" \
    "bartowski/Qwen3-Coder-30B-A3B-Instruct-GGUF" \
    "Qwen3-Coder-30B-A3B-Instruct-Q4_K_M.gguf" \
    8081 \
    32768

# 2. Llama 3.3 70B (General Purpose)
setup_model "llama3.3-70b" \
    "bartowski/Llama-3.3-70B-Instruct-GGUF" \
    "Llama-3.3-70B-Instruct-Q4_K_M.gguf" \
    8082 \
    8192

# 3. Qwen 3 Next 80B Instruct (General Purpose)
setup_model "qwen3-next-80b-instruct" \
    "bartowski/Qwen3-Next-80B-A3B-Instruct-GGUF" \
    "Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf" \
    8083 \
    8192

# 4. Qwen 3 Next 80B Thinking (Reasoning)
setup_model "qwen3-next-80b-thinking" \
    "bartowski/Qwen3-Next-80B-A3B-Thinking-GGUF" \
    "Qwen3-Next-80B-A3B-Thinking-Q4_K_M.gguf" \
    8084 \
    8192

echo "---------------------------------------------------"
echo "🎉 All models configured!"
echo "⚠️  NOTE: 80B models require ~48GB VRAM. Run only ONE at a time."
