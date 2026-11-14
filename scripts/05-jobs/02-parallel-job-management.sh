#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "05.2 — Indexed Parallel Parameter Sweep (Slurm Job-Array Equivalent)" 6

step "Inspect the Indexed Job manifest (completions: 6, parallelism: 3, JOB_COMPLETION_INDEX)" \
  "cat 02-parallel-job.yaml"

step "Submit the 6-task parallel parameter sweep" \
  "kubectl delete job parallel-sweep-job --ignore-not-found && kubectl apply -f 02-parallel-job.yaml"

step "Wait for all 6 indexed ranks (0..5) to complete" \
  "kubectl wait --for=condition=Complete job/parallel-sweep-job --timeout=120s"

step "List the 6 completed rank Pods" \
  "kubectl get pods -l job-name=parallel-sweep-job"

step "Aggregate parameter sweep results across all 6 ranks" \
  'for pod in $(kubectl get pods -l job-name=parallel-sweep-job -o name | sort); do kubectl logs "$pod"; done'

step "Clean up the completed sweep Job" \
  "kubectl delete job parallel-sweep-job --ignore-not-found"
