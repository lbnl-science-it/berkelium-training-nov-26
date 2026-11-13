#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

kubectl delete job parallel-sweep-job --ignore-not-found

# Submit Indexed Parallel Parameter Sweep (6 tasks, 3 concurrent workers)
kubectl apply -f 02-parallel-job.yaml

# Wait for all 6 indexed completions
kubectl wait --for=condition=Complete job/parallel-sweep-job --timeout=120s

kubectl get job parallel-sweep-job
kubectl get pods -l job-name=parallel-sweep-job

echo "=== Aggregated Parameter Sweep Results Across All Ranks ==="
for pod in $(kubectl get pods -l job-name=parallel-sweep-job -o name | sort); do
  kubectl logs "$pod"
done

# Clean up
kubectl delete job parallel-sweep-job --ignore-not-found
