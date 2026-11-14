#!/usr/bin/env python3
"""Static audit for common Berkelium manifest mistakes."""

import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "03-bad-manifest.yaml"
with open(path, "r", encoding="utf-8") as f:
    raw_lines = f.readlines()

# Strip YAML comment lines / inline comments so header instructions don't trigger false positives/negatives
text = "\n".join(re.sub(r"(^|\s)#.*$", "", line) for line in raw_lines)

violations = []
if re.search(r"storageClassName:\s*(?!cephfs\b|ceph-rbd\b)\S+", text):
    violations.append("[storage-class] Use 'storageClassName: ceph-rbd' (RWO) or 'cephfs' (RWX).")
if "limits:" not in text or "memory:" not in text:
    violations.append("[mandatory-requests-and-limits] Specify cpu & memory in BOTH requests and limits.")
if re.search(r"\b(sleep\s+infinity|tail\s+-f\s+/dev/null)\b", text):
    violations.append("[no-sleep-infinity] Batch Jobs must execute active work and exit 0 (never 'sleep infinity').")
if "hostPath:" in text:
    violations.append("[no-hostpath] hostPath volumes are forbidden; use 'emptyDir: {}' for NVMe scratch or Ceph PVCs.")

print(f"Audited {path}: {len(violations)} policy violation(s) caught:")
for v in violations:
    print(f"  - {v}")
print("\nTip: Connect Claude Code, Cursor, or OpenCode to https://berkelium.scs.lbl.gov/mcp")
print("     to validate manifests automatically with the 'validate_manifest' MCP tool!")
