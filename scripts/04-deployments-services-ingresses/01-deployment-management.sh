#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "04.1 — Resilient HTTP Deployment & Scaling" 5

step "Inspect the 2-replica HTTP Deployment manifest (initContainer + container)" \
  "cat 01-http-deployment.yaml"

step "Create the Deployment and wait for replicas to become Available" \
  "kubectl apply -f 01-http-deployment.yaml && kubectl wait --for=condition=Available deployment/test-http --timeout=120s"

step "Check Deployment status and Pod placement across worker nodes" \
  "kubectl get deployment test-http && kubectl get pods -l k8s-app=test-http -o wide"

step "Scale the Deployment up to 3 replicas and watch rollout" \
  "kubectl scale deployment test-http --replicas=3 && kubectl rollout status deployment/test-http --timeout=90s && kubectl get pods -l k8s-app=test-http -o wide"

step "Scale back down to 2 replicas (keep running for Exercise 04.2)" \
  "kubectl scale deployment test-http --replicas=2 && kubectl rollout status deployment/test-http --timeout=90s"
