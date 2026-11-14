#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "02.2 — GPU Batch Job via Classic Extended Resources" 5

step "Inspect the GPU Job manifest (nvidia.com/h200 extended resource)" \
  "cat 02-nvidia-smi-job.yaml"

step "Submit the GPU batch Job" \
  "kubectl delete job nvidia-smi-job --ignore-not-found && kubectl apply -f 02-nvidia-smi-job.yaml"

step "Wait for the GPU Job to run to completion" \
  "kubectl wait --for=condition=complete job/nvidia-smi-job --timeout=180s"

step "View nvidia-smi output from the scheduled GPU node" \
  "kubectl logs job/nvidia-smi-job"

step "Delete the completed Job" \
  "kubectl delete job nvidia-smi-job --ignore-not-found"
