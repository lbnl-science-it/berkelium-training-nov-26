#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

kubectl delete job cpu-job --ignore-not-found

# Submit unattended CPU batch Job
kubectl apply -f 01-cpu-job.yaml

# Wait for completion
kubectl wait --for=condition=Complete job/cpu-job --timeout=90s

# Check Job status and output logs
kubectl get job cpu-job
kubectl get pods -l job-name=cpu-job
kubectl logs job/cpu-job

# Clean up
kubectl delete job cpu-job --ignore-not-found
