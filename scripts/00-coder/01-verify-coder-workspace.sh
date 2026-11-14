#!/bin/bash
TRAINING_SKIP_SETUP=1
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "00.1 — Verify Coder Workspace & Persistent Storage" 5

step "Inspect workspace host & persistent /home/coder volume (Ceph RBD)" \
  'echo "Hostname: $(hostname) | User: $(whoami)" && df -h "$HOME"'

step "Check shared memory (/dev/shm for PyTorch DataLoader & NCCL)" \
  'df -h /dev/shm 2>/dev/null || echo "/dev/shm not mounted"'

step "Write a persistence marker file into ~/training-persistence-check.txt" \
  'echo "Verified on $(hostname) at $(date -Iseconds)" > "$HOME/training-persistence-check.txt" && cat "$HOME/training-persistence-check.txt"'

step "Verify outbound internet access via Berkelium IPv6 + NAT64 gateway" \
  'curl -fsSI https://github.com | head -n 5'

step "Check attached accelerator (NVIDIA / AMD) or CPU-only mode" \
  'if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then nvidia-smi; elif command -v rocminfo >/dev/null 2>&1; then rocminfo | grep -E "Marketing Name|Name:" | head -n 6; else echo "No GPU attached (CPU-only workspace)."; fi'
