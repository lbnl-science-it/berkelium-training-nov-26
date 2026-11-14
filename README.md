# Berkelium Hands-On User Training (1 Hour)

Welcome to the **Berkelium Scientific Kubernetes & Cloud IDE Training** at Lawrence Berkeley National Laboratory (Science IT).

In **60 minutes**, this hands-on session covers both ways researchers work on Berkelium:
1. **Zero-YAML Interactive Cloud Workspaces with Coder** (`https://coder.bk.lbl.gov`) — browser VS Code, JupyterLab, Marimo, RStudio, AI Coding Agents (CBorg), Linux GUI Desktops, and KubeVirt Linux VMs with 1–8 NVIDIA GPUs (`A40`, `A100`, `H100`, `H200 NVL`, `B300 Blackwell`).
2. **Direct Kubernetes Workloads with `kubectl`** — interactive pods, GPU Dynamic Resource Allocation (DRA & Dynamic MIG), Ceph storage (`ceph-rbd` vs `cephfs`) & NVMe scratch, web services (`HTTPRoute`), and parallel batch jobs.

---

## 60-Minute Agenda

| Time | Duration | Module | Directory | What You Will Do |
| :--- | :--- | :--- | :--- | :--- |
| `00:00–00:12` | **12 min** | **00. Coder Cloud Workspaces** | [`scripts/00-coder/`](scripts/00-coder/) | Launch a Coder workspace (`cloud-native` or `cuda`), verify `/home/coder` persistence & PyTorch GPU, and see Coder CLI / Remote-SSH. |
| `00:12–00:19` | **7 min** | **01. Nodes & Interactive Pods** | [`scripts/01-nodes-and-pods/`](scripts/01-nodes-and-pods/) | Inspect Berkelium Talos/IPv6 nodes & `LimitRange`, run single- and multi-container pods, view logs, and `kubectl exec`. |
| `00:19–00:29` | **10 min** | **02. GPUs, DRA & Dynamic MIG** | [`scripts/02-gpu-pods/`](scripts/02-gpu-pods/) | Discover `B300`/`H200`/`H100`/`A100`/`A40`/`MI100` accelerators, run `nvidia-smi` via Extended Resources, claim GPUs via Kubernetes DRA, and carve a **Dynamic MIG** slice. |
| `00:29–00:37` | **8 min** | **03. Storage (`ceph-rbd`, `cephfs`, NVMe)** | [`scripts/03-storage/`](scripts/03-storage/) | Compare RWO block (`ceph-rbd`), RWX shared POSIX (`cephfs`), and ephemeral node-local NVMe scratch (`emptyDir`). |
| `00:37–00:45` | **8 min** | **04. Web Apps & `HTTPRoute`** | [`scripts/04-deployments-services-ingresses/`](scripts/04-deployments-services-ingresses/) | Deploy & scale a web service, load-balance via IPv6 `ClusterIP`, and expose HTTPS traffic via Gateway API `HTTPRoute`. |
| `00:45–00:52` | **7 min** | **05. Batch & Parallel Sweep Jobs** | [`scripts/05-jobs/`](scripts/05-jobs/) | Run unattended CPU jobs, **Indexed Parallel Parameter Sweeps** (`JOB_COMPLETION_INDEX`), and a PyTorch CUDA 13.0 GPU benchmark job. |
| `00:52–01:00` | **8 min** | **06. Debugging, Metrics & Policies + Q&A** | [`scripts/06-debugging/`](scripts/06-debugging/) | Diagnose crashed pods, inspect `kubectl top` metrics, catch policy violations (Gatekeeper & Berkelium MCP), and clean up. |

---

## Quick Setup (Choose Option A or Option B)

