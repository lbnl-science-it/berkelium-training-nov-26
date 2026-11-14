#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "05.1 — Unattended CPU Batch Job" 5

step "Inspect the CPU Job manifest (runs active computation & exits 0 — never sleep infinity!)" \
  "cat 01-cpu-job.yaml"

step "Submit the unattended CPU batch Job" \
  "kubectl delete job cpu-job --ignore-not-found && kubectl apply -f 01-cpu-job.yaml"

step "Wait for the Job to complete" \
  "kubectl wait --for=condition=Complete job/cpu-job --timeout=90s"

step "Check Job status and worker output logs" \
  "kubectl get job cpu-job && kubectl logs job/cpu-job"

step "Clean up the completed Job" \
  "kubectl delete job cpu-job --ignore-not-found"
