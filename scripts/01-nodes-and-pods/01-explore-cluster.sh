#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

echo "=== Current Kubernetes Identity & Context ==="
kubectl auth whoami

echo ""
echo "=== Berkelium Cluster Nodes (Talos Linux + IPv6) ==="
kubectl get nodes -o wide

echo ""
echo "=== Namespace Default Resource LimitRange ==="
kubectl describe limitrange default-limits

echo ""
echo "=== Active Workloads in Current Namespace ==="
kubectl get pods,deployments,services

echo ""
echo "=== Recent Namespace Events ==="
kubectl get events --sort-by=.metadata.creationTimestamp | tail -n 15
