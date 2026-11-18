terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.18"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
  }
}

provider "coder" {}

variable "use_kubeconfig" {
  type        = bool
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces. A valid "~/.kube/config" must be present on the Coder host.
  EOF
  default     = false
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder"
}

data "coder_parameter" "cpu" {
  order        = 1
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "The number of CPU cores allocated to the workspace"
  default      = "2"
  type         = "number"
  form_type    = "slider"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 1
    max = 16
  }
}

data "coder_parameter" "memory" {
  order        = 2
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "The amount of RAM in GB allocated to the workspace"
  default      = "4"
  type         = "number"
  form_type    = "slider"
  icon         = "/icon/memory.svg"
  mutable      = true
  validation {
    min = 2
    max = 32
  }
}

data "coder_parameter" "home_disk_size" {
  order        = 3
  name         = "home_disk_size"
  display_name = "Home Disk Size (GB)"
  description  = "Persistent storage size for /home/coder (manifests, scripts, ~/.kube) in GB"
  default      = "10"
  type         = "number"
  form_type    = "slider"
  icon         = "/emojis/1f4be.png"
  mutable      = false
  validation {
    min = 5
    max = 100
  }
}

data "coder_parameter" "git_repo" {
  order        = 4
  name         = "git_repo"
  display_name = "Git Repository URL (Clear to skip)"
  description  = "Git repository to clone into /home/coder/<repo-name> on first startup (pre-filled for the Berkelium Workshop)"
  type         = "string"
  default      = "https://github.com/lbnl-science-it/berkelium-training-nov-26.git"
  mutable      = true
  icon         = "/icon/git.svg"
  styling = jsonencode({
    placeholder = "https://github.com/organization/repository.git"
  })
}

data "coder_parameter" "dotfiles_url" {
  order        = 5
  name         = "dotfiles_url"
  display_name = "Dotfiles Git URL (Optional)"
  description  = "Personalize your workspace with a Git repository of dotfiles"
  type         = "string"
  default      = ""
  mutable      = true
  icon         = "/icon/git.svg"
  styling = jsonencode({
    placeholder = "https://github.com/username/dotfiles"
  })
}

locals {
  clean_repo    = trimsuffix(trimsuffix(trimspace(data.coder_parameter.git_repo.value), "/"), ".git")
  repo_dir_name = local.clean_repo != "" ? basename(local.clean_repo) : ""
  open_folder   = local.repo_dir_name != "" ? "/home/coder/${local.repo_dir_name}" : "/home/coder"
}

provider "kubernetes" {
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}

data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = local.open_folder

  display_apps {
    vscode                 = true
    vscode_insiders        = false
    web_terminal           = true
    ssh_helper             = true
    port_forwarding_helper = true
  }

  startup_script = <<-EOT
    set -e

    # Ensure /home/coder itself is owned by coder:coder (fresh Ceph RBD mounts start as root:coder)
    sudo -n chown coder:coder "$${HOME}" 2>/dev/null || true

    # Seed skeleton shell files when a fresh Ceph RBD PVC is mounted on /home/coder
    for f in .bashrc .profile .bash_logout; do
      if [ ! -f "$${HOME}/$${f}" ] && [ -f "/etc/skel/$${f}" ]; then
        cp "/etc/skel/$${f}" "$${HOME}/$${f}"
      fi
    done

    # Configure concise path-only shell prompt (before optional user dotfiles)
    if ! grep -q '# berkelium-short-prompt' "$${HOME}/.bashrc" 2>/dev/null; then
      cat >> "$${HOME}/.bashrc" << 'EOF'
# berkelium-short-prompt
case $- in
  *i*) PS1='\[\033[01;34m\]\w\[\033[00m\] \$ ' ;;
