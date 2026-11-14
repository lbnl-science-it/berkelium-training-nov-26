#!/bin/bash
# Shared interactive step-by-step runner for Berkelium training exercises.
#
# Default mode (interactive):
#   Pre-fills each command at an editable '$ ' prompt (read -e -i / zsh vared).
#   - Press Enter to run the pre-filled command (or edit it inline first!)
#   - Type 's' (or clear the line) to skip a step
#   - Type 'q' (or Ctrl+C) to exit cleanly
#
# Flags:
#   --yes   / -y : Run all steps non-interactively (prints '$ <cmd>' before each)
#   --print / -p : Print numbered commands only without executing anything

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REL_DIR="${SCRIPT_DIR#"$REPO_ROOT"/}"
cd "$SCRIPT_DIR"

[ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ] && export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml" || true

TRAINING_MODE="${TRAINING_MODE:-interactive}"
if [ "${TRAINING_AUTO:-0}" = "1" ]; then
  TRAINING_MODE="auto"
fi

for arg in "$@"; do
  case "$arg" in
    -y|--yes|--run|--auto)
      TRAINING_MODE="auto"
      ;;
    -p|--print|--dry)
      TRAINING_MODE="print"
      ;;
    -h|--help)
      echo "Usage: $0 [--yes | --print]"
      echo "  (default) : Interactive step-by-step editable prompt"
      echo "  --yes     : Execute all commands automatically"
      echo "  --print   : Print all commands without executing"
      exit 0
      ;;
  esac
done

# Fall back to auto mode if no controlling terminal is attached
if [ "$TRAINING_MODE" = "interactive" ] && [ ! -t 0 ]; then
  TRAINING_MODE="auto"
fi

# Ensure attendee has personalized resource names for the shared namespace
if [ "${TRAINING_SKIP_SETUP:-0}" != "1" ] && [ "$TRAINING_MODE" != "print" ] && [ ! -f "$REPO_ROOT/.training-user" ]; then
  if [ "$TRAINING_MODE" = "interactive" ]; then
    "$REPO_ROOT/setup.sh"
    echo ""
    # Re-exec the caller script from byte 0 so newly stamped '-<user>' names take effect cleanly
    exec "${BASH_SOURCE[1]}" "$@"
  fi
fi

TRAINING_USER_SUFFIX=""
if [ -f "$REPO_ROOT/.training-user" ]; then
  TRAINING_USER_SUFFIX="$(tr -d '[:space:]' < "$REPO_ROOT/.training-user")"
fi

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

STEP_NUM=0
STEP_TOTAL=0

init_exercise() {
  local title="$1"
  STEP_TOTAL="${2:-0}"
  STEP_NUM=0

  local sfx_note=""
  if [ -n "$TRAINING_USER_SUFFIX" ]; then
    sfx_note=" | suffix: -${TRAINING_USER_SUFFIX}"
  fi

  echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
  echo "${C_BOLD}${title}${C_RESET} ${C_DIM}(dir: ${REL_DIR}${sfx_note})${C_RESET}"
  if [ "$TRAINING_MODE" = "interactive" ]; then
    echo "${C_DIM}Controls: [Enter] run command | edit inline | 's' skip | 'q' quit${C_RESET}"
  elif [ "$TRAINING_MODE" = "print" ]; then
    echo "${C_DIM}Print-only mode (copy & run commands below in '${REL_DIR}'):${C_RESET}"
    echo "cd \"$REL_DIR\""
  fi
  echo "${C_BOLD}${C_CYAN}======================================================================${C_RESET}"
}

_prompt_editable() {
  local default_cmd="$1"
  local reply=""

  if [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
    read -e -r -p "${C_GREEN}\$ ${C_RESET}" -i "$default_cmd" reply </dev/tty || return 130
  elif [ -x /bin/zsh ]; then
    reply="$(DEFAULT_CMD="$default_cmd" /bin/zsh -f -c '
      zmodload zsh/zle
      cmd="$DEFAULT_CMD"
      vared -p "%F{green}\$ %f" cmd || exit 130
      printf "%s" "$cmd"
    ' </dev/tty)" || return 130
  else
    printf "%s\$ %s\n" "$C_GREEN" "$default_cmd$C_RESET" >/dev/tty
    printf "Press Enter to run (or type replacement command, 's'=skip, 'q'=quit): " >/dev/tty
    read -r reply </dev/tty || return 130
    if [ -z "$reply" ]; then
      reply="$default_cmd"
    fi
  fi

  printf '%s' "$reply"
}

_run_step_impl() {
  local expect_fail="$1"
  local desc="$2"
  local cmd="$3"

  STEP_NUM=$((STEP_NUM + 1))
  local label="[Step ${STEP_NUM}"
  if [ "$STEP_TOTAL" -gt 0 ]; then
    label="${label}/${STEP_TOTAL}"
  fi
  label="${label}]"

  echo ""
  echo "${C_BOLD}${C_YELLOW}${label}${C_RESET} ${C_BOLD}${desc}${C_RESET}"

  if [ "$TRAINING_MODE" = "print" ]; then
    echo "$cmd"
    return 0
  fi

  if [ "$TRAINING_MODE" = "auto" ]; then
    echo "${C_GREEN}\$ ${cmd}${C_RESET}"
    eval "$cmd"
    local rc=$?
    if [ "$expect_fail" = "1" ]; then
      if [ "$rc" -ne 0 ]; then
        echo "${C_GREEN}--> Expected rejection confirmed (exit code $rc).${C_RESET}"
        return 0
      fi
      echo "Unexpectedly succeeded (expected policy rejection)." >&2
      return 1
    fi
    return "$rc"
  fi

  local current_default="$cmd"
  while true; do
    local user_cmd
    if ! user_cmd="$(_prompt_editable "$current_default")"; then
      echo ""
      echo "Exiting exercise. (Run ./scripts/cleanup-all.sh anytime to clean up your resources.)"
      exit 130
    fi

    case "$user_cmd" in
      ""|s|skip)
        echo "${C_DIM}(Skipped step ${STEP_NUM})${C_RESET}"
        return 0
        ;;
      q|quit|exit)
        echo "Exiting exercise. (Run ./scripts/cleanup-all.sh anytime to clean up your resources.)"
        exit 0
        ;;
    esac

    eval "$user_cmd"
    local rc=$?

    if [ "$expect_fail" = "1" ]; then
      if [ "$rc" -ne 0 ]; then
        echo "${C_GREEN}--> Expected rejection confirmed (exit code $rc).${C_RESET}"
      fi
      return 0
    fi

    if [ "$rc" -eq 0 ]; then
      return 0
    fi

    echo "${C_YELLOW}Command exited with code ${rc}.${C_RESET}"
    current_default="$user_cmd"
    local action=""
    printf "Retry this step? [Enter=edit/retry | s=skip | q=quit]: " >/dev/tty
    read -r action </dev/tty || exit 130
    case "$action" in
      s|skip)
        return 0
        ;;
      q|quit|exit)
        exit "$rc"
        ;;
    esac
  done
}

step() {
  _run_step_impl 0 "$1" "$2"
}

step_expect_fail() {
  _run_step_impl 1 "$1" "$2"
}
