#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Launch pod with ephemeral node-local NVMe scratch (emptyDir)
kubectl apply -f 05-nvme-scratch-pod.yaml
kubectl wait --for=condition=Ready pod/nvme-scratch-pod --timeout=90s

# View write throughput to local NVMe scratch (wiped automatically when pod exits!)
sleep 2
kubectl logs nvme-scratch-pod

# Clean up pod
kubectl delete pod nvme-scratch-pod --ignore-not-found
