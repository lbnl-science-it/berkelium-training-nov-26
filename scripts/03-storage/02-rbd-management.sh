#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create Ceph RBD block PVC (ReadWriteOnce - ideal for code, uv/conda, databases)
kubectl apply -f 01-rbd-pvc.yaml

# Wait for PVC to bind
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/rbd-pvc --timeout=60s
kubectl get pvc rbd-pvc

# Mount RBD PVC into pod
kubectl apply -f 02-rbd-pod.yaml
kubectl wait --for=condition=Ready pod/rbd-pod --timeout=90s

# Write & verify persistent data on /workspace
kubectl exec rbd-pod -- sh -c "echo 'Saved on ceph-rbd block volume' > /workspace/rbd-test.txt && ls -lh /workspace && cat /workspace/rbd-test.txt"

# Clean up pod and PVC
kubectl delete pod rbd-pod --ignore-not-found
kubectl delete pvc rbd-pvc --ignore-not-found
