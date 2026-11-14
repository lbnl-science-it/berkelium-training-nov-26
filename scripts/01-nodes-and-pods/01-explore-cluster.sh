#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "01.1 — Explore Berkelium Cluster, Nodes & LimitRange" 5

step "Check your current Kubernetes identity & namespace context" \
  "kubectl auth whoami"

step "List Berkelium Talos Linux nodes & IPv6 internal addresses" \
  "kubectl get nodes -o wide"

step "Inspect the namespace LimitRange (default CPU & memory requests/limits)" \
  "kubectl describe limitrange default-limits"

step "List active pods, deployments, and services in the shared namespace" \
  "kubectl get pods,deployments,services"

step "Inspect the most recent events in this namespace" \
  "kubectl get events --sort-by=.metadata.creationTimestamp | tail -n 15"
