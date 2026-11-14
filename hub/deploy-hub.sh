#!/bin/bash
# Deploy or update the shared in-cluster Berkelium Classroom Hub (svc/training-hub)
# in namespace 'training-nov-26'.
#
# Run once before the workshop from Coder or any terminal on LBL network / VPN:
#   ./hub/deploy-hub.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${KUBECONFIG:-}" ] && [ -f "$REPO_ROOT/kubeconfig.yaml" ]; then
  export KUBECONFIG="$REPO_ROOT/kubeconfig.yaml"
fi

NS="$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || true)"
NS="${NS:-training-nov-26}"

echo "=== Deploying Berkelium Classroom Hub to namespace '$NS' ==="

echo "1/3 Syncing ConfigMap/training-hub-code from ./lab ..."
kubectl -n "$NS" create configmap training-hub-code \
  --from-file=lab="$REPO_ROOT/lab" \
  --dry-run=client -o yaml | kubectl -n "$NS" apply -f -

echo "2/3 Applying Deployment, Service, and internal-LBL HTTPRoute ..."
kubectl -n "$NS" apply -f "$REPO_ROOT/hub/training-hub.yaml"

echo "3/3 Restarting & waiting for Deployment/training-hub rollout ..."
kubectl -n "$NS" rollout restart deployment/training-hub
kubectl -n "$NS" rollout status deployment/training-hub --timeout=90s

cat <<'EOF'

=== Classroom Hub Ready! ===
1. Classroom Projector / LBL Wi-Fi / LBL VPN (no world-readable exception required):
     https://training-hub.bk.lbl.gov/?view=classroom

2. Off-site Laptop via kubectl port-forward:
     kubectl port-forward svc/training-hub 8080:80
     -> Open http://localhost:8080

3. Off-site Attendee inside Coder (https://coder.bk.lbl.gov — zero VPN needed):
     ./lab --web
     -> Coder automatically proxies port 8080 to their browser over LBNL SSO!
EOF
