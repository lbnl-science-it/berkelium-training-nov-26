#!/usr/bin/env python3
"""Quick PyTorch CPU/GPU verification & matrix-multiply benchmark for Coder workspaces."""

import os
import shutil
import time

try:
    import torch
except ImportError:
    print("PyTorch is not pre-installed in this template.")
    print("Run this inside the 'PyTorch / CUDA' (cuda) or 'Data Lab' (data-lab) Coder template,")
    print("or run with uv:  uv run --with torch python3 02-pytorch-gpu-check.py")
    raise SystemExit(0)

print(f"PyTorch version : {torch.__version__}")
print(f"CUDA available  : {torch.cuda.is_available()}")

shm_total, shm_used, shm_free = shutil.disk_usage("/dev/shm")
print(f"/dev/shm size   : {shm_total / (1024**3):.1f} GiB ({shm_free / (1024**3):.1f} GiB free)")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
if device.type == "cuda":
    props = torch.cuda.get_device_properties(0)
    print(f"GPU 0           : {props.name} ({props.total_memory / (1024**3):.1f} GiB VRAM, sm_{props.major}{props.minor})")
    n = 8192
    dtype = torch.bfloat16
else:
    print(f"Running on CPU  : {os.cpu_count()} logical cores visible")
    n = 2048
    dtype = torch.float32

a = torch.randn((n, n), device=device, dtype=dtype)
b = torch.randn((n, n), device=device, dtype=dtype)

# Warmup
_ = a @ b
if device.type == "cuda":
    torch.cuda.synchronize()

iters = 10
t0 = time.perf_counter()
for _ in range(iters):
    c = a @ b
if device.type == "cuda":
    torch.cuda.synchronize()
elapsed = time.perf_counter() - t0

tflops = (2 * (n**3) * iters) / elapsed / 1e12
print(f"MatMul ({n}x{n}, {dtype}) : {tflops:.2f} TFLOPS ({elapsed * 1000 / iters:.2f} ms/iter)")
