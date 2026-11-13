#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Clean up any previous completed run
kubectl delete job nvidia-smi-job --ignore-not-found

# Submit GPU batch job using Extended Resources (nvidia.com/a40)
kubectl apply -f 02-nvidia-smi-job.yaml

# Wait for the job to complete
kubectl wait --for=condition=complete job/nvidia-smi-job --timeout=180s

# View nvidia-smi output from the GPU node
kubectl logs job/nvidia-smi-job

# Clean up the job to release metadata
kubectl delete job nvidia-smi-job --ignore-not-found
