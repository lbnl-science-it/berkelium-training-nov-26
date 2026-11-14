#!/bin/bash
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

echo "Cleaning up training workloads in current namespace ($(kubectl config view --minify -o jsonpath='{..namespace}'))..."
kubectl delete httproute test-http-route --ignore-not-found
kubectl delete deployment test-http --ignore-not-found
kubectl delete service test-svc --ignore-not-found
kubectl delete job nvidia-smi-job dynamic-mig-job cpu-job parallel-sweep-job gpu-pytorch-job boss-job --ignore-not-found
kubectl delete pod test-pod multi-container-pod dra-gpu-pod rbd-pod cephfs-pod nvme-scratch-pod test-curl-pod failing-pod debug-pod quest1-pod quest3-pod --ignore-not-found
kubectl delete resourceclaimtemplate training-gpu-claim mig-slice-claim --ignore-not-found
kubectl delete pvc rbd-pvc cephfs-pvc quest3-pvc boss-pvc --ignore-not-found
echo "Cleanup complete!"
