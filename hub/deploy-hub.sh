#!/bin/bash
# Deploy or update the shared in-cluster Berkelium Classroom Hub (svc/training-hub)
# AND configure passcode-protected kubeconfig distribution (zero secrets in GitHub!).
#
# Usage (run from LBL network / VPN / Ziti):
#   ./hub/deploy-hub.sh                    # Deploy/update hub (reuses existing Join Code)
#   ./hub/deploy-hub.sh bk-nov26           # Deploy/update hub with explicit Join Code 'bk-nov26'
#   ./hub/deploy-hub.sh --reset            # Wipe ALL attendee workloads & scoreboard + refresh 24h token (keeps Join Code)
#   ./hub/deploy-hub.sh --reset --new-code # Wipe ALL attendee workloads & scoreboard + generate a brand-new Join Code
#   ./hub/deploy-hub.sh --reset bk-run2    # Wipe ALL attendee workloads & scoreboard + set Join Code to 'bk-run2'
#   ./hub/deploy-hub.sh --teardown         # Delete everything (all attendee workloads, scoreboard, AND training-hub itself)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${KUBECONFIG:-}" ]; then
  if [ -f "$HOME/.kube/config_berkelium_auth.yaml" ]; then
    export KUBECONFIG="$HOME/.kube/config_berkelium_auth.yaml"
  elif [ -f "$REPO_ROOT/kubeconfig.yaml" ]; then
    export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml"
  fi
fi

NS="${TRAINING_NAMESPACE:-training-nov-26}"

RESET_STATE=0
NEW_CODE=0
TEARDOWN=0
JOIN_CODE=""

for arg in "$@"; do
  case "$arg" in
    --reset|--clean)
      RESET_STATE=1
      ;;
    --new-code|--rotate-code)
      NEW_CODE=1
      ;;
    --teardown|--destroy)
      TEARDOWN=1
      ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown flag: $arg (try --help)" >&2
      exit 1
      ;;
    *)
      JOIN_CODE="$arg"
      ;;
  esac
done

