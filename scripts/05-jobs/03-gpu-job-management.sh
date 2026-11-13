#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

kubectl delete job gpu-pytorch-job --ignore-not-found

# Submit unattended PyTorch GPU batch computation (exits automatically releasing GPU!)
kubectl apply -f 03-gpu-pytorch-job.yaml

# Wait for job to complete
kubectl wait --for=condition=Complete job/gpu-pytorch-job --timeout=180s

# Check status and GPU benchmark output
kubectl get job gpu-pytorch-job
kubectl get pods -l job-name=gpu-pytorch-job -o wide
kubectl logs job/gpu-pytorch-job

# Clean up
kubectl delete job gpu-pytorch-job --ignore-not-found
