#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "01.3 — Multi-Container Pod (Web Server + Sidecar)" 8

step "Inspect the multi-container Pod manifest (nginx + busybox sidecar)" \
  "cat 03-multi-container-pod.yaml"

step "Create the multi-container Pod (containers share localhost & IPv6 network namespace)" \
  "kubectl apply -f 03-multi-container-pod.yaml"

step "Wait for both containers in the Pod to become Ready" \
  "kubectl wait --for=condition=Ready pod/multi-container-pod --timeout=90s"

step "Check Pod status (READY 2/2) and node placement" \
  "kubectl get pod multi-container-pod -o wide"

step "View logs from the 'web-server' container (-c web-server)" \
  "kubectl logs multi-container-pod -c web-server | tail -n 10"

step "View health-check logs from the 'sidecar' container (-c sidecar)" \
  "kubectl logs multi-container-pod -c sidecar"

step "Run a command inside a specific container (-c web-server)" \
  "kubectl exec multi-container-pod -c web-server -- nginx -v"

step "Clean up the multi-container Pod" \
  "kubectl delete pod multi-container-pod --ignore-not-found"
