#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Ensure backing HTTP Deployment is running
kubectl apply -f 01-http-deployment.yaml
kubectl wait --for=condition=Available deployment/test-http --timeout=120s

# Create ClusterIP Service (allocates an IPv6 service address on Berkelium)
kubectl apply -f 03-service.yaml
kubectl get service test-svc

# Launch curl client pod to test in-cluster load balancing
kubectl apply -f 02-curl-pod.yaml
kubectl wait --for=condition=Ready pod/test-curl-pod --timeout=90s

echo "=== Sending 4 requests to http://test-svc (observe load balancing across replicas) ==="
for i in 1 2 3 4; do
  kubectl exec test-curl-pod -- curl -sS http://test-svc
done
