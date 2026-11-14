#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "02.3 — Allocate a GPU via Kubernetes DRA (firstAvailable)" 6

step "Inspect ResourceClaimTemplate (firstAvailable across A40/H200/A100/H100/B300) + Pod" \
  "cat 03-dra-gpu-pod.yaml"

step "Apply the ResourceClaimTemplate and GPU Pod" \
  "kubectl apply -f 03-dra-gpu-pod.yaml"

step "Wait for the DRA claim to bind and the Pod to become Ready" \
  "kubectl wait --for=condition=Ready pod/dra-gpu-pod --timeout=180s"

step "Inspect the bound ResourceClaim and Pod placement" \
  "kubectl get resourceclaims && kubectl get pod dra-gpu-pod -o wide"

step "Query the allocated GPU model, VRAM, and driver inside the Pod" \
  "kubectl exec dra-gpu-pod -- nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv"

step "Delete the Pod & ResourceClaimTemplate to return the GPU to the pool immediately" \
  "kubectl delete -f 03-dra-gpu-pod.yaml --ignore-not-found"
