#!/bin/bash
set -e
cd "$(dirname "$0")"
REPO_ROOT="$(cd ../.. && pwd)"
[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

echo "=== 1. Server-Side Gatekeeper Admission Dry-Run on 03-bad-manifest.yaml ==="
echo "(Expecting Gatekeeper to DENY the forbidden hostPath volume!)"
if kubectl apply --dry-run=server -f 03-bad-manifest.yaml 2>&1; then
  echo "Unexpectedly passed dry-run"
else
  echo "--> Gatekeeper blocked the unsafe hostPath manifest before scheduling!"
fi

echo ""
echo "=== 2. Berkelium Policy Audit (Requests/Limits, No sleep infinity, StorageClass) ==="
python3 - 03-bad-manifest.yaml <<'PYEOF'
import re, sys

path = sys.argv[1]
text = open(path).read()
violations = []

if re.search(r"storageClassName:\s*(?!cephfs\b|ceph-rbd\b)\S+", text):
    violations.append("[storage-class] Use 'storageClassName: ceph-rbd' (RWO) or 'cephfs' (RWX).")
if "limits:" not in text or "memory:" not in text:
    violations.append("[mandatory-requests-and-limits] Every container must specify cpu & memory in BOTH requests and limits.")
if re.search(r"\b(sleep\s+infinity|tail\s+-f\s+/dev/null)\b", text):
    violations.append("[no-sleep-infinity] Batch Jobs must execute active work and exit 0 (never 'sleep infinity').")
if "hostPath:" in text:
    violations.append("[no-hostpath] hostPath volumes are forbidden; use 'emptyDir: {}' for NVMe scratch or Ceph PVCs.")

print(f"Audited {path}: {len(violations)} policy violation(s) caught:")
for v in violations:
    print(f"  - {v}")
print("\nTip: Connect Claude Code, Cursor, or OpenCode to https://berkelium.scs.lbl.gov/mcp")
print("     to validate manifests automatically with the 'validate_manifest' MCP tool!")
PYEOF
