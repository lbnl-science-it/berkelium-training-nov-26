#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Create 2-replica HTTP Deployment (note mandatory requests & limits on initContainer + container)
kubectl apply -f 01-http-deployment.yaml

# Wait for Deployment to become Available
kubectl wait --for=condition=Available deployment/test-http --timeout=120s

# Check Deployment & Pod replicas across worker nodes
kubectl get deployment test-http
kubectl get pods -l k8s-app=test-http -o wide

# Scale Deployment up to 3 replicas, then back to 2
kubectl scale deployment test-http --replicas=3
kubectl rollout status deployment/test-http --timeout=90s
kubectl get pods -l k8s-app=test-http -o wide

kubectl scale deployment test-http --replicas=2
kubectl rollout status deployment/test-http --timeout=90s
