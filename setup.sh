#!/bin/bash
# One-command Workshop Setup for Berkelium User Training (shared namespace: training-nov-26)
#
# 1. Configures kubectl access (fetches kubeconfig via Workshop Join Code from
#    https://training-hub.bk.lbl.gov, or imports a downloaded file / pasted token,
#    and installs ~/.kube/config so plain 'kubectl' works in every terminal tab).
# 2. Personalizes all training YAML manifests & scripts with a unique '-<name>'
#    suffix so 20+ attendees never collide in 'training-nov-26'.
#
# Usage:
#   ./setup.sh                       # Interactive 2-step setup (kubeconfig + suffix)
#   ./setup.sh --code bk-7k9m        # Fetch kubeconfig with join code + prompt suffix
#   ./setup.sh --code bk-7k9m alice  # Non-interactive full setup (kubeconfig + '-alice')
#   ./setup.sh --kubeconfig          # Re-run kubeconfig setup / update token
#   ./setup.sh alice                 # Stamp '-alice' onto all resource names
#   ./setup.sh --status              # Show current suffix and kubectl config status
#   ./setup.sh --reset               # Restore base un-suffixed names (for git commits)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE="$REPO_ROOT/.training-user"
LOCAL_KC="$REPO_ROOT/kubeconfig.yaml"
HUB_URL="${TRAINING_HUB_URL:-https://training-hub.bk.lbl.gov}"
TRAINING_NS="training-nov-26"

# Public Berkelium API endpoint & public X.509 cluster CA cert (NOT a secret)
CLUSTER_SERVER="https://[2620:83:8000:157::f]:6443"
CLUSTER_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJpekNDQVRDZ0F3SUJBZ0lSQU5JNU1YaGRwSk1XckswbXUyMERxVjR3Q2dZSUtvWkl6ajBFQXdJd0ZURVQKTUJFR0ExVUVDaE1LYTNWaVpYSnVaWFJsY3pBZUZ3MHlOakEzTURFeU16TTNNelJhRncwek5qQTJNamd5TXpNMwpNelJhTUJVeEV6QVJCZ05WQkFvVENtdDFZbVZ5Ym1WMFpYTXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CCkJ3TkNBQVIybHJORkhZUkZDemtvQVZOTHRIMEZRQWJVSm4veFdJb0x6NEQ2VVRadjU0bk1ORy9pWk9wRitDY0sKWmZOd2h1NWFmWStFdkRHVWtqRXZDYUFGN053dW8yRXdYekFPQmdOVkhROEJBZjhFQkFNQ0FvUXdIUVlEVlIwbApCQll3RkFZSUt3WUJCUVVIQXdFR0NDc0dBUVVGQndNQ01BOEdBMVVkRXdFQi93UUZNQU1CQWY4d0hRWURWUjBPCkJCWUVGSjRaTEorOWd1OVpMS3NQVWU4S2hpbnNSbmdqTUFvR0NDcUdTTTQ5QkFNQ0Ewa0FNRVlDSVFEMFNQdTAKT3ZnNzJNRmpEMklzcE84TXZ3dVBPc2NwZVd3MUUyOEwyRTVCRWdJaEFLSkVqQmdVMCs2REQ2ZUZMVDJuNmlGZgo4OWE3Tm5keC9DbVpOb0M1ZmlwTwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

sanitize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/@.*$//; s/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-16 \
    | sed -E 's/-+$//'
}

write_kc_from_token() {
  local tok="$1"
  local dest="$2"
  cat > "$dest" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: berkelium
  cluster:
    certificate-authority-data: ${CLUSTER_CA_B64}
    server: ${CLUSTER_SERVER}
contexts:
- name: training@berkelium
  context:
    cluster: berkelium
    namespace: ${TRAINING_NS}
    user: training-user
current-context: training@berkelium
users:
- name: training-user
  user:
    token: ${tok}
EOF
  chmod 600 "$dest"
}

install_home_kubeconfig() {
  local src_kc="$1"
  local home_kube_dir="$HOME/.kube"
  local home_kc="$home_kube_dir/config"

  mkdir -p "$home_kube_dir"
  chmod 700 "$home_kube_dir"

  if [ ! -f "$home_kc" ]; then
    cp "$src_kc" "$home_kc"
    chmod 600 "$home_kc"
    echo "Installed ~/.kube/config -> 'kubectl' now works in every terminal tab!"
    return 0
  fi

  if cmp -s "$src_kc" "$home_kc"; then
    return 0
  fi

  if [ -t 0 ]; then
    local ans=""
    printf "Also set ~/.kube/config to Berkelium '%s' (backs up current file to ~/.kube/config.pre-berkelium.bak)? [Y/n]: " "$TRAINING_NS"
    read -r ans </dev/tty || true
    case "$ans" in
      [nN]*)
        echo "Kept existing ~/.kube/config unchanged. Run in new shells:"
        echo "  export KUBECONFIG=\"$src_kc\""
        ;;
      *)
        if [ ! -f "$home_kc.pre-berkelium.bak" ]; then
          cp "$home_kc" "$home_kc.pre-berkelium.bak"
          chmod 600 "$home_kc.pre-berkelium.bak"
        fi
        cp "$src_kc" "$home_kc"
        chmod 600 "$home_kc"
        echo "Updated ~/.kube/config (backup saved at ~/.kube/config.pre-berkelium.bak)."
        ;;
    esac
  fi
}

