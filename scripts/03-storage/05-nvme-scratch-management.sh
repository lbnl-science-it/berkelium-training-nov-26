#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "03.4 — Ephemeral Node-Local NVMe Scratch (emptyDir)" 4

step "Inspect the Pod manifest with 5Gi emptyDir NVMe scratch (/scratch)" \
  "cat 05-nvme-scratch-pod.yaml"

step "Launch the Pod and wait until Ready" \
  "kubectl apply -f 05-nvme-scratch-pod.yaml && kubectl wait --for=condition=Ready pod/nvme-scratch-pod --timeout=90s"

step "View NVMe write throughput logs (scratch is wiped automatically when the Pod exits)" \
  "sleep 2 && kubectl logs nvme-scratch-pod"

step "Clean up the scratch Pod" \
  "kubectl delete pod nvme-scratch-pod --ignore-not-found"
