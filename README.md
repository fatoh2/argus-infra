# Argus Infrastructure

[![Sanity Checks](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml)
[![CD Deploy](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cd-deploy.yml)
[![Cluster Sanity](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml)

> **GitOps-driven Kubernetes homelab** — Hetzner Cloud → k3s → ArgoCD → Prometheus/Grafana/Loki

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner Cloud (HCLOUD)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Master  │  │  Worker  │  │  Worker  │  │  Worker  │   │
│  │  (k3s)   │  │  (k3s)   │  │  (k3s)   │  │  (k3s)   │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │              │              │              │        │
│       └──────────────┴──────────────┴──────────────┘        │
│                         │                                    │
│                    ┌────┴─────┐                              │
│                    │  ArgoCD  │  (GitOps)                    │
│                    └──────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

## Repository Structure

```
argus-infra/
├── terraform/             # Infrastructure as Code (Hetzner Cloud)
│   ├── modules/           # Reusable Terraform modules
│   │   ├── network/       # VPC, subnet, firewall
│   │   └── server/        # k3s master & worker nodes
│   └── environments/
│       └── homelab/       # Homelab environment config
├── ansible/               # Configuration management
│   ├── playbooks/         # k3s installation, system hardening
│   ├── roles/             # Ansible roles (k3s, monitoring, security)
│   └── inventory/         # Host inventories
├── k8s/                   # Kubernetes manifests (ArgoCD managed)
│   ├── argocd/            # ArgoCD installation + app-of-apps
│   │   ├── apps/          # ArgoCD Application definitions
│   │   └── config/        # ArgoCD configuration
│   ├── ingress/           # Traefik, cert-manager, TLS
│   ├── monitoring/        # Prometheus stack
│   ├── grafana/           # Grafana deployment, dashboards, datasources, ingress
│   ├── databases/         # PostgreSQL, Redis, backup CronJob
│   ├── security/          # Security policies
│   │   ├── network-policies/  # Default deny + explicit allow rules
│   │   ├── pod-security/      # Pod Security Standards (restricted profile)
│   │   └── rbac/              # Least-privilege ServiceAccounts
│   ├── external-secrets/  # External Secrets Operator + Doppler
│   │   ├── helm-repository.yaml
│   │   ├── helm-release.yaml
│   │   ├── secretstore.yaml
│   │   ├── doppler-auth-secret.yaml
│   │   ├── example-external-secret.yaml
│   │   └── kustomization.yaml
│   └── cluster-issuer/    # Let's Encrypt ClusterIssuers
├── scripts/               # Operational and CI scripts
│   ├── run-sanity-checks.sh   # Local sanity suite (Terraform, Ansible, ArgoCD)
│   ├── argocd-health.sh       # ArgoCD app health check
│   └── cluster-sanity.sh      # Full cluster-level sanity checks
├── docs/                  # Documentation
│   ├── cicd.md            # CI/CD pipeline overview
│   ├── architecture.md    # System architecture
│   ├── secrets.md         # Secret management with ESO + Doppler
│   ├── runbooks.md        # Operational runbooks
│   ├── setup.md           # Setup guide
│   └── adr/               # Architecture Decision Records
└── .github/workflows/     # CI/CD pipeline
    ├── sanity-checks.yml  # PR-level Terraform + Ansible validation (CI)
    ├── cd-deploy.yml      # CD pipeline (lint → build → ArgoCD sync)
    └── cluster-sanity.yml # Cluster-level health checks (scheduled, conditionally enabled)
```

## CI/CD Pipeline

Argus Infra uses a three-stage CI/CD pipeline:

1. **Lint** — runs on every PR and merge to `main` (Terraform fmt, Ansible lint, ShellCheck)
2. **Build** — runs on every PR and merge to `main` (Terraform validate + plan, Ansible syntax check, critical file checks)
3. **Deploy** — runs on every merge to `main` (triggers ArgoCD sync)

See [docs/cicd.md](docs/cicd.md) for full pipeline documentation and [docs/runbooks.md](docs/runbooks.md) for operational procedures.

## Key Features

- **Fully GitOps-driven** — all cluster state defined in Git, ArgoCD syncs automatically
- **Automatic TLS** — wildcard certificate via Let's Encrypt + cert-manager
- **Observability out of the box** — Prometheus metrics, Grafana dashboards (Node Exporter Full, Kubernetes Cluster Overview), Loki logs
- **Secure by default** — External Secrets Operator for secrets, private network for nodes
- **Network Policies** — default-deny on all namespaces with explicit allow rules for least-privilege pod communication
- **Pod Security Standards** — restricted profile enforced on all namespaces; workloads configured with `runAsNonRoot`, `readOnlyRootFilesystem`, and dropped capabilities
- **Least-Privilege RBAC** — dedicated ServiceAccounts for each service with minimum required permissions; `api-service` has zero k8s API access
- **CI/CD-validated**
- **Automated Backups** — PostgreSQL backups to S3-compatible storage via CronJob
- **Disaster Recovery** — documented restore procedures in `docs/runbooks.md`
- **Idempotent Provisioning** — Terraform and Ansible ensure consistent, repeatable deployments
- **Scalable** — easily add more worker nodes to the k3s cluster
- **Cost-Optimized** — leverages Hetzner Cloud's affordable VMs

## Quick Start

### Prerequisites

- [Hetzner Cloud](https://www.hetzner.com/cloud) account + API token
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) >= 2.14
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [argocd CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)

### 1. Provision Infrastructure

```bash
cd terraform/environments/homelab
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Hetzner token and SSH key
terraform init
terraform apply
```

### 2. Install k3s

```bash
cd ansible
cp inventory/homelab.yml.example inventory/homelab.yml
# Edit homelab.yml with your server IPs
ansible-playbook -i inventory/homelab.yml playbooks/site.yml
```

### 3. Install ArgoCD

```bash
kubectl apply -f k8s/argocd/install.yaml
```

### 4. Deploy Applications

```bash
kubectl apply -f k8s/argocd/app-of-apps.yaml
```

ArgoCD will automatically sync all applications.

See [docs/setup.md](docs/setup.md) for the complete setup guide.

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | System architecture, component decisions, data flow |
| [Setup Guide](docs/setup.md) | Step-by-step setup from scratch |
| [CI/CD Pipeline](docs/cicd.md) | CI/CD workflow documentation |
| [Runbooks](docs/runbooks.md) | Operational procedures, backup/restore, troubleshooting |
| [Secrets Management](docs/secrets.md) | External Secrets Operator + Doppler setup |
| [ADRs](docs/adr/) | Architecture Decision Records |

## License

MIT