esac
EOF
    fi

    mkdir -p "$${HOME}/.local/bin" "$${HOME}/.kube"
    mkdir -p "$${HOME}/.local/share/code-server/User" "$${HOME}/.config/code-server"
    if [ ! -f "$${HOME}/.local/share/code-server/User/settings.json" ]; then
      cat > "$${HOME}/.local/share/code-server/User/settings.json" << 'EOF'
{
  "security.workspace.trust.enabled": false,
  "git.openDiffOnClick": false,
  "vs-kubernetes": {
    "vs-kubernetes.crd-code-completion": "disabled",
    "vs-kubernetes.suppress-kubeconfig-not-found-alerts": true,
    "vs-kubernetes.ignore-recommendations": true
  }
}
EOF
    fi

    export PATH="$${HOME}/.local/bin:$${PATH}"
    if ! grep -q 'HOME/.local/bin' "$${HOME}/.bashrc" 2>/dev/null; then
      cat >> "$${HOME}/.bashrc" << 'EOF'
export PATH="$HOME/.local/bin:$PATH"
if command -v kubectl >/dev/null 2>&1; then
  alias k=kubectl
  source <(kubectl completion bash) 2>/dev/null || true
  complete -o default -F __start_kubectl k 2>/dev/null || true
fi
EOF
    fi
    if ! grep -q 'HOME/.local/bin' "$${HOME}/.profile" 2>/dev/null; then
      cat >> "$${HOME}/.profile" << 'EOF'
if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"
EOF
    fi

    # Ensure python3 is present for interactive workshop labs & CLI scripts
    if ! command -v python3 >/dev/null 2>&1; then
      sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 >/dev/null 2>&1 || true
    fi

    # Ensure code-server defaults prevent read-only Git diff, Workspace Trust, & CRD slow-fetch popups
    python3 -c '
import json, os
p = os.path.expanduser("~/.local/share/code-server/User/settings.json")
try:
    d = json.load(open(p)) if os.path.exists(p) else {}
except Exception:
    d = {}
changed = False
for k, v in [("security.workspace.trust.enabled", False), ("git.openDiffOnClick", False)]:
    if k not in d:
        d[k] = v
        changed = True
vsk = d.get("vs-kubernetes")
if not isinstance(vsk, dict):
    vsk = {}
    d["vs-kubernetes"] = vsk
    changed = True
for k, v in [
    ("vs-kubernetes.crd-code-completion", "disabled"),
    ("vs-kubernetes.suppress-kubeconfig-not-found-alerts", True),
    ("vs-kubernetes.ignore-recommendations", True),
]:
    if k not in vsk:
        vsk[k] = v
        changed = True
if changed or not os.path.exists(p):
    with open(p, "w") as f:
        json.dump(d, f, indent=2)
