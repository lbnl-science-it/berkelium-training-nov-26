#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Ensure Deployment & Service exist
kubectl apply -f 01-http-deployment.yaml
kubectl apply -f 03-service.yaml
kubectl wait --for=condition=Available deployment/test-http --timeout=120s

# Attach Gateway API HTTPRoute to Berkelium's central Envoy Gateway (gateway/ingress)
# Note: Berkelium uses Kubernetes Gateway API (HTTPRoute), not legacy Ingress objects.
kubectl apply -f 04-httproute.yaml

# Wait briefly for Envoy Gateway to accept and program the route
sleep 3
kubectl get httproute test-http-route
kubectl describe httproute test-http-route

# Clean up Module 04 resources
kubectl delete httproute test-http-route --ignore-not-found
kubectl delete pod test-curl-pod --ignore-not-found
kubectl delete service test-svc --ignore-not-found
kubectl delete deployment test-http --ignore-not-found
