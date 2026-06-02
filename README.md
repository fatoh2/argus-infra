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

```bash
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

## Repository Structure

See the [CI/CD Pipeline documentation](docs/cicd.md) for details on how changes are validated and deployed.

```
argus-infra/
├── terraform/              # Hetzner Cloud provisioning
│   └── environments/homelab/
├── ansible/                # k3s cluster configuration
│   ├── inventory/
│   ├── playbooks/
│   └── roles/
├── k8s/                    # Kubernetes manifests (source of truth)
│   ├── argocd/             # ArgoCD app-of-apps definitions
│   │   ├── apps/           # Individual application manifests
│   │   └── config/         # ArgoCD configuration
│   ├── ingress/            # Traefik, cert-manager, TLS
│   ├── monitoring/         # Prometheus stack
│   ├── grafana/            # Grafana deployment, dashboards, datasources, ingress
│   ├── security/           # Security policies
│   │   ├── network-policies/  # Default deny + explicit allow rules
│   │   ├── pod-security/      # Pod Security Standards (restricted profile)
│   │   └── rbac/              # Least-privilege ServiceAccounts
│   └── cluster-issuer/     # Let's Encrypt ClusterIssuers
├── scripts/                # Operational and CI scripts
│   ├── run-sanity-checks.sh   # Local sanity suite (Terraform, Ansible, ArgoCD)
│   ├── argocd-health.sh       # ArgoCD app health check
│   └── cluster-sanity.sh      # Full cluster-level sanity checks
├── docs/                   # Documentation
│   ├── cicd.md             # CI/CD pipeline overview
│   ├── architecture.md     # System architecture
│   ├── runbooks.md         # Operational runbooks
│   ├── setup.md            # Setup guide
│   └── adr/                # Architecture Decision Records
└── .github/workflows/      # CI/CD pipeline
    ├── sanity-checks.yml   # PR-level Terraform + Ansible validation (CI)
    ├── cd-deploy.yml       # CD pipeline (lint → build → ArgoCD sync)
    └── cluster-sanity.yml  # Cluster-level health checks (scheduled)
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
- **Automated Backups** — PostgreSQL backups to Backblaze B2 via pgbackrest
- **Disaster Recovery** — documented restore procedures in `docs/runbooks.md`
- **Idempotent Provisioning** — Terraform and Ansible ensure consistent, repeatable deployments
- **Scalable** — easily add more worker nodes to the k3s cluster
- **Cost-Optimized** — leverages Hetzner Cloud's affordable VMs