' 2>/dev/null || true

    # Install Kubernetes CLI suite synchronously in parallel (~2-3s on first boot; cached on PVC thereafter)
    (
      if [ ! -x "$${HOME}/.local/bin/kubectl" ]; then
        KUBE_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -fsSL -o "$${HOME}/.local/bin/kubectl" "https://dl.k8s.io/release/$${KUBE_VER}/bin/linux/amd64/kubectl" && chmod +x "$${HOME}/.local/bin/kubectl" || true
      fi
    ) &
    (
      if [ ! -x "$${HOME}/.local/bin/helm" ]; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | USE_SUDO=false HELM_INSTALL_DIR="$${HOME}/.local/bin" bash >/dev/null 2>&1 || true
      fi
    ) &
    (
      if [ ! -x "$${HOME}/.local/bin/k9s" ]; then
        curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar -xz -C "$${HOME}/.local/bin" k9s 2>/dev/null || true
      fi
    ) &
    (
      if [ ! -x "$${HOME}/.local/bin/kubectl-radar" ]; then
        curl -fsSL https://get.radarhq.io | INSTALL_DIR="$${HOME}/.local/bin" sh >/dev/null 2>&1 || true
      fi
    ) &
    (
      if [ ! -x "$${HOME}/.local/bin/uv" ]; then
        curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 sh >/dev/null 2>&1 || true
      fi
    ) &
    wait

    for bin in kubectl helm k9s kubectl-radar radar uv uvx; do
      if [ -x "$${HOME}/.local/bin/$${bin}" ]; then
        sudo -n ln -sf "$${HOME}/.local/bin/$${bin}" "/usr/local/bin/$${bin}" 2>/dev/null || true
      fi
    done

    # Clone optional Git repository into ~/<repo-name> before launching code-server so folder exists immediately
    if [ -n "${local.repo_dir_name}" ]; then
      REPO_DIR="$${HOME}/${local.repo_dir_name}"
      if [ ! -d "$${REPO_DIR}" ]; then
        git clone "${trimspace(data.coder_parameter.git_repo.value)}" "$${REPO_DIR}" || true
      fi
      # Auto-start Berkelium Interactive Quest Lab web app (:8080) when ./lab is present
      if [ -f "$${REPO_DIR}/lab" ]; then
        nohup python3 "$${REPO_DIR}/lab" --web >/tmp/lab-web.log 2>&1 </dev/null &
      fi
    fi

    # Install and start code-server on fast local NVMe (/tmp); extensions persist in ~/.local/share/code-server
    echo "Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.140.0
    nohup /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 </dev/null &

    # Install lightweight CLI utilities and YAML/Kubernetes VS Code support in background
    (
      if ! command -v jq >/dev/null 2>&1 || ! command -v rg >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
          jq ripgrep fd-find fzf tmux btop bash-completion >/dev/null 2>&1 || true
      fi
      /tmp/code-server/bin/code-server --install-extension redhat.vscode-yaml >/dev/null 2>&1 || true
      /tmp/code-server/bin/code-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools >/dev/null 2>&1 || true
    ) >/tmp/k8s-cli-tools.log 2>&1 </dev/null &

    # Apply dotfiles if specified
    if [ -n "${data.coder_parameter.dotfiles_url.value}" ]; then
      coder dotfiles -y "${data.coder_parameter.dotfiles_url.value}" || true
    fi
  EOT

  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "2_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "K8s Context"
    key          = "3_k8s_context"
    script       = "kubectl config current-context 2>/dev/null || echo 'Not set (open Quest Lab or ./setup.sh)'"
    interval     = 15
    timeout      = 2
  }
}

resource "coder_app" "quest-lab" {
  count        = local.repo_dir_name != "" ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "quest-lab"
  display_name = "Quest Lab"
  icon         = "/icon/k8s.svg"
  url          = "http://localhost:8080"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:8080/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=${local.open_folder}"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  wait_until_bound = false
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "ceph-rbd"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }

  lifecycle {
    ignore_changes = [metadata, spec[0].resources[0].requests["storage"]]
  }
}

resource "kubernetes_pod" "main" {
  timeouts {
    create = "20m"
  }
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${lower(data.coder_workspace_owner.me.name)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      "com.coder.resource"         = "true"
      "com.coder.workspace.id"     = data.coder_workspace.me.id
      "com.coder.workspace.name"   = data.coder_workspace.me.name
      "com.coder.user.id"          = data.coder_workspace_owner.me.id
      "com.coder.user.username"    = data.coder_workspace_owner.me.name
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace_owner.me.email
    }
  }
  spec {
    hostname = coalesce(trim(substr(replace(lower(data.coder_workspace.me.name), "/[^a-z0-9-]/", "-"), 0, 63), "-"), "workspace")
    security_context {
      run_as_user            = "1000"
      fs_group               = "1000"
      fs_group_change_policy = "OnRootMismatch"
    }
    container {
      name              = "dev"
      image             = "codercom/enterprise-base:ubuntu-20261019"
      image_pull_policy = "IfNotPresent"
      command           = ["sh", "-c", coder_agent.main.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "CODER_WORKSPACE_OWNER_NAME"
        value = data.coder_workspace_owner.me.name
      }
      resources {
        requests = {
          "cpu"    = "250m"
          "memory" = "512Mi"
        }
        limits = {
          "cpu"    = "${data.coder_parameter.cpu.value}"
          "memory" = "${data.coder_parameter.memory.value}Gi"
        }
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    affinity {
      pod_anti_affinity {
        preferred_during_scheduling_ignored_during_execution {
          weight = 1
          pod_affinity_term {
            topology_key = "kubernetes.io/hostname"
            label_selector {
              match_expressions {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["coder-workspace"]
              }
            }
          }
        }
      }
    }
  }
}
