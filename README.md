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

See the [GCP module documentation](docs/architecture.md#15-gcp-compute-engine-module) for full details.

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

See the [GKE module documentation](docs/architecture.md#16-gcp-gke-module) for full details.

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

See the [AWS EC2 module documentation](docs/architecture.md#17-aws-ec2-module) for full details.

## Makefile Targets

The project includes a `Makefile` with common infra operations. Run `make` or `make help` to see all targets:

| Target | Description | Requires |
|--------|-------------|----------|
| `make lint` | Terraform fmt -check + ansible-lint + shellcheck | Installed tools |
| `make validate` | Terraform init (no backend) + validate | Terraform |
| `make plan` | Terraform plan (targets module.network) | `HCLOUD_TOKEN` env var |
| `make install-tools` | Install CLI tools (Terraform, Ansible, kubectl, etc.) | sudo access |
| `make local-up` | Create k3d cluster with ArgoCD, Prometheus, Loki | k3d, Helm |
| `make local-down` | Destroy k3d cluster | k3d |
| `make check-versions` | Show installed tool versions | Installed tools |

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
├── scripts/                  # Utility scripts
│   ├── install-tools.sh      # Automated CLI tool installation
│   └── versions.sh           # Tool version checker
├── docs/                     # Documentation
│   ├── setup.md              # Full setup guide
│   └── architecture.md       # Architecture documentation
├── Makefile                  # Common operations
└── README.md                 # This file
```

## CI/CD

The repository uses GitHub Actions for CI/CD:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **Sanity Checks** | PRs to develop/main | Terraform fmt, validate, Ansible syntax check, shellcheck |
| **Cluster Sanity** | PRs to develop/main | k3d cluster creation, ArgoCD bootstrap, app deployment test |
| **CD Deploy** | Push to main | Apply Terraform, run Ansible, sync ArgoCD apps |

## License

MIT
