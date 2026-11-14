#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "06.2 — Live Inspection (kubectl exec, Events & kubectl top)" 6

step "Launch the debug Pod and wait until Ready" \
  "kubectl apply -f 02-debug-pod.yaml && kubectl wait --for=condition=Ready pod/debug-pod --timeout=90s"

step "Inspect running processes inside the container" \
  "kubectl exec debug-pod -- ps aux"

step "Inspect filesystem mounts, UTC clock, and Talos kernel version" \
  'kubectl exec debug-pod -- sh -c '\''df -h && echo "UTC: $(date -u) | Kernel: $(uname -r)"'\'''

step "Filter namespace events specifically for this Pod" \
  "kubectl get events --field-selector involvedObject.name=debug-pod"

step "Check live cluster node & Pod resource utilization (metrics-server)" \
  'kubectl top nodes | head -n 10 && (kubectl top pods || echo "(Pod metrics populate ~30-60s after start)")'

step "Clean up the debug Pod" \
  "kubectl delete pod debug-pod --ignore-not-found"
