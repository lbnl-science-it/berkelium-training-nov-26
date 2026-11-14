#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "02.1 — Discover GPU Models, DRA DeviceClasses & ResourceSlices" 4

step "List Berkelium nodes with NVIDIA & AMD GPU hardware labels" \
  "kubectl get nodes -L nvidia.com/gpu.product,amd.com/gpu.device-id"

step "Count GPU worker nodes by NVIDIA accelerator model" \
  "kubectl get nodes -l nvidia.com/gpu.product -L nvidia.com/gpu.product --no-headers | awk '{print \$NF}' | sort | uniq -c"

step "List Kubernetes Dynamic Resource Allocation (DRA) DeviceClasses" \
  "kubectl get deviceclass"

step "Inspect sample DRA ResourceSlices published by GPU nodes" \
  'kubectl get resourceslices -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,DRIVER:.spec.driver | grep -E "NODE|gpu\." | head -n 20'
