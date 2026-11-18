---
name: Kubernetes CLI & Workshop
description: Fast, lightweight Kubernetes workspace (2 CPU / 4 GB) with kubectl, helm, k9s, radar, python3, uv, and VS Code Web
tags: [kubernetes, kubectl, k9s, radar, helm, workshop, cli]
icon: /icon/k8s.svg
---

# Kubernetes CLI & Workshop Workspace (`k8s-cli`)

A fast-booting, low-footprint Ubuntu workspace (`codercom/enterprise-base:ubuntu-20261019`) designed for submitting and managing Berkelium Kubernetes workloads, batch jobs, and live hands-on workshops without allocating heavy language toolchains or GPUs:

- **Lightweight Defaults**: `2` CPU cores (`250m` request), `4` GB RAM (`512Mi` request), and a `10` GB persistent Ceph RBD `/home/coder` disk so dozens of concurrent workshop attendees launch in seconds.
- **Kubernetes CLI Suite**: Pre-installs `kubectl` (with `k` alias + bash completion), `helm`, `k9s`, `radar` (`kubectl radar`), `python3`, `uv`, `jq`, `ripgrep`, `fzf`, `tmux`, and `btop`.
- **Browser & Remote IDEs**: Includes **Quest Lab** (auto-started on `:8080` when the workshop repo is cloned), **code-server** (VS Code Web with YAML & Kubernetes extensions), **Web Terminal**, and **VS Code Desktop**.
- **Auto-Cloned Workshop Repo**: Pre-fills `https://github.com/lbnl-science-it/berkelium-training-nov-26.git` by default so **Quest Lab**, **code-server**, and **Web Terminal** open ready to go inside `/home/coder/berkelium-training-nov-26` (clear the Git Repository URL field if you want a blank workspace).

## Persistence

Your `/home/coder` directory (including `~/.kube/config`, cloned repositories, and cached CLI binaries) persists across workspace stops and restarts on `ceph-rbd`.
