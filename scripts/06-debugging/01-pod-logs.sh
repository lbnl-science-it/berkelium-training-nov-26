#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "06.1 — Diagnose a Failing Pod (Status, Events & Timestamped Logs)" 6

step "Inspect the intentionally failing Pod manifest" \
  "cat 01-failing-pod.yaml"

step "Submit the failing Pod" \
  "kubectl delete pod failing-pod --ignore-not-found && kubectl apply -f 01-failing-pod.yaml"

step "Wait ~3s for the Pod to run and exit with non-zero error" \
  "kubectl wait --for=jsonpath='{.status.phase}'=Failed pod/failing-pod --timeout=30s"

step "Inspect Error status, exit code, and Pod events" \
  "kubectl get pod failing-pod && kubectl describe pod failing-pod | tail -n 20"

step "View container stderr/stdout logs with timestamps (--previous shows prior crash if restarted)" \
  "kubectl logs failing-pod --timestamps"

step "Clean up the failed Pod" \
  "kubectl delete pod failing-pod --ignore-not-found"
