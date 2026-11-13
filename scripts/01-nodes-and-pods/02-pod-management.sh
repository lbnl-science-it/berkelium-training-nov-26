#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create single-container interactive pod (auto-capped at 6h on Berkelium)
kubectl apply -f 02-pod1.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/test-pod --timeout=90s

# Check pod status and IPv6 pod address
kubectl get pod test-pod -o wide

# View pod logs
kubectl logs test-pod

# Run a command inside the pod non-interactively
kubectl exec test-pod -- sh -c "echo \"Hostname: \$(hostname) | Pod IPv6: \$(hostname -i)\""

# Interactive shell tip:
# kubectl exec -it test-pod -- /bin/bash

# Clean up pod when finished
kubectl delete pod test-pod --ignore-not-found
