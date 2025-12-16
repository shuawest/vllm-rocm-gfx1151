
import argparse
import os
from awq import AutoAWQForCausalLM
from transformers import AutoTokenizer

def quantize(model_id, quant_path, bits=4, group_size=128):
    print(f"Loading model: {model_id}")
    model = AutoAWQForCausalLM.from_pretrained(model_id, safetensors=True, device_map="auto")
    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)

    quant_config = {
        "zero_point": True,
        "q_group_size": group_size,
        "w_bit": bits,
        "version": "GEMM"
    }

    print(f"Quantizing with config: {quant_config}")
    model.quantize(tokenizer, quant_config=quant_config)

    print(f"Saving quantized model to: {quant_path}")
    model.save_quantized(quant_path)
    tokenizer.save_pretrained(quant_path)
    print("Quantization complete!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Quantize a model using AutoAWQ")
    parser.add_argument("--model_id", type=str, required=True, help="Hugging Face model ID")
    parser.add_argument("--quant_path", type=str, required=True, help="Output path for quantized model")
    parser.add_argument("--bits", type=int, default=4, help="Quantization bits")
    
    args = parser.parse_args()
    
    quantize(args.model_id, args.quant_path, args.bits)
