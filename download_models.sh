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

# Sudo Keep-Alive
echo "🔑 Acquiring sudo privilege for config generation..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


# Helper function to setup a model
setup_model() {
    local NAME=$1
    local REPO=$2
    local FILE=$3
    local PORT=$4
    local CTX=$5
    local EXTRA=$6
    
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
    {
        echo "MODEL_FILE=$FILE"
        echo "PORT=$PORT"
        echo "CTX_SIZE=$CTX"
        echo "N_GPU_LAYERS=999"
        if [ -n "$EXTRA" ]; then
            echo "EXTRA_ARGS=$EXTRA"
        fi
    } | sudo tee $CONFIG_DIR/$NAME.env > /dev/null

    echo "✅ Ready! Start with: sudo systemctl start llama-vulkan@$NAME"
}

# --- Model Definitions ---

# 1. Qwen 3 Coder 30B (Coding Specialist)
# Note: Using lmstudio-community as it has the standard naming convention
setup_model "qwen3-coder-30b" \
    "lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-GGUF" \
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
    "bartowski/Qwen_Qwen3-Next-80B-A3B-Instruct-GGUF" \
    "Qwen_Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf" \
    8083 \
    8192

# 4. Qwen 3 Next 80B Thinking (Reasoning)
setup_model "qwen3-next-80b-thinking" \
    "bartowski/Qwen_Qwen3-Next-80B-A3B-Thinking-GGUF" \
    "Qwen_Qwen3-Next-80B-A3B-Thinking-Q4_K_M.gguf" \
    8084 \
    8192

# --- NVIDIA Fleet ---

# 5. AceMath 72B Instruct (Math Specialist)
setup_model "nvidia-acemath-72b" \
    "mradermacher/AceMath-72B-Instruct-GGUF" \
    "AceMath-72B-Instruct.Q4_K_M.gguf" \
    8085 \
    8192

# 6. AceMath 7B Instruct (Math Specialist - Small)
setup_model "nvidia-acemath-7b" \
    "mradermacher/AceMath-7B-Instruct-GGUF" \
    "AceMath-7B-Instruct.Q4_K_M.gguf" \
    8086 \
    32768

# 7. Nemotron Super 49B (Llama 3.3 Derivative)
setup_model "nvidia-nemotron-49b" \
    "bartowski/nvidia_Llama-3_3-Nemotron-Super-49B-v1_5-GGUF" \
    "nvidia_Llama-3_3-Nemotron-Super-49B-v1_5-Q4_K_M.gguf" \
    8087 \
    8192

# 8. Nemotron Nano 12B (Mistral-Nemo based?)
setup_model "nvidia-nemotron-12b" \
    "bartowski/nvidia_NVIDIA-Nemotron-Nano-12B-v2-GGUF" \
    "nvidia_NVIDIA-Nemotron-Nano-12B-v2-Q4_K_M.gguf" \
    8088 \
    8192

# 9. NV-Reason-CXR-3B (Medical VLM)
# Note: Requires multimodal projector (mmproj). Skipping auto-setup for now as it needs extra files.
# setup_model "nvidia-cxr-3b" ...

# 10. CoEmbed 3B (Embedding Model)
# Note: No GGUF available yet. Manual setup required.
# setup_model "nvidia-coembed-3b" \
#     "bartowski/nvidia_Llama-NeMoRetriever-CoEmbed-3B-v1-GGUF" \
#     "nvidia_Llama-NeMoRetriever-CoEmbed-3B-v1-Q4_K_M.gguf" \
#     8089 \
#     8192 \
#     "--embedding"

# 11. OpenReasoning Nemotron 32B (Reasoning Specialist)
setup_model "nvidia-openreasoning-32b" \
    "bartowski/nvidia_OpenReasoning-Nemotron-32B-GGUF" \
    "nvidia_OpenReasoning-Nemotron-32B-Q4_K_M.gguf" \
    8090 \
    32768

# 12. Nemotron 8B UltraLong (1M Context)
setup_model "nvidia-nemotron-8b-ultralong" \
    "bartowski/nvidia_Llama-3.1-8B-UltraLong-1M-Instruct-GGUF" \
    "nvidia_Llama-3.1-8B-UltraLong-1M-Instruct-Q4_K_M.gguf" \
    8091 \
    131072
    # Note: 1M context requires massive RAM. Capped at 128k for safety.

# 13. LLaVA 1.6 Mistral 7B (Vision)
echo "---------------------------------------------------"
echo "🚀 Setting up: llava-v1.6-mistral-7b"
REPO="cjpais/llava-1.6-mistral-7b-gguf"
FILE="llava-v1.6-mistral-7b.Q4_K_M.gguf"
PROJ="mmproj-model-f16.gguf"

# Download Model
if [ ! -f "$MODEL_DIR/$FILE" ]; then
    echo "⬇️  Downloading Model..."
    huggingface-cli download $REPO $FILE --local-dir $MODEL_DIR --local-dir-use-symlinks False
fi

# Download Projector
if [ ! -f "$MODEL_DIR/$PROJ" ]; then
    echo "⬇️  Downloading Projector..."
    huggingface-cli download $REPO $PROJ --local-dir $MODEL_DIR --local-dir-use-symlinks False
fi

# Create Config
echo "📝 Generating config: $CONFIG_DIR/llava-v1.6-mistral-7b.env"
{
    echo "MODEL_FILE=$FILE"
    echo "PORT=8001"
    echo "CTX_SIZE=8192"
    echo "N_GPU_LAYERS=999"
    echo "EXTRA_ARGS=\"--mmproj /models/$PROJ\""
} | sudo tee $CONFIG_DIR/llava-v1.6-mistral-7b.env > /dev/null

echo "✅ Ready! Start with: sudo systemctl start llama-vulkan@llava-v1.6-mistral-7b"

echo "---------------------------------------------------"
echo "🎉 All models configured!"
echo "⚠️  NOTE: 80B/72B models require ~48GB VRAM. Run only ONE at a time."
echo "⚠️  Skipped (Not Supported/No GGUF):"
echo "   - Cosmos (Diffusion/World Model)"
echo "   - Hymba (Architecture not supported in llama.cpp yet)"
echo "   - MambaVision (No GGUF)"
echo "   - NV-Embed-v2 (No GGUF)"
echo "   - Reward Models (No GGUF)"
