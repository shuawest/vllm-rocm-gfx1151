import torch
import time

def stress_test():
    print(f"PyTorch Version: {torch.__version__}")
    print(f"ROCm Version: {torch.version.hip}")
    
    if not torch.cuda.is_available():
        print("CUDA/ROCm not available!")
        return

    device = torch.device("cuda")
    print(f"Using device: {torch.cuda.get_device_name(0)}")

    # 1. Basic Matrix Multiplication
    print("\n--- Test 1: Large Matrix Multiplication ---")
    size = 8192
    a = torch.randn(size, size, device=device, dtype=torch.float16)
    b = torch.randn(size, size, device=device, dtype=torch.float16)
    
    start = time.time()
    for i in range(10):
        c = torch.matmul(a, b)
        torch.cuda.synchronize()
        print(f"Iter {i+1}: Done")
    end = time.time()
    print(f"Matmul Time: {end - start:.4f}s")

    # 2. Basic Attention (SDPA)
    print("\n--- Test 2: Scaled Dot Product Attention ---")
    batch, heads, seq, dim = 4, 32, 2048, 128
    q = torch.randn(batch, heads, seq, dim, device=device, dtype=torch.float16)
    k = torch.randn(batch, heads, seq, dim, device=device, dtype=torch.float16)
    v = torch.randn(batch, heads, seq, dim, device=device, dtype=torch.float16)

    start = time.time()
    for i in range(10):
        out = torch.nn.functional.scaled_dot_product_attention(q, k, v)
        torch.cuda.synchronize()
        print(f"Iter {i+1}: Done")
    end = time.time()
    print(f"Attention Time: {end - start:.4f}s")

    print("\n✅ PyTorch Stress Test Passed!")

if __name__ == "__main__":
    stress_test()
