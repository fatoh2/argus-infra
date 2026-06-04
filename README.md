# Argus Infra 🚀

[![Sanity Checks](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml)
[![Cluster Sanity](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml)
[![CD Deploy](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml)

**A production-grade Kubernetes homelab platform** — provisioned with Terraform (Hetzner Cloud / GCP Compute Engine / GKE / AWS EC2), configured with Ansible, and managed via GitOps with ArgoCD.

## Overview

Argus Infra provides a complete, reproducible Kubernetes cluster running on Hetzner Cloud VMs, a single VM on GCP Compute Engine or AWS EC2, or a managed GKE cluster on Google Cloud. Everything is defined as code:

| Layer | Tool | Purpose |
|-------|------|---------|
| **Infrastructure** | Terraform | Provision Hetzner VMs, GCP Compute Engine VMs, GKE clusters, AWS EC2 instances, networks, SSH keys |
| **Configuration** | Ansible | Install k3s, configure nodes, firewall rules |
| **GitOps** | ArgoCD | Declarative app deployment, self-healing |
| **Ingress** | Traefik + cert-manager | HTTP routing, automatic TLS via Let's Encrypt |
| **Monitoring** | Prometheus + Grafana + Loki | Metrics, dashboards (Node Exporter Full, Cluster Overview), log aggregation |
| **Secrets** | External Secrets Operator + Doppler | Secure secret injection |
| **Network Policies** | Kubernetes NetworkPolicies | Least-privilege pod network access (default deny) |
| **Pod Security** | Kubernetes Pod Security Standards | Restricted profile enforcement on all namespaces |

## Quick Start

### Local Development (k3d)

For local testing without Hetzner Cloud VMs, spin up a k3d cluster:

```bash
# 0. Install required CLI tools
make install-tools

# 1. Create local cluster with ArgoCD, Prometheus, and Loki
make local-up

# 2. Tear down when done
make local-down
```

### Windows

For Windows development, see the [Windows Setup Guide](SETUP_WINDOWS.md).

```bash
# 0. Run the bootstrap script (Git Bash or WSL2) to check prerequisites
bash BOOTSTRAP_WINDOWS.sh

# 1. Install required CLI tools
make install-tools

# 2. Create local cluster with ArgoCD, Prometheus, and Loki
make local-up

# 3. Tear down when done
make local-down
```

> **Note:** On Windows, use **Git Bash** (not Command Prompt or PowerShell) for shell commands.
> Docker Desktop with WSL2 backend is required for k3d clusters.
> See [SETUP_WINDOWS.md](SETUP_WINDOWS.md) for detailed Windows setup instructions.

### Production (Hetzner Cloud)

```bash
# 0. Install required CLI tools (Terraform, Ansible, kubectl, Helm, ArgoCD, k3d, kubeseal)
make install-tools

# 1. Provision VMs
cd terraform/environments/homelab
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Hetzner token
terraform init && terraform apply

# 2. Install k3s
cd ansible
cp inventory/homelab.yml.example inventory/homelab.yml
# Edit inventory with VM IPs from terraform output
ansible-playbook -i inventory/homelab.yml playbooks/site.yml

# 3. Bootstrap ArgoCD
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

See the [full setup guide](docs/setup.md) for detailed instructions.

### Single VM (GCP Compute Engine)

For lightweight deployments or testing on Google Cloud Platform:

```bash
# 0. Install required CLI tools
make install-tools

# 1. Provision a single VM with Docker
cd terraform/environments/gcp-single-vm
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and SSH public key
terraform init && terraform apply

# 2. Connect via SSH
ssh argus@$(terraform output -raw public_ip)

# 3. Verify Docker is running
ssh argus@$(terraform output -raw public_ip) "docker --version && docker compose version"
```

See the [GCP module documentation](docs/architecture.md#16-gcp-compute-engine-module) for full details.

### Managed Kubernetes (GCP GKE)

For a fully managed Kubernetes cluster on Google Cloud Platform with Autopilot mode:

```bash
# 0. Install required CLI tools
make install-tools

# 1. Provision a GKE cluster
cd terraform/environments/gcp-gke
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID
terraform init && terraform apply

# 2. Configure kubectl
gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region=us-central1

# 3. Verify cluster is ready
kubectl get nodes
```

> **Tip:** The module also generates a kubeconfig file at `$(terraform output -raw kubeconfig_path)` when `generate_kubeconfig` is enabled (default: `true`).

See the [GKE module documentation](docs/architecture.md#17-gcp-gke-module) for full details.

### Single VM (AWS EC2)

For lightweight deployments or testing on Amazon Web Services:

```bash
# 0. Install required CLI tools
make install-tools

# 1. Provision a single EC2 instance with Docker
cd terraform/environments/aws-single-vm
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS region and SSH public key
terraform init && terraform apply

# 2. Connect via SSH
ssh argus@$(terraform output -raw public_ip)

# 3. Verify Docker is running
ssh argus@$(terraform output -raw public_ip) "docker --version && docker compose version"
```

See the [AWS EC2 module documentation](docs/architecture.md#18-aws-ec2-module) for full details.

## Makefile Targets

The project includes a `Makefile` with common infra operations. Run `make` or `make help` to see all targets:

| Target | Description | Requires |
|--------|-------------|----------|
| `make lint` | Terraform fmt -check + ansible-lint + shellcheck | Installed tools |
| `make validate` | Terraform init (no backend) + validate | Terraform |
| `make plan` | Terraform plan (targets module.network) | `HCLOUD_TOKEN` env var |
| `make install-tools` | Install CLI tools (Terraform, Ansible, kubectl, etc.) | sudo access |
| `make local-up` | Spin up local k3d cluster for testing | k3d |
| `make local-down` | Tear down local k3d cluster | k3d |
| `make setup-windows` | Show Windows setup guide and Docker Desktop instructions | — |
| `make bootstrap` | Run Windows bootstrap script (checks prerequisites) | Git Bash / WSL2 |
| `make check-versions` | Print installed tool versions | — |
| `make sanity` | Run full local sanity check suite | Installed tools |
| `make test-scripts-dry` | Static checks: bash -n + shellcheck (fast, no Docker) | bash, shellcheck or Docker |
| `make test-scripts` | Full script test in clean Docker container (must pass before PR) | Docker |

## Repository Structure

See the [CI/CD Pipeline documentation](docs/cicd.md) for details on how changes are validated and deployed.

```
argus-infra/
├── Makefile                 # Common infra operations (lint, validate, plan, etc.)
├── terraform/               # Infrastructure provisioning
│   ├── environments/homelab/       # Hetzner Cloud (k3s cluster)
│   ├── environments/gcp-single-vm/ # GCP Compute Engine (single VM)
│   ├── environments/gcp-gke/         # GCP GKE (managed Kubernetes cluster)
│   ├── environments/aws-single-vm/      # AWS EC2 (single VM)
│   ├── modules/gcp-compute-engine/   # GCP VM Terraform module
│   ├── modules/gcp-gke/              # GCP GKE Terraform module
│   └── modules/aws-ec2/              # AWS EC2 Terraform module
├── ansible/                 # k3s cluster configuration
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── k8s/                     # Kubernetes manifests (source of truth)
│   ├── argocd/              # ArgoCD app-of-apps definitions
│   │   ├── apps/            # Individual application manifests
│   │   └── config/          # ArgoCD configuration
│   ├── ingress/             # Traefik, cert-manager, TLS
│   ├── monitoring/          # Prometheus stack
│   ├── grafana/             # Grafana deployment, dashboards, datasources, ingress
│   ├── security/            # Security policies
│   │   ├── network-policies/   # Default deny + explicit allow rules
│   │   ├── pod-security/       # Pod Security Standards (restricted profile)
│   │   └── rbac/               # Least-privilege ServiceAccounts
│   └── cluster-issuer/      # Let's Encrypt ClusterIssuers
├── BOOTSTRAP_WINDOWS.sh      # Windows bootstrap — checks Docker, kubectl, k3d, helm prerequisites
├── SETUP_WINDOWS.md           # Windows setup guide (Docker Desktop, WSL2, Chocolatey)
├── scripts/                   # Operational and CI scripts
│   ├── install-tools.sh        # One-command tool installation (Terraform, Ansible, kubectl, Helm, ArgoCD, k3d, kubeseal)
│   ├── versions.sh             # Print all tool versions for debugging
│   ├── run-sanity-checks.sh    # Local sanity suite (Terraform, Ansible, ArgoCD)
│   ├── argocd-health.sh        # ArgoCD app health check
│   ├── local-cluster.sh        # Spin up local k3d cluster for testing
│   ├── local-cluster-down.sh   # Tear down local k3d cluster
│   └── cluster-sanity.sh       # Full cluster-level sanity checks
├── docs/                    # Documentation
│   ├── cicd.md              # CI/CD pipeline overview
│   ├── architecture.md      # System architecture
│   ├── runbooks.md          # Operational runbooks
│   ├── setup.md             # Setup guide
│   ├── adr/                 # Architecture Decision Records
│   └── secrets.md             # Secrets management
└── .github/workflows/       # CI/CD pipeline
    ├── sanity-checks.yml    # PR-level Terraform + Ansible validation (CI)
    ├── cd-deploy.yml        # CD pipeline (lint → build → deploy, path-filtered)
    └── cluster-sanity.yml   # Cluster-level health checks (scheduled, conditionally enabled)
```

## CI/CD Pipeline

Argus Infra uses a three-stage CI/CD pipeline:

1. **Lint** — runs on every PR and merge to `main` (Terraform fmt, Ansible lint, ShellCheck)
2. **Build** — runs on every PR and merge to `main` (Terraform validate + plan, Ansible syntax check, critical file checks)
3. **Deploy** — runs only on infrastructure-relevant merges to `main` (path-filtered: `terraform/**`, `ansible/**`, `k8s/**`, `scripts/**`, `.github/workflows/cd-deploy.yml`); docs-only pushes are skipped automatically

See [docs/cicd.md](docs/cicd.md) for full pipeline documentation and [docs/runbooks.md](docs/runbooks.md) for operational procedures.

## Key Features

- **Fully GitOps-driven** — all cluster state defined in Git, ArgoCD syncs automatically
- **Automatic TLS** — wildcard certificate via Let's Encrypt + cert-manager
- **Observability out of the box** — Prometheus metrics, Grafana dashboards (Node Exporter Full, Kubernetes Cluster Overview), Loki logs
- **Secure by default** — External Secrets Operator + Doppler for secret injection, NetworkPolicies for least-privilege access, Pod Security Standards (restricted profile)
- **Makefile-driven workflow** — `make lint`, `make validate`, `make plan`, `make install-tools`, `make local-up/down, make setup-windows, make bootstrap`, `make check-versions`, `make sanity`
- **Local development** — k3d cluster for testing without cloud costs
- **Multi-cloud support** — Hetzner Cloud (k3s cluster), GCP Compute Engine (single VM), GCP GKE (managed Kubernetes), and AWS EC2 (single VM) deployment options
- **Automated CI/CD** — GitHub Actions validate every PR and deploy on merge to `main`
- **Architecture Decision Records** — all significant decisions documented in `docs/adr/`
