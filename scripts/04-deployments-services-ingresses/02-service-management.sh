#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "04.2 — IPv6 ClusterIP Service & In-Cluster Load Balancing" 5

step "Inspect the ClusterIP Service manifest" \
  "cat 03-service.yaml"

step "Ensure backing Deployment & Service are applied" \
  "kubectl apply -f 01-http-deployment.yaml -f 03-service.yaml && kubectl wait --for=condition=Available deployment/test-http --timeout=120s"

step "Inspect the allocated IPv6 ClusterIP Service address" \
  "kubectl get service test-svc"

step "Launch a lightweight curl client Pod" \
  "kubectl apply -f 02-curl-pod.yaml && kubectl wait --for=condition=Ready pod/test-curl-pod --timeout=90s"

step "Send 4 HTTP requests to http://test-svc to observe round-robin load balancing" \
  "for i in 1 2 3 4; do kubectl exec test-curl-pod -- curl -sS http://test-svc; done"
