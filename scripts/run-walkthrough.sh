#!/bin/bash
# Interactive menu & sequential runner for all 20 Berkelium Guided Scripts (Modules 01–06).
#
# Usage:
#   ./scripts/run-walkthrough.sh          # Open interactive menu (press Enter to step through 1 -> 20)
#   ./scripts/run-walkthrough.sh m2       # Jump directly to Module 02 (GPUs, DRA & Dynamic MIG)
#   ./scripts/run-walkthrough.sh 14       # Jump directly to Exercise 14 (04.3 HTTPRoute)
#   ./scripts/run-walkthrough.sh --list   # Print all 6 modules & 20 exercises and exit

set -uo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
STATE_FILE="$REPO_ROOT/.training-user"

[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

# Format: "module_num|code|short_title|rel_script_path"
EXERCISES=(
  "1|01.1|Explore nodes, identity & LimitRange|01-nodes-and-pods/01-explore-cluster.sh"
  "1|01.2|Launch & exec into a single-container Pod|01-nodes-and-pods/02-pod-management.sh"
  "1|01.3|Multi-container Pod (nginx + sidecar)|01-nodes-and-pods/03-multi-container-management.sh"
  "2|02.1|Discover GPU models & DRA DeviceClasses|02-gpu-pods/01-gpu-discovery.sh"
  "2|02.2|Run nvidia-smi Job (classic GPU limits)|02-gpu-pods/02-nvidia-smi-management.sh"
  "2|02.3|Claim GPU + /dev/shm via Kubernetes DRA|02-gpu-pods/03-dra-gpu-management.sh"
  "2|02.4|Carve an on-demand Dynamic MIG slice|02-gpu-pods/04-dynamic-mig-management.sh"
  "3|03.1|Inspect ceph-rbd & cephfs StorageClasses|03-storage/01-storage-discovery.sh"
  "3|03.2|ReadWriteOnce Ceph RBD block volume|03-storage/02-rbd-management.sh"
  "3|03.3|ReadWriteMany CephFS shared POSIX volume|03-storage/03-cephfs-management.sh"
  "3|03.4|Fast node-local NVMe scratch (emptyDir)|03-storage/05-nvme-scratch-management.sh"
  "4|04.1|Deploy & scale 2-replica HTTP service|04-deployments-services-ingresses/01-deployment-management.sh"
  "4|04.2|IPv6 ClusterIP Service load balancing|04-deployments-services-ingresses/02-service-management.sh"
  "4|04.3|Expose live HTTPS URL via HTTPRoute|04-deployments-services-ingresses/03-httproute-management.sh"
  "5|05.1|Unattended CPU batch Job|05-jobs/01-job-management.sh"
  "5|05.2|6-rank Indexed Parallel Parameter Sweep|05-jobs/02-parallel-job-management.sh"
  "5|05.3|PyTorch CUDA 13.0 BF16 GPU benchmark Job|05-jobs/03-gpu-job-management.sh"
  "6|06.1|Diagnose failing Pod via events & logs|06-debugging/01-pod-logs.sh"
  "6|06.2|Live kubectl exec & kubectl top metrics|06-debugging/02-pod-exec.sh"
  "6|06.3|Gatekeeper dry-run & Golden Rules audit|06-debugging/03-validate-policies.sh"
)

MODULE_TITLES=(
  ""
  "Module 01 — Nodes & Interactive Pods"
  "Module 02 — GPUs, DRA & Dynamic MIG"
  "Module 03 — Persistent Ceph Storage & NVMe Scratch"
  "Module 04 — Web Deployments, Services & HTTPRoute"
  "Module 05 — Batch Jobs & Indexed Parallel Sweeps"
  "Module 06 — Debugging, Live Metrics & Policy Audit"
)

C_BOLD=""
C_CYAN=""
C_GREEN=""
C_YELLOW=""
C_DIM=""
C_RESET=""
if [ -t 1 ]; then
  C_BOLD=$'\033[1m'
  C_CYAN=$'\033[36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_DIM=$'\033[2m'
  C_RESET=$'\033[0m'
fi

print_menu() {
  local sfx="(not set yet — will run ./setup.sh)"
  if [ -f "$STATE_FILE" ]; then
    sfx="-$(tr -d '[:space:]' < "$STATE_FILE")"
  fi
  echo ""
  echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
  echo "${C_BOLD}  BERKELIUM GUIDED SCRIPT WALKTHROUGH (Modules 01–06)${C_RESET}"
  echo "  Attendee suffix: ${C_GREEN}${sfx}${C_RESET}  |  Namespace: ${C_BOLD}training-nov-26${C_RESET}"
  echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"

  local prev_mod=""
  local i=0
  for entry in "${EXERCISES[@]}"; do
    i=$((i + 1))
    IFS='|' read -r mod code title rel <<< "$entry"
    if [ "$mod" != "$prev_mod" ]; then
      [ -n "$prev_mod" ] && echo ""
      echo "  ${C_BOLD}${C_YELLOW}${MODULE_TITLES[$mod]}${C_RESET} ${C_DIM}(type m${mod})${C_RESET}"
      prev_mod="$mod"
    fi
    printf "    [%2d] %-4s  %-42s ${C_DIM}(%s)${C_RESET}\n" "$i" "$code" "$title" "$(basename "$rel")"
  done
  echo ""
  echo "  ${C_BOLD}[c]${C_RESET} Clean up all workshop resources (cleanup-all.sh)    ${C_BOLD}[q]${C_RESET} Quit"
  echo "${C_DIM}----------------------------------------------------------------------${C_RESET}"
}

resolve_choice() {
  local choice="$1"
  case "$choice" in
    m1|M1) echo 1 ;;
    m2|M2) echo 4 ;;
    m3|M3) echo 8 ;;
    m4|M4) echo 12 ;;
    m5|M5) echo 15 ;;
    m6|M6) echo 18 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#EXERCISES[@]}" ]; then
        echo "$choice"
      else
        echo ""
      fi
      ;;
  esac
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [ "${1:-}" = "-l" ] || [ "${1:-}" = "--list" ]; then
  print_menu
  exit 0
