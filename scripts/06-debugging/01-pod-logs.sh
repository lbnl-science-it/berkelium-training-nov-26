#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

kubectl delete pod failing-pod --ignore-not-found

# Create a pod that exits with a non-zero error code
kubectl apply -f 01-failing-pod.yaml

echo "Waiting for pod to run and fail..."
kubectl wait --for=jsonpath='{.status.phase}'=Failed pod/failing-pod --timeout=30s

# Inspect Error status and exit code
kubectl get pod failing-pod
kubectl describe pod failing-pod | tail -n 20

echo "=== Container Logs with Timestamps ==="
kubectl logs failing-pod --timestamps

# Tip: If restartPolicy is Always/OnFailure and a container crashed & restarted, inspect the prior crash with:
# kubectl logs <pod-name> --previous

kubectl delete pod failing-pod --ignore-not-found
