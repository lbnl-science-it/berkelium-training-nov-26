#!/bin/bash
set -e

echo "=== 1. Workspace Host & Persistent Storage (/home/coder on ceph-rbd) ==="
echo "Hostname : $(hostname)"
echo "User     : $(whoami)"
df -h "$HOME"

echo ""
echo "=== 2. Shared Memory (/dev/shm for PyTorch DataLoader & NCCL) ==="
df -h /dev/shm 2>/dev/null || echo "/dev/shm not mounted"

echo ""
echo "=== 3. Persistence Test in ~/training-persistence-check.txt ==="
STAMP="Verified on $(hostname) at $(date -Iseconds)"
echo "$STAMP" > "$HOME/training-persistence-check.txt"
cat "$HOME/training-persistence-check.txt"
echo "(Stop & restart your Coder workspace—this file in /home/coder persists on Ceph RBD!)"

echo ""
echo "=== 4. Outbound Internet via Berkelium IPv6 + NAT64 Gateway ==="
curl -fsSI https://github.com | head -n 5

echo ""
echo "=== 5. Installed Developer & Scientific Tooling ==="
for tool in git uv python3 kubectl helm k9s claude aider opencode; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  [OK] %-10s -> %s\n" "$tool" "$(command -v "$tool")"
  fi
done

echo ""
echo "=== 6. Accelerator Check (NVIDIA / AMD) ==="
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  nvidia-smi
elif command -v rocminfo >/dev/null 2>&1; then
  rocminfo | grep -E "Marketing Name|Name:" | head -n 6
else
  echo "No GPU attached to this workspace (CPU-only mode)."
  echo "Tip: Launch the 'PyTorch / CUDA' template at https://coder.bk.lbl.gov with 1x NVIDIA A40/A100/H100/H200/B300!"
fi
