#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create multi-container pod (nginx + busybox sidecar sharing network namespace)
kubectl apply -f 03-multi-container-pod.yaml

# Wait for both containers in the pod to become Ready
kubectl wait --for=condition=Ready pod/multi-container-pod --timeout=90s

# Check pod status and shared IPv6 address
kubectl get pod multi-container-pod -o wide

# Inspect logs from each container using -c
echo "=== Web-server container logs ==="
kubectl logs multi-container-pod -c web-server | tail -n 10

echo "=== Sidecar container logs ==="
kubectl logs multi-container-pod -c sidecar

# Run a command in a specific container
kubectl exec multi-container-pod -c web-server -- nginx -v

# Interactive shell tips:
# kubectl exec -it multi-container-pod -c web-server -- /bin/sh
# kubectl exec -it multi-container-pod -c sidecar -- /bin/sh

# Clean up pod when finished
kubectl delete pod multi-container-pod --ignore-not-found
