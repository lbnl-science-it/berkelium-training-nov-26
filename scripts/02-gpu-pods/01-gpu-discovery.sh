#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

echo "=== 1. Berkelium Nodes & GPU Hardware Labels (NVIDIA & AMD) ==="
kubectl get nodes -L nvidia.com/gpu.product,amd.com/gpu.device-id

echo ""
echo "=== 2. Node Counts by NVIDIA GPU Model ==="
kubectl get nodes -l nvidia.com/gpu.product -L nvidia.com/gpu.product --no-headers \
  | awk '{print $NF}' | sort | uniq -c

echo ""
echo "=== 3. Dynamic Resource Allocation (DRA) DeviceClasses ==="
kubectl get deviceclass

echo ""
echo "=== 4. Sample DRA ResourceSlices Published by GPU Nodes ==="
kubectl get resourceslices -o 'custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,DRIVER:.spec.driver' | grep -E "NODE|gpu\." | head -n 20
