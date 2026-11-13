#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

echo "=== Available StorageClasses on Berkelium ==="
echo "  - ceph-rbd (ReadWriteOnce): High small-file IOPS for code, uv/conda, Git, SQLite/DuckDB"
echo "  - cephfs   (ReadWriteMany): Shared POSIX filesystem for multi-pod datasets & checkpoints"
echo ""
kubectl get storageclass

echo ""
echo "=== Existing PersistentVolumeClaims in Namespace ==="
kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes,STORAGECLASS:.spec.storageClassName
