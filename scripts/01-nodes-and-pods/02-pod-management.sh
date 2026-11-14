#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "01.2 — Single-Container Interactive Pod Lifecycle" 7

step "Inspect the Pod manifest (note mandatory CPU & memory requests/limits)" \
  "cat 02-pod1.yaml"

step "Create the interactive Pod (standalone Pods auto-terminate at 6h on Berkelium)" \
  "kubectl apply -f 02-pod1.yaml"

step "Wait for the Pod to become Ready" \
  "kubectl wait --for=condition=Ready pod/test-pod --timeout=90s"

step "Check Pod placement and allocated IPv6 Pod address" \
  "kubectl get pod test-pod -o wide"

step "View container startup logs" \
  "kubectl logs test-pod"

step "Execute a command inside the running Pod (or edit to: kubectl exec -it test-pod -- /bin/bash)" \
  'kubectl exec test-pod -- sh -c '\''echo "Hostname: $(hostname) | Pod IPv6: $(hostname -i)"'\'''

step "Delete the Pod when finished" \
  "kubectl delete pod test-pod --ignore-not-found"