fetch_or_import_kubeconfig() {
  local supplied="${1:-}"
  local tmp_dl
  tmp_dl="$(mktemp)"
  chmod 600 "$tmp_dl"

  while true; do
    local input="$supplied"
    supplied=""

    if [ -z "$input" ]; then
      # Auto-offer ~/Downloads/kubeconfig.yaml if attendee downloaded from Google Drive / Zoom
      if [ -f "$HOME/Downloads/kubeconfig.yaml" ] && [ -t 0 ]; then
        local use_dl=""
        printf "Found ~/Downloads/kubeconfig.yaml — import it now? [Y/n]: "
        read -r use_dl </dev/tty || true
        case "$use_dl" in
          [nN]*) ;;
          *) input="$HOME/Downloads/kubeconfig.yaml" ;;
        esac
      fi
    fi

    if [ -z "$input" ]; then
      if [ ! -t 0 ]; then
        rm -f "$tmp_dl"
        return 1
      fi
      echo ""
      echo "=== Step 1: Configure Berkelium kubectl Access (Namespace: $TRAINING_NS) ==="
      echo "  Enter the Workshop Join Code shown on the slide / Zoom chat"
      echo "  (or paste a file path like ~/Downloads/kubeconfig.yaml, or paste an 'eyJ...' token,"
      echo "   or press Enter to skip for now):"
      printf "Workshop Join Code / path / token: "
      read -r input </dev/tty || true
      input="$(printf '%s' "$input" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      if [ -z "$input" ]; then
        echo "Skipped kubeconfig setup for now (run './setup.sh --kubeconfig' anytime)."
        rm -f "$tmp_dl"
        return 0
      fi
    fi

    # Expand leading ~/ if user typed a path
    case "$input" in
      "~/"*) input="$HOME/${input#\~/}" ;;
    esac

    # Case 1: Local file path
    if [ -f "$input" ]; then
      if grep -q "clusters:" "$input" 2>/dev/null; then
        cp "$input" "$LOCAL_KC"
        chmod 600 "$LOCAL_KC"
        echo "Saved kubeconfig -> $LOCAL_KC"
        rm -f "$tmp_dl"
        install_home_kubeconfig "$LOCAL_KC"
        return 0
      else
        echo "Error: File '$input' does not look like a valid Kubernetes config file." >&2
      fi

    # Case 2: Raw Kubernetes JWT ServiceAccount token ('eyJ...')
    elif [[ "$input" == eyJ* ]] && [ "${#input}" -gt 80 ]; then
      write_kc_from_token "$input" "$LOCAL_KC"
      echo "Generated kubeconfig from token -> $LOCAL_KC"
      rm -f "$tmp_dl"
      install_home_kubeconfig "$LOCAL_KC"
      return 0

    # Case 3: Workshop Join Code -> fetch from training-hub.bk.lbl.gov
    else
      echo "Fetching workshop kubeconfig from $HUB_URL/kubeconfig ..."
      local http_code=""
      http_code="$(curl -sSL -w '%{http_code}' -o "$tmp_dl" --connect-timeout 6 \
        -H "X-Workshop-Code: $input" \
        "$HUB_URL/kubeconfig" 2>/dev/null || echo "000")"

      if [ "$http_code" = "200" ] && grep -q "clusters:" "$tmp_dl" 2>/dev/null; then
        cp "$tmp_dl" "$LOCAL_KC"
        chmod 600 "$LOCAL_KC"
        echo "Downloaded workshop kubeconfig -> $LOCAL_KC"
        rm -f "$tmp_dl"
        install_home_kubeconfig "$LOCAL_KC"
        return 0
      elif [ "$http_code" = "403" ]; then
        echo "Invalid Workshop Join Code '$input'. Double-check the code on the slide/Zoom chat." >&2
      elif [ "$http_code" = "429" ]; then
        echo "Too many attempts — wait 60 seconds or paste the backup file/token." >&2
      elif [ "$http_code" = "404" ]; then
        echo "Hub is reachable, but the instructor hasn't uploaded the join code yet (run ./hub/deploy-hub.sh)." >&2
      else
        echo "Could not reach $HUB_URL (HTTP $http_code)." >&2
        echo "  • If you are off-site without VPN, run this inside Coder (https://coder.bk.lbl.gov)!" >&2
        echo "  • If you are on a local laptop, connect to LBNL Wi-Fi or LBNL VPN first." >&2
      fi
    fi

    if [ ! -t 0 ]; then
      rm -f "$tmp_dl"
      return 1
    fi
  done
}

