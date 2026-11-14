#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "02.4 — On-Demand Hardware-Isolated Dynamic MIG Slice" 5

step "Inspect the Dynamic MIG ResourceClaimTemplate (CEL profile selector) + Job" \
  "cat 04-dynamic-mig-job.yaml"

step "Submit the Dynamic MIG Job (carves 1 slice out of 7 on a shared GPU)" \
  "kubectl delete -f 04-dynamic-mig-job.yaml --ignore-not-found && kubectl apply -f 04-dynamic-mig-job.yaml"

step "Wait for DRA to carve the MIG slice and complete the Job" \
  "kubectl wait --for=condition=complete job/dynamic-mig-job --timeout=180s"

step "Inspect nvidia-smi output showing the isolated MIG instance" \
  "kubectl logs job/dynamic-mig-job"

step "Clean up (DRA tears down the MIG partition automatically upon release)" \
  "kubectl delete -f 04-dynamic-mig-job.yaml --ignore-not-found"
