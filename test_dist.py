import os
import torch
import torch.distributed as dist
import time

print(f"PyTorch Version: {torch.__version__}")
print(f"ROCm Version: {torch.version.hip}")
print(f"CUDA Available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Device Name: {torch.cuda.get_device_name(0)}")

os.environ["MASTER_ADDR"] = "127.0.0.1"
os.environ["MASTER_PORT"] = "29500"
os.environ["RANK"] = "0"
os.environ["WORLD_SIZE"] = "1"

print("Initializing process group (nccl)...")
start = time.time()
try:
    dist.init_process_group(backend="nccl", init_method="tcp://127.0.0.1:29500")
    print(f"Success! Took {time.time() - start:.2f}s")
except Exception as e:
    print(f"Failed: {e}")

print("Creating tensor on GPU...")
t = torch.ones(1).cuda()
print("All reduce...")
dist.all_reduce(t)
print("Done!")