has_working_kubeconfig() {
  [ -f "$LOCAL_KC" ] && return 0
  [ -n "${KUBECONFIG:-}" ] && [ -f "${KUBECONFIG%%:*}" ] && return 0
  if [ -f "$HOME/.kube/config" ] && grep -q "$TRAINING_NS" "$HOME/.kube/config" 2>/dev/null; then
    return 0
  fi
  return 1
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
    "quest1-pod",
    "quest3-pod",
    "quest3-pvc",
    "broken-pvc",
    "cephfs-pod",
    "cephfs-pvc",
    "debug-pod",
    "test-http",
    "boss-job",
    "boss-pvc",
    "test-pod",
    "test-svc",
    "cpu-job",
    "rbd-pod",
    "rbd-pvc",
]

target_files = []
for subdir in ("scripts", "challenges"):
    scan_dir = os.path.join(repo_root, subdir)
    if not os.path.isdir(scan_dir):
        continue
    for root, _, files in os.walk(scan_dir):
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
        pat = re.compile(rf"(?<![a-z0-9-]){re.escape(src)}(?=\.bk\.lbl\.gov\b)")
    else:
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

# Parse CLI flags
FORCE_KC=0
JOIN_CODE_ARG=""
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --status)
      if [ -n "$current_suffix" ]; then
        echo "Active attendee suffix : -$current_suffix (stored in .training-user)"
      else
        echo "Active attendee suffix : (not configured yet — run ./setup.sh)"
      fi
      if [ -f "$HOME/.kube/config" ] && grep -q "$TRAINING_NS" "$HOME/.kube/config" 2>/dev/null; then
        echo "kubectl config         : ~/.kube/config (ready across all terminal tabs)"
      elif [ -n "${KUBECONFIG:-}" ]; then
        echo "kubectl config         : $KUBECONFIG (via \$KUBECONFIG)"
      elif [ -f "$LOCAL_KC" ]; then
        echo "kubectl config         : $LOCAL_KC (run './setup.sh --kubeconfig' to also install ~/.kube/config)"
      else
        echo "kubectl config         : NOT CONFIGURED YET (run './setup.sh --kubeconfig')"
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
    --kubeconfig)
      FORCE_KC=1
      shift
      ;;
    --code)
      FORCE_KC=1
      JOIN_CODE_ARG="${2:-}"
      if [ -z "$JOIN_CODE_ARG" ]; then
        echo "Error: --code requires a value (e.g., ./setup.sh --code bk-7k9m)" >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

target_raw="${POSITIONAL[0]:-}"

# Step 1: Configure kubeconfig when requested (--kubeconfig / --code) or when running interactively without one
if [ "$FORCE_KC" -eq 1 ]; then
  fetch_or_import_kubeconfig "$JOIN_CODE_ARG"
  # If user ONLY ran './setup.sh --kubeconfig' and suffix is already set, exit cleanly after verification
  if [ -z "$target_raw" ] && [ -z "$JOIN_CODE_ARG" ] && [ -n "$current_suffix" ]; then
    [ -f "$LOCAL_KC" ] && [ -z "${KUBECONFIG:-}" ] && [ ! -f "$HOME/.kube/config" ] && export KUBECONFIG="$LOCAL_KC" || true
    kubectl auth whoami 2>/dev/null || true
    exit 0
  fi
elif [ -z "$target_raw" ] && [ -t 0 ]; then
  if ! has_working_kubeconfig; then
    fetch_or_import_kubeconfig ""
  elif [ -f "$LOCAL_KC" ] && [ ! -f "$HOME/.kube/config" ]; then
    install_home_kubeconfig "$LOCAL_KC"
  fi
fi

# Step 2: Determine & apply per-attendee suffix
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

  echo ""
  echo "=== Personalize Workshop Resource Names (Namespace: $TRAINING_NS) ==="
  echo "Enter your LBNL username or initials so your pods/jobs don't collide with classmates:"
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

if [ -z "${KUBECONFIG:-}" ] && [ -f "$LOCAL_KC" ] && [ ! -f "$HOME/.kube/config" ]; then
  export KUBECONFIG="$LOCAL_KC"
  echo ""
  echo "Tip: For manual kubectl commands in your shell, run:"
  echo "  export KUBECONFIG=\"$LOCAL_KC\""
fi

if command -v kubectl >/dev/null 2>&1 && has_working_kubeconfig; then
  [ -z "${KUBECONFIG:-}" ] && [ -f "$LOCAL_KC" ] && [ ! -f "$HOME/.kube/config" ] && export KUBECONFIG="$LOCAL_KC" || true
  echo ""
  echo "Verifying Berkelium cluster connection ($TRAINING_NS)..."
  if kubectl -n "$TRAINING_NS" get pods >/dev/null 2>&1; then
    echo "Connected! 'kubectl' is ready in namespace '$TRAINING_NS'."
    echo "Next: run './lab' (Terminal Quest UI) or './lab --web' (Browser Quest UI)!"
  else
    echo "(Note: could not reach Berkelium API yet — check LBNL Wi-Fi/VPN, or use a Coder terminal at https://coder.bk.lbl.gov)"
  fi
fi
