#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create debug pod
kubectl apply -f 02-debug-pod.yaml
kubectl wait --for=condition=Ready pod/debug-pod --timeout=90s

echo "=== 1. Inspect Processes, Disk & Environment via kubectl exec ==="
kubectl exec debug-pod -- ps aux
kubectl exec debug-pod -- df -h
kubectl exec debug-pod -- sh -c "echo 'Current UTC time:' && date -u && uname -r"

echo ""
echo "=== 2. Pod Events & Live Metrics (metrics.k8s.io) ==="
kubectl get events --field-selector involvedObject.name=debug-pod
kubectl top nodes | head -n 10
kubectl top pods || echo "(Pod metrics populate ~30-60s after container start)"

# Copy files to/from a running pod:
# kubectl cp ./local-script.py debug-pod:/tmp/local-script.py
# kubectl cp debug-pod:/tmp/local-script.py ./downloaded-script.py

kubectl delete pod debug-pod --ignore-not-found
