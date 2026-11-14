#!/bin/bash
# Personalize all training YAML manifests & scripts with a unique per-user suffix
# so 20+ attendees can work simultaneously in the shared 'training-nov-26' namespace
# without colliding on Pod, Job, PVC, Service, or HTTPRoute names.
#
# Usage:
#   ./setup.sh              # Auto-detect Coder username or prompt interactively
#   ./setup.sh alice        # Explicitly stamp '-alice' onto all resource names
#   ./setup.sh --status     # Show current user suffix and KUBECONFIG status
#   ./setup.sh --reset      # Restore base un-suffixed names (for git commits)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$REPO_ROOT/.training-user"

sanitize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/@.*$//; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-16 \
    | sed -E 's/-+$//'
}

current_suffix=""
if [ -f "$STATE_FILE" ]; then
  current_suffix="$(tr -d '[:space:]' < "$STATE_FILE")"
fi

apply_transform() {
  local old_sfx="$1"
  local new_sfx="$2"

  python3 - "$REPO_ROOT" "$old_sfx" "$new_sfx" <<'PYEOF'
import os
import re
import sys

repo_root, old_sfx, new_sfx = sys.argv[1], sys.argv[2], sys.argv[3]

# Ordered longest-first where prefixes overlap (e.g. test-http-route before test-http).
BASE_NAMES = [
    "multi-container-pod",
    "parallel-sweep-job",
    "broken-hostpath-pod",
    "training-gpu-claim",
    "nvme-scratch-pod",
    "dynamic-mig-job",
    "gpu-pytorch-job",
    "mig-slice-claim",
    "test-http-route",
    "nvidia-smi-job",
    "training-demo",
    "test-curl-pod",
    "dra-gpu-pod",
    "failing-pod",
    "broken-pvc",
    "cephfs-pod",
    "cephfs-pvc",
    "debug-pod",
    "test-http",
    "test-pod",
    "test-svc",
    "cpu-job",
    "rbd-pod",
    "rbd-pvc",
]

target_files = []
scripts_dir = os.path.join(repo_root, "scripts")
for root, _, files in os.walk(scripts_dir):
    for fn in sorted(files):
        if fn == "_common.sh":
            continue
        if fn.endswith((".yaml", ".sh")):
            target_files.append(os.path.join(root, fn))

patterns = []
for base in BASE_NAMES:
    src = f"{base}-{old_sfx}" if old_sfx else base
    dst = f"{base}-{new_sfx}" if new_sfx else base
    if base == "training-demo":
        # Match hostname prefix before .bk.lbl.gov
        pat = re.compile(rf"(?<![a-z0-9-]){re.escape(src)}(?=\.bk\.lbl\.gov\b)")
    else:
        # Match Kubernetes resource/label identifier, never filenames like 01-cpu-job.yaml
        pat = re.compile(rf"(?<![a-z0-9-]){re.escape(src)}(?![a-z0-9.-])")
    patterns.append((pat, dst))

changed_count = 0
for path in target_files:
    with open(path, "r", encoding="utf-8") as f:
        orig = f.read()
    updated = orig
    for pat, dst in patterns:
        updated = pat.sub(dst, updated)
    if updated != orig:
        with open(path, "w", encoding="utf-8") as f:
            f.write(updated)
        changed_count += 1

action = f"'-{new_sfx}'" if new_sfx else "base template names"
print(f"Updated {changed_count} manifest/script file(s) -> {action}.")
PYEOF
}

case "${1:-}" in
  --status)
    if [ -n "$current_suffix" ]; then
      echo "Active attendee suffix : -$current_suffix (stored in .training-user)"
    else
      echo "Active attendee suffix : (not configured yet — run ./setup.sh)"
    fi
    if [ -n "${KUBECONFIG:-}" ]; then
      echo "KUBECONFIG             : $KUBECONFIG"
    elif [ -f "$REPO_ROOT/kubeconfig.yaml" ]; then
      echo "KUBECONFIG             : $REPO_ROOT/kubeconfig.yaml (auto-detected by scripts)"
    else
      echo "KUBECONFIG             : using default ~/.kube/config"
    fi
    exit 0
    ;;
  --reset)
    if [ -z "$current_suffix" ]; then
      echo "Already at base template names (nothing to reset)."
      exit 0
    fi
    apply_transform "$current_suffix" ""
    rm -f "$STATE_FILE"
    echo "Reset complete."
    exit 0
    ;;
  -h|--help)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

# Determine target suffix
target_raw="${1:-}"
if [ -z "$target_raw" ]; then
  if [ -n "$current_suffix" ]; then
    default_guess="$current_suffix"
  elif [ -n "${CODER_WORKSPACE_OWNER_NAME:-}" ]; then
    default_guess="$CODER_WORKSPACE_OWNER_NAME"
  elif [ -n "${CODER_USERNAME:-}" ]; then
    default_guess="$CODER_USERNAME"
  elif [ -n "${USER:-}" ] && [ "$USER" != "coder" ] && [ "$USER" != "root" ] && [ "$USER" != "ubuntu" ]; then
    default_guess="$USER"
  else
    default_guess=""
  fi
  default_guess="$(sanitize_name "$default_guess")"

  echo "=== Berkelium Workshop Setup (Shared Namespace: training-nov-26) ==="
  echo "To avoid resource name collisions with other attendees, enter your"
  echo "LBNL username or initials (lowercase letters/numbers, e.g. 'alice'):"
  if [ -t 0 ]; then
    if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
      read -e -r -p "Your name/initials: " -i "$default_guess" target_raw </dev/tty
    elif [ -x /bin/zsh ] && [ -n "$default_guess" ]; then
      target_raw="$(DEFAULT_VAL="$default_guess" /bin/zsh -f -c 'zmodload zsh/zle; val="$DEFAULT_VAL"; vared -p "Your name/initials: " val && printf "%s" "$val"' </dev/tty)"
    else
      if [ -n "$default_guess" ]; then
        printf "Your name/initials [%s]: " "$default_guess"
        read -r target_raw </dev/tty
        target_raw="${target_raw:-$default_guess}"
      else
        printf "Your name/initials: "
        read -r target_raw </dev/tty
      fi
    fi
  else
    target_raw="${default_guess:-user$$}"
  fi
fi

target_suffix="$(sanitize_name "$target_raw")"
if [ -z "$target_suffix" ]; then
  echo "Error: Please provide at least one letter or digit (e.g., ./setup.sh alice)." >&2
  exit 1
fi

if [ "$target_suffix" = "$current_suffix" ]; then
  echo "Already configured for attendee suffix '-$target_suffix'."
else
  apply_transform "$current_suffix" "$target_suffix"
  printf '%s\n' "$target_suffix" > "$STATE_FILE"
  echo "Personalized all manifests & scripts with suffix '-$target_suffix' (e.g., pod/test-pod-$target_suffix)."
fi

if [ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ]; then
  export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml"
  echo ""
  echo "Tip: For manual kubectl commands in your shell, run:"
  echo "  export KUBECONFIG=\"$REPO_ROOT/kubeconfig.yaml\""
fi

if command -v kubectl >/dev/null 2>&1 && { [ -n "${KUBECONFIG:-}" ] || [ -f "$HOME/.kube/config" ]; }; then
  echo ""
  echo "Verifying Berkelium cluster access..."
  kubectl auth whoami 2>/dev/null || echo "(Warning: could not reach cluster yet — check kubeconfig.yaml or VPN/Coder terminal)"
fi