wipe_attendee_state() {
  echo "=== Cleaning all attendee workloads & leaderboard state in '$NS' ==="
  # Pause training-hub during wipe so no in-flight poll re-persists deleted state
  kubectl -n "$NS" scale deployment/training-hub --replicas=0 2>/dev/null || true

  # 1. Delete attendee HTTPRoutes, Deployments, and Services (preserving training-hub & kubernetes)
  kubectl -n "$NS" delete httproute -l 'app!=training-hub' --ignore-not-found
  kubectl -n "$NS" delete deployment -l 'app!=training-hub' --ignore-not-found
  for svc in $(kubectl -n "$NS" get svc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
    if [ "$svc" != "training-hub" ] && [ "$svc" != "kubernetes" ]; then
      kubectl -n "$NS" delete svc "$svc" --ignore-not-found
    fi
  done

  # 2. Delete all attendee Jobs, standalone Pods, DRA claims/templates, and PVCs
  kubectl -n "$NS" delete jobs --all --ignore-not-found --timeout=45s || true
  kubectl -n "$NS" delete pods -l 'app!=training-hub' --ignore-not-found --timeout=45s || true
  kubectl -n "$NS" delete resourceclaimtemplate --all --ignore-not-found 2>/dev/null || true
  kubectl -n "$NS" delete resourceclaim --all --ignore-not-found 2>/dev/null || true
  kubectl -n "$NS" delete pvc --all --ignore-not-found --timeout=45s || true

  # 3. Delete sticky scoreboard ConfigMaps (lab-state-<user>), preserving training-hub-code & kube-root-ca.crt
  kubectl -n "$NS" delete configmap -l app.kubernetes.io/part-of=berkelium-lab --ignore-not-found
  echo "=== Attendee workloads & scoreboard ConfigMaps wiped ==="
}

if [ "$TEARDOWN" -eq 1 ]; then
  wipe_attendee_state
  echo "=== Removing Classroom Hub infrastructure from '$NS' ==="
  kubectl -n "$NS" delete -f "$REPO_ROOT/hub/training-hub.yaml" --ignore-not-found
  kubectl -n "$NS" delete configmap training-hub-code --ignore-not-found
  kubectl -n "$NS" delete secret training-hub-join --ignore-not-found
  rm -f /tmp/berkelium-training-kubeconfig.yaml
  echo "=== Teardown complete (namespace '$NS', RBAC, and LimitRange preserved) ==="
  exit 0
fi

if [ "$RESET_STATE" -eq 1 ]; then
  wipe_attendee_state
fi

# Public Berkelium API endpoint & cluster CA certificate (public X.509 CA cert, NOT a secret)
CLUSTER_SERVER="https://[2620:83:8000:157::f]:6443"
CLUSTER_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJpekNDQVRDZ0F3SUJBZ0lSQU5JNU1YaGRwSk1XckswbXUyMERxVjR3Q2dZSUtvWkl6ajBFQXdJd0ZURVQKTUJFR0ExVUVDaE1LYTNWaVpYSnVaWFJsY3pBZUZ3MHlOakEzTURFeU16TTNNelJhRncwek5qQTJNamd5TXpNMwpNelJhTUJVeEV6QVJCZ05WQkFvVENtdDFZbVZ5Ym1WMFpYTXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CCkJ3TkNBQVIybHJORkhZUkZDemtvQVZOTHRIMEZRQWJVSm4veFdJb0x6NEQ2VVRadjU0bk1ORy9pWk9wRitDY0sKWmZOd2h1NWFmWStFdkRHVWtqRXZDYUFGN053dW8yRXdYekFPQmdOVkhROEJBZjhFQkFNQ0FvUXdIUVlEVlIwbApCQll3RkFZSUt3WUJCUVVIQXdFR0NDc0dBUVVGQndNQ01BOEdBMVVkRXdFQi93UUZNQU1CQWY4d0hRWURWUjBPCkJCWUVGSjRaTEorOWd1OVpMS3NQVWU4S2hpbnNSbmdqTUFvR0NDcUdTTTQ5QkFNQ0Ewa0FNRVlDSVFEMFNQdTAKT3ZnNzJNRmpEMklzcE84TXZ3dVBPc2NwZVd3MUUyOEwyRTVCRWdJaEFLSkVqQmdVMCs2REQ2ZUZMVDJuNmlGZgo4OWE3Tm5keC9DbVpOb0M1ZmlwTwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

echo "=== Deploying Berkelium Classroom Hub to namespace '$NS' ==="

# 1. Determine Workshop Join Code (explicit arg > existing Secret [unless --new-code] > newly generated)
if [ -z "$JOIN_CODE" ] && [ "$NEW_CODE" -eq 0 ]; then
  EXISTING_B64="$(kubectl -n "$NS" get secret training-hub-join -o jsonpath='{.data.code}' 2>/dev/null || true)"
  if [ -n "$EXISTING_B64" ]; then
    JOIN_CODE="$(printf '%s' "$EXISTING_B64" | base64 -d 2>/dev/null || printf '%s' "$EXISTING_B64" | base64 -D 2>/dev/null || true)"
  fi
fi
if [ -z "$JOIN_CODE" ]; then
  JOIN_CODE="$(python3 -c 'import secrets, string; alphabet = "abcdefghjkmnpqrstuvwxyz23456789"; print("bk-" + "".join(secrets.choice(alphabet) for _ in range(5)))')"
fi

# 2. Build attendee kubeconfig (prefer 24h auto-expiring token; fallback to local kubeconfig.yaml)
TMP_KC="$(mktemp)"
chmod 600 "$TMP_KC"
trap 'rm -f "$TMP_KC"' EXIT

TOKEN_24H="$(kubectl -n "$NS" create token training-user --duration=24h 2>/dev/null || true)"
if [ -n "$TOKEN_24H" ]; then
  echo "1/4 Minted fresh 24-hour auto-expiring token for ServiceAccount/training-user ..."
  cat > "$TMP_KC" <<EOF
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
    namespace: ${NS}
    user: training-user
current-context: training@berkelium
users:
- name: training-user
  user:
    token: ${TOKEN_24H}
EOF
elif [ -f "$REPO_ROOT/kubeconfig.yaml" ]; then
  echo "1/4 Using local $REPO_ROOT/kubeconfig.yaml for attendee distribution ..."
  cp "$REPO_ROOT/kubeconfig.yaml" "$TMP_KC"
else
  echo "Error: Could not mint token via 'kubectl create token training-user' and '$REPO_ROOT/kubeconfig.yaml' not found." >&2
  exit 1
fi

BACKUP_KC="/tmp/berkelium-training-kubeconfig.yaml"
cp "$TMP_KC" "$BACKUP_KC"
chmod 600 "$BACKUP_KC"

echo "2/4 Storing passcode-protected kubeconfig in Secret/training-hub-join (never in git!) ..."
kubectl -n "$NS" create secret generic training-hub-join \
  --from-literal=code="$JOIN_CODE" \
  --from-file=kubeconfig.yaml="$TMP_KC" \
  --dry-run=client -o yaml | kubectl -n "$NS" apply -f -

echo "3/4 Syncing ConfigMap/training-hub-code from ./lab & applying hub manifests ..."
kubectl -n "$NS" create configmap training-hub-code \
  --from-file=lab="$REPO_ROOT/lab" \
  --dry-run=client -o yaml | kubectl -n "$NS" apply -f -
kubectl -n "$NS" apply -f "$REPO_ROOT/hub/training-hub.yaml"

echo "4/4 Restarting & waiting for Deployment/training-hub rollout ..."
kubectl -n "$NS" rollout restart deployment/training-hub
kubectl -n "$NS" rollout status deployment/training-hub --timeout=90s

cat <<EOF

======================================================================
  BERKELIUM CLASSROOM HUB & KUBECONFIG DISTRIBUTION READY!
======================================================================
  Share this Workshop Join Code on your opening slide / Zoom chat:

      WORKSHOP JOIN CODE :  ${JOIN_CODE}

  How Attendees Configure kubectl + Suffix (1 command!):
      git clone https://github.com/lbnl-science-it/berkelium-training-nov-26.git
      cd berkelium-training-nov-26
      ./setup.sh
      (When prompted for the Workshop Join Code, they enter: ${JOIN_CODE})

  Optional Backup File (e.g. for an @lbl.gov-only Google Drive folder):
      Saved locally at: ${BACKUP_KC}

  Live Dashboards:
    • Projector / LBL Wi-Fi / VPN : https://training-hub.bk.lbl.gov/?view=classroom
    • Coder Attendee Browser UI   : ./lab --web  (auto-proxied on port 8080)
    • Laptop Port-Forward         : kubectl port-forward svc/training-hub 8080:80
======================================================================
EOF
