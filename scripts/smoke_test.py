import os
from vllm import LLM, SamplingParams

def main():
    model = os.environ.get("SMOKE_MODEL", "Qwen/Qwen2.5-0.5B-Instruct")
    llm = LLM(model=model, dtype="bfloat16", tensor_parallel_size=1)
    sampling_params = SamplingParams(temperature=0.7, max_tokens=64)

    out = llm.generate(
        ["Say hello from Strix Halo ROCm stack"],
        sampling_params=sampling_params,
    )
    print(out[0].outputs[0].text)

if __name__ == "__main__":
    main()
    