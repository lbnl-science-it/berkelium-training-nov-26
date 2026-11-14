#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "03.3 — CephFS ReadWriteMany Shared POSIX Volume (Datasets & Checkpoints)" 6

step "Inspect the cephfs PVC and Pod manifests" \
  "cat 03-cephfs-pvc.yaml && echo '---' && cat 04-cephfs-pod.yaml"

step "Create the 2Gi ReadWriteMany CephFS PersistentVolumeClaim" \
  "kubectl apply -f 03-cephfs-pvc.yaml"

step "Wait for the CephFS PVC to bind" \
  "kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/cephfs-pvc --timeout=60s && kubectl get pvc cephfs-pvc"

step "Mount the CephFS volume at /shared-data inside a Pod" \
  "kubectl apply -f 04-cephfs-pod.yaml && kubectl wait --for=condition=Ready pod/cephfs-pod --timeout=90s"

step "Write and verify a shared dataset shard (never install conda/pip directly on cephfs!)" \
  'kubectl exec cephfs-pod -- sh -c '\''echo "Shared dataset shard from $(hostname)" > /shared-data/shard-0.txt && ls -lh /shared-data && cat /shared-data/shard-0.txt'\'''

step "Clean up the Pod and CephFS PVC" \
  "kubectl delete pod cephfs-pod --ignore-not-found && kubectl delete pvc cephfs-pvc --ignore-not-found"