During live workshops, all attendees share the **`training-nov-26`** namespace via `kubeconfig.yaml` (save it either to `./kubeconfig.yaml` inside this repo or `~/.kube/config`). You can also generate your own personal project namespace anytime at **[berkelium.scs.lbl.gov/portal](https://berkelium.scs.lbl.gov/portal)**.

### Option A (Recommended — Zero Local Setup via Coder Browser Terminal)
Works from any laptop over standard HTTPS (no local `kubectl` or IPv6 network setup required):
1. Sign in to **[coder.bk.lbl.gov](https://coder.bk.lbl.gov)** with your LBNL SSO credentials.
2. Click **Templates** → choose **`Cloud-Native & Systems (Go + Rust)`** (`cloud-native` — starts in seconds with `kubectl` & `k9s` pre-installed) or **`PyTorch / CUDA Deep Learning`** (`cuda`).
3. Paste `https://github.com/lbnl-science-it/berkelium-training-nov-26.git` into **Git Repository URL (Optional)** and click **Create Workspace**.
4. Open **Web Terminal** (or **code-server** VS Code Web) and run `./setup.sh` to personalize your YAML resource names (`-<your-name>`):
   ```bash
   cd ~/berkelium-training-nov-26
   export KUBECONFIG="$(pwd)/kubeconfig.yaml"
   ./setup.sh
   ```

### Option B (Local Laptop / Workstation Terminal)
Requires `kubectl` installed and LBNL IPv6 / VPN connectivity to `[2620:83:8000:157::f]:6443`:
```bash
git clone https://github.com/lbnl-science-it/berkelium-training-nov-26.git
cd berkelium-training-nov-26
export KUBECONFIG="$(pwd)/kubeconfig.yaml"
./setup.sh
```

### How the Interactive Exercise Scripts Work
1. **Zero Name Collisions (`./setup.sh`)**: Running `./setup.sh` (auto-detects your Coder username or prompts once) stamps your unique suffix (e.g., `-alice`) directly into all local `.yaml` and `.sh` files (`test-pod-alice`, `test-svc-alice`, `training-demo-alice.bk.lbl.gov`). That means plain `kubectl apply -f ...` works out of the box without colliding with classmates! *(Run `./setup.sh --reset` anytime to restore base names.)*
2. **Interactive Editable Prompt**: Each `./scripts/.../*.sh` script walks through the exercise step-by-step and **pre-fills the exact `kubectl` command at an editable `$ ` prompt**:
   - Press **`Enter`** to execute the command, or **edit it inline** first (e.g., change flags, try `kubectl exec -it ... -- /bin/bash`).
   - Type **`s`** to skip a step or **`q`** (`Ctrl+C`) to quit.
   - Pass **`--print`** to display all commands without running them, or **`--yes`** to run all steps non-interactively.

---

## Berkelium's 4 Golden Rules

1. **Always Set Both `requests` AND `limits`**: Every container (and `initContainer`) must declare `cpu` and `memory` under both `resources.requests` and `resources.limits`. Omitting them falls back to the namespace `LimitRange` (`1` CPU limit, `1Gi` RAM limit), causing CPU throttling or `OOMKilled` crashes.
2. **Never Use `sleep infinity` in Batch `Job`s or GPU Reservations**: Batch `Job`s must run unattended computation and exit `0` automatically so GPUs return to the shared pool. Standalone interactive `Pod`s automatically terminate after **6 hours** (use **Coder** for interactive dev!).
3. **Pick the Right Storage Tier**:
   - **`ceph-rbd` (`ReadWriteOnce`)**: High small-file IOPS — use for `uv`/`conda`/`pip` environments, Git repos, source builds, and SQLite/DuckDB.
   - **`cephfs` (`ReadWriteMany`)**: Shared POSIX across multiple pods/nodes — use for large dataset shards (`.tar`, HDF5, Parquet) and checkpoints. **Never install `conda`/`pip` on `cephfs`!**
   - **`emptyDir` (`sizeLimit`)**: Fast ephemeral node-local NVMe `/scratch` (and `medium: Memory` for `/dev/shm`). Wiped when the pod exits.
4. **Gateway API (`HTTPRoute`) + IPv6/NAT64**: Berkelium runs an IPv6 pod network with transparent outbound IPv4/IPv6 internet access (DNS64/NAT64 — no HTTP proxies needed) and uses Kubernetes **Gateway API (`HTTPRoute`)** on `gateway/ingress` (`*.bk.lbl.gov`) instead of legacy `Ingress`.

---

## Hands-On Exercises Walkthrough

### Module 00 — Coder Cloud Development Environments (`12 min`)
Directory: [`scripts/00-coder/`](scripts/00-coder/)

1. **Explore Templates at [coder.bk.lbl.gov](https://coder.bk.lbl.gov)**:
   - **AI & Agents**: `ai-agents` (Claude Code, OpenCode, Aider, Gemini CLI, Codex pre-wired to **LBNL CBorg** `api.cborg.lbl.gov`), `openclaw`, `vllm`, `ollama-webui`, `comfyui`.
   - **GPU & Data Science**: `cuda` (PyTorch `2.14+cu130` with native NVIDIA B300 Blackwell support, JupyterLab, TensorBoard), `data-lab` (Marimo, DuckDB, Polars), `bio-chem-lab`, `rstudio`.
   - **Desktops, VMs & Systems**: `selkies` (GPU KDE Plasma), `desktop` (XFCE noVNC), `kubevirt` (full KVM Linux VM with `systemd` & Docker), `cloud-native`, `golang`, `nodejs`, `universal`.
2. **Verify Your Workspace & Run PyTorch Check** (inside your Coder terminal):
   ```bash
   ./scripts/00-coder/01-verify-coder-workspace.sh
   python3 ./scripts/00-coder/02-pytorch-gpu-check.py
   ```
3. **Connect Local VS Code / Cursor & Stop Idle Workspaces**:
   ```bash
   ./scripts/00-coder/03-coder-cli-and-ssh.sh
   ```

---

### Module 01 — Cluster Exploration & Interactive Pods (`7 min`)
Directory: [`scripts/01-nodes-and-pods/`](scripts/01-nodes-and-pods/)

```bash
# 1. Inspect nodes, identity, and namespace LimitRange defaults
./scripts/01-nodes-and-pods/01-explore-cluster.sh

# 2. Launch a single-container interactive pod, inspect IPv6 address & logs
./scripts/01-nodes-and-pods/02-pod-management.sh

# 3. Launch a multi-container pod (nginx + busybox sidecar sharing localhost)
./scripts/01-nodes-and-pods/03-multi-container-management.sh
```

---

### Module 02 — GPUs, Dynamic Resource Allocation (DRA) & Dynamic MIG (`10 min`)
Directory: [`scripts/02-gpu-pods/`](scripts/02-gpu-pods/)

Berkelium hosts **NVIDIA B300 (275GB)**, **H200 NVL (141GB)**, **H100 (80GB)**, **A100 (80GB)**, **A40 (48GB)**, and **AMD Instinct MI100 (32GB)** accelerators.

```bash
# 1. Discover GPU node models, DRA DeviceClasses, and ResourceSlices
./scripts/02-gpu-pods/01-gpu-discovery.sh

# 2. Run nvidia-smi using classic Extended Resources (nvidia.com/a40: "1")
./scripts/02-gpu-pods/02-nvidia-smi-management.sh

# 3. Allocate a GPU + /dev/shm RAM disk via Kubernetes DRA (ResourceClaimTemplate)
./scripts/02-gpu-pods/03-dra-gpu-management.sh

# 4. Carve an on-demand hardware-isolated Dynamic MIG slice (up to 7 users per GPU!)
./scripts/02-gpu-pods/04-dynamic-mig-management.sh
```

---

### Module 03 — Persistent Ceph Storage & Ephemeral NVMe Scratch (`8 min`)
Directory: [`scripts/03-storage/`](scripts/03-storage/)

```bash
# 1. Inspect ceph-rbd (RWO) and cephfs (RWX) StorageClasses
./scripts/03-storage/01-storage-discovery.sh

# 2. Provision & mount a ReadWriteOnce Ceph RBD block volume (/workspace)
./scripts/03-storage/02-rbd-management.sh

# 3. Provision & mount a ReadWriteMany CephFS shared POSIX volume (/shared-data)
./scripts/03-storage/03-cephfs-management.sh

# 4. Benchmark fast ephemeral node-local NVMe scratch via emptyDir (/scratch)
./scripts/03-storage/05-nvme-scratch-management.sh
```

---

### Module 04 — Web Deployments, Services & Gateway API `HTTPRoute` (`8 min`)
Directory: [`scripts/04-deployments-services-ingresses/`](scripts/04-deployments-services-ingresses/)

```bash
# 1. Deploy and scale a resilient 2-replica HTTP Deployment
./scripts/04-deployments-services-ingresses/01-deployment-management.sh

# 2. Expose via IPv6 ClusterIP Service and test round-robin load balancing
./scripts/04-deployments-services-ingresses/02-service-management.sh

# 3. Attach an HTTPRoute to Berkelium's Envoy Gateway (gateway/ingress) & clean up
./scripts/04-deployments-services-ingresses/03-httproute-management.sh
```

---

### Module 05 — Scientific Batch Jobs & Indexed Parallel Sweeps (`7 min`)
Directory: [`scripts/05-jobs/`](scripts/05-jobs/)

```bash
# 1. Unattended CPU batch Job (runs to completion and exits 0)
./scripts/05-jobs/01-job-management.sh

# 2. Indexed Parallel Parameter Sweep (Slurm job-array equivalent using JOB_COMPLETION_INDEX)
./scripts/05-jobs/02-parallel-job-management.sh

# 3. PyTorch 2.14 + CUDA 13.0 GPU BF16 TFLOPS benchmark batch Job
./scripts/05-jobs/03-gpu-job-management.sh
```

---

### Module 06 — Debugging, Live Metrics & Policy Validation (`8 min`)
Directory: [`scripts/06-debugging/`](scripts/06-debugging/)

```bash
# 1. Diagnose a failing pod via status, events, and timestamped logs
./scripts/06-debugging/01-pod-logs.sh

# 2. Inspect a live pod via kubectl exec and check kubectl top metrics
./scripts/06-debugging/02-pod-exec.sh

# 3. Test Gatekeeper server-side dry-run & audit Berkelium policy violations
./scripts/06-debugging/03-validate-policies.sh
```

---

## Cleanup & Useful Links

Clean up any remaining objects in `training-nov-26` at any time:
```bash
./scripts/cleanup-all.sh
```

- **Berkelium Portal & Docs**: [https://berkelium.scs.lbl.gov](https://berkelium.scs.lbl.gov) ([Documentation](https://berkelium.scs.lbl.gov/docs/))
- **Berkelium Coder (Cloud IDEs)**: [https://coder.bk.lbl.gov](https://coder.bk.lbl.gov)
- **Berkelium AI Agent MCP Server**: `https://berkelium.scs.lbl.gov/mcp` (`get_cluster_rules_and_specs`, `validate_manifest`)
- **Recommended CLI/GUI Tools**: [K9s](https://k9scli.io) (`k9s -n training-nov-26`) and [Radar](https://radarhq.io) (`kubectl radar`)
