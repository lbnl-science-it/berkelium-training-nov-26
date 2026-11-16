#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "05.3 — PyTorch 2.14 + CUDA 13.0 GPU BF16 Benchmark Job" 5

step "Inspect the PyTorch GPU benchmark Job manifest" \
  "cat 03-gpu-pytorch-job.yaml"

step "Submit the PyTorch GPU batch Job (exits 0 automatically, releasing the GPU)" \
  "kubectl delete -f 03-gpu-pytorch-job.yaml --ignore-not-found && kubectl apply -f 03-gpu-pytorch-job.yaml"

step "Wait for the GPU benchmark Job to complete" \
  "kubectl wait --for=condition=Complete job/gpu-pytorch-job --timeout=180s"

step "Check GPU node placement and BF16 TFLOPS output" \
  "kubectl get pods -l job-name=gpu-pytorch-job -o wide && kubectl logs job/gpu-pytorch-job"

step "Clean up the completed GPU Job" \
  "kubectl delete -f 03-gpu-pytorch-job.yaml --ignore-not-found"
