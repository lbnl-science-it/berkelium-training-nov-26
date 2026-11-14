#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "03.1 — Discover Ceph StorageClasses & Namespace PVCs" 2

step "List StorageClasses (ceph-rbd for RWO small-file IOPS vs cephfs for RWX shared datasets)" \
  "kubectl get storageclass"

step "List PersistentVolumeClaims currently in the shared namespace" \
  "kubectl get pvc -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes,STORAGECLASS:.spec.storageClassName"
