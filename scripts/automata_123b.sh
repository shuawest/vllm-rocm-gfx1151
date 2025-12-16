#!/bin/bash
set -e

# Model ID for Devstral 2 123B
MODEL_ID="mistralai/Devstral-2-123B-Instruct-2512"
OUTPUT_DIR="/models/devstral-2-123b-awq"

# Ensure we have the token
if [ -z "$HF_TOKEN" ]; then
    if [ -f "hf_token.txt" ]; then
        export HF_TOKEN=$(cat hf_token.txt)
    else
        echo "❌ Error: HF_TOKEN env var not set and hf_token.txt not found."
        exit 1
    fi
fi

echo "🚀 Starting Automata for Devstral 2 123B Quantization..."
echo "   Model: $MODEL_ID"
echo "   Output: $OUTPUT_DIR"
echo "   Note: This model is HUGE (~70GB @ 4-bit). Ensure you have >100GB disk space and >80GB RAM/Swap."

# Run the quantization using the container
# We assume this script is running from the host, triggering the container
podman run --rm \
    -v $(pwd)/models:/models \
    -v $(pwd)/scripts:/app/scripts \
    -e HF_TOKEN=$HF_TOKEN \
    aimax-vllm \
    python3 /app/scripts/quantize_awq.py \
    --model_id $MODEL_ID \
    --quant_path $OUTPUT_DIR \
    --bits 4

echo "✅ Quantization Complete!"
echo "   You can now run it with: ./start_vllm_aimax.sh $(pwd)$OUTPUT_DIR 8000"
