# Argus Infra 🚀

[![Sanity Checks](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml)
[![Cluster Sanity](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml)
[![CD Deploy](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml)

**A production-grade Kubernetes homelab platform on Hetzner Cloud** — provisioned with Terraform, configured with Ansible, and managed via GitOps with ArgoCD.

## Overview

Argus Infra provides a complete, reproducible Kubernetes cluster running on Hetzner Cloud VMs. Everything is defined as code:

| Layer | Tool | Purpose |
|-------|------|---------|
| **Infrastructure** | Terraform | Provision Hetzner VMs, networks, SSH keys |
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
| `make check-versions` | Print installed tool versions | — |
| `make sanity` | Run full local sanity check suite | Installed tools |

## Repository Structure

See the [CI/CD Pipeline documentation](docs/cicd.md) for details on how changes are validated and deployed.

```
argus-infra/
├── Makefile                 # Common infra operations (lint, validate, plan, etc.)
├── terraform/               # Hetzner Cloud provisioning
│   └── environments/homelab/
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
├── scripts/                 # Operational and CI scripts
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
│   └── adr/                 # Architecture Decision Records
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
- **Makefile-driven workflow** — `make lint`, `make validate`, `make plan`, `make install-tools`, `make local-up/down`, `make check-versions`, `make sanity`
- **Local development** — k3d cluster for testing without Hetzner Cloud costs
- **Automated CI/CD** — GitHub Actions validate every PR and deploy on merge to `main`
- **Architecture Decision Records** — all significant decisions documented in `docs/adr/`