fi

# Ensure attendee has configured kubeconfig & suffix before starting exercises
if [ ! -f "$STATE_FILE" ] && [ -t 0 ]; then
  "$REPO_ROOT/setup.sh"
fi

run_from_index() {
  local idx="$1"
  local total="${#EXERCISES[@]}"
  while [ "$idx" -le "$total" ]; do
    IFS='|' read -r mod code title rel <<< "${EXERCISES[$((idx - 1))]}"
    "$SCRIPTS_DIR/$rel"
    idx=$((idx + 1))
    if [ "$idx" -le "$total" ]; then
      IFS='|' read -r nmod ncode ntitle nrel <<< "${EXERCISES[$((idx - 1))]}"
      echo ""
      printf "${C_BOLD}Next → [%d/%d] %s %s${C_RESET} — Press ${C_GREEN}Enter${C_RESET} to continue [m=menu, q=quit]: " "$idx" "$total" "$ncode" "$ntitle"
      local nxt=""
      read -r nxt </dev/tty || exit 0
      case "$nxt" in
        m|M|menu) return 0 ;;
        q|Q|quit|exit) exit 0 ;;
      esac
    else
      echo ""
      echo "${C_GREEN}${C_BOLD}Completed all 20 guided scripts!${C_RESET}"
      echo "Tip: Try fixing challenges/06-boss-job.yaml for Quest 06, or run ./scripts/cleanup-all.sh when finished."
      return 0
    fi
  done
}

if [ -n "${1:-}" ]; then
  start_idx="$(resolve_choice "$1")"
  if [ -z "$start_idx" ]; then
    echo "Unknown exercise or module '$1' (use 1-${#EXERCISES[@]} or m1-m6; see --list)." >&2
    exit 1
  fi
  run_from_index "$start_idx"
  exit 0
fi

while true; do
  print_menu
  printf "Start at exercise ${C_BOLD}[1-${#EXERCISES[@]}, m1-m6, c=cleanup, q=quit]${C_RESET} (Enter = 1): "
  choice=""
  read -r choice </dev/tty || exit 0
  choice="$(printf '%s' "$choice" | tr -d '[:space:]')"
  if [ -z "$choice" ]; then
    choice="1"
  fi
  case "$choice" in
    q|Q|quit|exit)
      exit 0
      ;;
    c|C|clean|cleanup)
      "$SCRIPTS_DIR/cleanup-all.sh"
      ;;
    *)
      start_idx="$(resolve_choice "$choice")"
      if [ -n "$start_idx" ]; then
        run_from_index "$start_idx"
      else
        echo "${C_YELLOW}Please enter a number 1–${#EXERCISES[@]}, m1–m6, c, or q.${C_RESET}"
      fi
      ;;
  esac
done
