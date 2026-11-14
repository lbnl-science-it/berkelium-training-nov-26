#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "03.2 — Ceph RBD ReadWriteOnce Block Volume (Code, Conda/uv, DBs)" 6

step "Inspect the ceph-rbd PVC and Pod manifests" \
  "cat 01-rbd-pvc.yaml && echo '---' && cat 02-rbd-pod.yaml"

step "Create the 2Gi ReadWriteOnce Ceph RBD PersistentVolumeClaim" \
  "kubectl apply -f 01-rbd-pvc.yaml"

step "Wait for the RBD PVC to bind" \
  "kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/rbd-pvc --timeout=60s && kubectl get pvc rbd-pvc"

step "Mount the RBD PVC at /workspace inside a Pod" \
  "kubectl apply -f 02-rbd-pod.yaml && kubectl wait --for=condition=Ready pod/rbd-pod --timeout=90s"

step "Write and verify persistent data on /workspace" \
  'kubectl exec rbd-pod -- sh -c '\''echo "Saved on ceph-rbd block volume" > /workspace/rbd-test.txt && ls -lh /workspace && cat /workspace/rbd-test.txt'\'''

step "Clean up the Pod and RBD PVC" \
  "kubectl delete pod rbd-pod --ignore-not-found && kubectl delete pvc rbd-pvc --ignore-not-found"
