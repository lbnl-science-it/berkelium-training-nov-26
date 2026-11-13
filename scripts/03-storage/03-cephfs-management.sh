#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create CephFS shared POSIX PVC (ReadWriteMany - mountable across multiple pods/nodes!)
kubectl apply -f 03-cephfs-pvc.yaml

# Wait for PVC to bind
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/cephfs-pvc --timeout=60s
kubectl get pvc cephfs-pvc

# Mount CephFS PVC into pod
kubectl apply -f 04-cephfs-pod.yaml
kubectl wait --for=condition=Ready pod/cephfs-pod --timeout=90s

# Write & verify shared file (remember: never install conda/uv directly on cephfs!)
kubectl exec cephfs-pod -- sh -c 'echo "Shared dataset shard from $(hostname)" > /shared-data/shard-0.txt && ls -lh /shared-data && cat /shared-data/shard-0.txt'

# Clean up pod and PVC
kubectl delete pod cephfs-pod --ignore-not-found
kubectl delete pvc cephfs-pvc --ignore-not-found
