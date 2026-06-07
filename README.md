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
| `make help` | Print all available targets | — |
| `make lint` | Terraform fmt -check + ansible-lint + shellcheck | Installed tools (skips gracefully if missing) |
| `make validate` | Terraform init (no backend) + validate | Terraform |
| `make plan` | Terraform plan (targets module.network) | `HCLOUD_TOKEN` env var |
| `make install-tools` | Install CLI tools (Terraform, Ansible, kubectl, k3d, etc.) | sudo access |
| `make local-up` | Spin up local k3d cluster for testing | k3d |
| `make local-down` | Tear down local k3d cluster | k3d |
| `make setup-windows` | Show Windows setup guide and Docker Desktop instructions | — |
| `make bootstrap` | Run Windows bootstrap script (checks prerequisites) | Git Bash / WSL2 |
| `make check-versions` | Print installed tool versions | — |
| `make sanity` | Run full local sanity check suite | Installed tools |
| `make test-scripts-dry` | Static checks: bash -n + shellcheck (fast, no Docker) | bash, shellcheck or Docker |
| `make test-scripts` | Full script test in clean Docker container (must pass before PR) | Docker |

> All targets gracefully skip missing tools. Run `make` (or `make help`) to see the full list.

## Repository Structure

```
argus-infra/
├── ansible/                  # Ansible playbooks for k3s setup
│   ├── playbooks/
│   │   └── site.yml          # Main playbook (k3s install + config)
│   ├── roles/                # Ansible roles
│   │   ├── k3s/              # k3s installation role
│   │   └── common/           # Common system configuration
│   └── inventory/            # Ansible inventories
├── terraform/                # Terraform configurations
│   ├── modules/              # Reusable Terraform modules
│   │   ├── network/          # Hetzner network module
│   │   ├── server/           # Hetzner server module
│   │   ├── gcp-single-vm/    # GCP Compute Engine module
│   │   ├── gcp-gke/          # GCP GKE module
│   │   └── aws-single-vm/    # AWS EC2 module
│   └── environments/         # Environment-specific configs
│       ├── homelab/          # Hetzner homelab environment
│       ├── gcp-single-vm/    # GCP single VM environment
│       ├── gcp-gke/          # GCP GKE environment
│       └── aws-single-vm/    # AWS EC2 environment
├── k8s/                      # Kubernetes manifests (ArgoCD apps)
│   ├── argocd/               # ArgoCD installation + config
│   ├── monitoring/           # Prometheus, Grafana, Loki
│   ├── ingress/              # Traefik, cert-manager
│   └── system/               # System components (secrets, policies)
├── scripts/                  # Operational and CI scripts
│   ├── install-tools.sh      # One-command tool installation (Terraform, Ansible, kubectl, Helm, ArgoCD, k3d, kubeseal)
│   ├── versions.sh           # Print all tool versions for debugging
│   ├── run-sanity-checks.sh  # Local sanity suite (Terraform, Ansible, ArgoCD)
│   ├── argocd-health.sh      # ArgoCD app health check
│   ├── cluster-sanity.sh     # Full cluster-level sanity checks
│   ├── bootstrap-argocd.sh   # ArgoCD bootstrap helper
│   └── setup-agent.sh        # Agent setup script
├── docs/                     # Documentation
│   ├── setup.md              # Full setup guide
│   ├── architecture.md       # System architecture
│   ├── runbooks.md           # Operational runbooks
│   ├── cicd.md               # CI/CD pipeline overview
│   ├── secrets.md            # Secrets management
│   └── adr/                  # Architecture Decision Records
├── Makefile                  # Common operations
└── README.md                 # This file
```

## CI/CD Pipeline

Argus Infra uses a three-stage CI/CD pipeline:

1. **Lint** — runs on every PR and merge to `main` (Terraform fmt, Ansible lint, ShellCheck)
2. **Build** — runs on every PR and merge to `main` (Terraform validate + plan, Ansible syntax check, critical file checks)
3. **Deploy** — runs only on infrastructure-relevant merges to `main` (path-filtered); docs-only pushes are skipped automatically

See [docs/cicd.md](docs/cicd.md) for full pipeline documentation and [docs/runbooks.md](docs/runbooks.md) for operational procedures.

## License

MIT
