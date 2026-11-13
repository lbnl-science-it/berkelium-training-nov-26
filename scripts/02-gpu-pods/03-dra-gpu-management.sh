#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create ResourceClaimTemplate + GPU Pod using Kubernetes Dynamic Resource Allocation (DRA)
kubectl apply -f 03-dra-gpu-pod.yaml

# Wait for the DRA claim to bind and the pod to become Ready
kubectl wait --for=condition=Ready pod/dra-gpu-pod --timeout=180s

# Inspect the dynamically created ResourceClaim and pod placement
kubectl get resourceclaims
kubectl get pod dra-gpu-pod -o wide

# View startup logs (GPU UUID + /dev/shm RAM disk) and run nvidia-smi
kubectl logs dra-gpu-pod
kubectl exec dra-gpu-pod -- nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv

# Clean up the pod and template so the GPU returns to the pool immediately
kubectl delete -f 03-dra-gpu-pod.yaml --ignore-not-found
