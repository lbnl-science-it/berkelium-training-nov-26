#!/bin/bash
# Deploy or update the shared in-cluster Berkelium Classroom Hub (svc/training-hub)
# AND configure passcode-protected kubeconfig distribution (zero secrets in GitHub!).
#
# Usage (run once before the workshop from LBL network / VPN / Ziti):
#   ./hub/deploy-hub.sh                 # Auto-generates (or reuses) a Workshop Join Code
#   ./hub/deploy-hub.sh bk-nov26        # Explicitly set the Workshop Join Code to 'bk-nov26'

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

# Public Berkelium API endpoint & cluster CA certificate (public X.509 CA cert, NOT a secret)
CLUSTER_SERVER="https://[2620:83:8000:157::f]:6443"
CLUSTER_CA_B64="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJpekNDQVRDZ0F3SUJBZ0lSQU5JNU1YaGRwSk1XckswbXUyMERxVjR3Q2dZSUtvWkl6ajBFQXdJd0ZURVQKTUJFR0ExVUVDaE1LYTNWaVpYSnVaWFJsY3pBZUZ3MHlOakEzTURFeU16TTNNelJhRncwek5qQTJNamd5TXpNMwpNelJhTUJVeEV6QVJCZ05WQkFvVENtdDFZbVZ5Ym1WMFpYTXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CCkJ3TkNBQVIybHJORkhZUkZDemtvQVZOTHRIMEZRQWJVSm4veFdJb0x6NEQ2VVRadjU0bk1ORy9pWk9wRitDY0sKWmZOd2h1NWFmWStFdkRHVWtqRXZDYUFGN053dW8yRXdYekFPQmdOVkhROEJBZjhFQkFNQ0FvUXdIUVlEVlIwbApCQll3RkFZSUt3WUJCUVVIQXdFR0NDc0dBUVVGQndNQ01BOEdBMVVkRXdFQi93UUZNQU1CQWY4d0hRWURWUjBPCkJCWUVGSjRaTEorOWd1OVpMS3NQVWU4S2hpbnNSbmdqTUFvR0NDcUdTTTQ5QkFNQ0Ewa0FNRVlDSVFEMFNQdTAKT3ZnNzJNRmpEMklzcE84TXZ3dVBPc2NwZVd3MUUyOEwyRTVCRWdJaEFLSkVqQmdVMCs2REQ2ZUZMVDJuNmlGZgo4OWE3Tm5keC9DbVpOb0M1ZmlwTwotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="

echo "=== Deploying Berkelium Classroom Hub to namespace '$NS' ==="

# 1. Determine Workshop Join Code (explicit arg > existing Secret > newly generated)
JOIN_CODE="${1:-}"
if [ -z "$JOIN_CODE" ]; then
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
