#!/bin/bash
source "$(dirname "$0")/../_common.sh" "$@"

init_exercise "06.3 — Gatekeeper Dry-Run & Berkelium Policy Audit" 3

step "Inspect the intentionally non-compliant manifest (4 common mistakes)" \
  "cat 03-bad-manifest.yaml"

step_expect_fail "Run server-side admission dry-run (Gatekeeper will DENY forbidden hostPath)" \
  "kubectl apply --dry-run=server -f 03-bad-manifest.yaml"

step "Audit the manifest against Berkelium's 4 Golden Rules" \
  "python3 03-audit-manifest.py 03-bad-manifest.yaml"
