#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Clean up any prior run
kubectl delete -f 04-dynamic-mig-job.yaml --ignore-not-found

# Provision an on-demand Dynamic MIG partition (up to 7 slices per physical GPU!)
kubectl apply -f 04-dynamic-mig-job.yaml

# Wait for DRA to carve the MIG instance and complete the job
kubectl wait --for=condition=complete job/dynamic-mig-job --timeout=180s

# Inspect the allocated MIG slice inside nvidia-smi
kubectl logs job/dynamic-mig-job

# Clean up (DRA automatically tears down the MIG partition when the claim is released)
kubectl delete -f 04-dynamic-mig-job.yaml --ignore-not-found
