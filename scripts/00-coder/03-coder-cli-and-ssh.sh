#!/bin/bash
# Reference workflow for connecting to Berkelium Coder (https://coder.bk.lbl.gov)
# from your local laptop terminal, VS Code, or Cursor IDE.
#
# Run these commands interactively on your local machine (not automatically in batch).

cat <<'EOF'
=== Berkelium Coder CLI & Remote-SSH Quick Reference ===

1. Install the matching Coder CLI binary directly from Berkelium Coder:
   curl -fsSL https://coder.bk.lbl.gov/install.sh | sh

2. Authenticate via LBNL SSO (opens browser token page):
   coder login https://coder.bk.lbl.gov

3. List available templates and your active workspaces:
   coder templates list
   coder list

4. Configure ~/.ssh/config for VS Code Remote-SSH, Cursor, rsync, and scp:
   coder config-ssh --yes

5. SSH directly into your workspace (including KubeVirt Linux VMs!):
   coder ssh <workspace-name>
   # or via OpenSSH:
   ssh coder.<workspace-name>

6. Stop your workspace when done to release GPUs back to the cluster:
   coder stop <workspace-name> --yes
   # Note: Your /home/coder volume (ceph-rbd) remains safely preserved while stopped!
EOF
