#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "04.3 — Expose HTTPS Web Service via Gateway API HTTPRoute" 4

step "Inspect the Gateway API HTTPRoute manifest (attaches to gateway/ingress)" \
  "cat 04-httproute.yaml"

step "Apply Deployment, Service, and HTTPRoute" \
  "kubectl apply -f 01-http-deployment.yaml -f 03-service.yaml -f 04-httproute.yaml && kubectl wait --for=condition=Available deployment/test-http --timeout=120s"

step "Verify Envoy Gateway accepted and programmed the HTTPRoute" \
  "sleep 3 && kubectl get httproute test-http-route && kubectl describe httproute test-http-route | tail -n 25"

step "Clean up all Module 04 resources" \
  "kubectl delete httproute test-http-route --ignore-not-found && kubectl delete pod test-curl-pod --ignore-not-found && kubectl delete service test-svc --ignore-not-found && kubectl delete deployment test-http --ignore-not-found"
