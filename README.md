# Argus Infra 🚀

[![Sanity Checks](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/sanity-checks.yml)
[![Cluster Sanity](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml/badge.svg)](https://github.com/fatoh2/argus-infra/actions/workflows/cluster-sanity.yml)

**A production-grade Kubernetes homelab platform on Hetzner Cloud** — provisioned with Terraform, configured with Ansible, and managed via GitOps with ArgoCD.

## Overview

Argus Infra provides a complete, reproducible Kubernetes cluster running on Hetzner Cloud VMs. Everything is defined as code:

| Layer | Tool | Purpose |
|-------|------|---------|
| **Infrastructure** | Terraform | Provision Hetzner VMs, networks, SSH keys |
| **Configuration** | Ansible | Install k3s, configure nodes, firewall rules |
| **GitOps** | ArgoCD | Declarative app deployment, self-healing |
| **Ingress** | Traefik + cert-manager | HTTP routing, automatic TLS via Let's Encrypt |
| **Monitoring** | Prometheus + Grafana + Loki | Metrics, dashboards, log aggregation |
| **Secrets** | External Secrets Operator + Doppler | Secure secret injection |
| **Security** | Kubernetes NetworkPolicies | Least-privilege pod network access (default deny) |

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
│   ├── grafana/            # Grafana dashboards & provisioning
│   ├── security/           # Security policies (NetworkPolicies)
│   │   └── network-policies/  # Default deny + explicit allow rules
│   └── cluster-issuer/     # Let's Encrypt ClusterIssuers
├── scripts/                # Operational and CI scripts
│   ├── run-sanity-checks.sh   # Local sanity suite (Terraform, Ansible, ArgoCD)
│   ├── argocd-health.sh       # ArgoCD app health check
│   └── cluster-sanity.sh      # Full cluster-level sanity checks
├── docs/                   # Documentation
│   ├── architecture.md     # System architecture
│   ├── setup.md            # Setup guide
│   └── adr/                # Architecture Decision Records
└── .github/workflows/      # CI pipeline
    ├── sanity-checks.yml   # PR-level Terraform + Ansible validation
    └── cluster-sanity.yml  # Cluster-level health checks (scheduled)
```

## Key Features

- **Fully GitOps-driven** — all cluster state defined in Git, ArgoCD syncs automatically
- **Automatic TLS** — wildcard certificate via Let's Encrypt + cert-manager
- **Observability out of the box** — Prometheus metrics, Grafana dashboards, Loki logs
- **Secure by default** — External Secrets Operator for secrets, private network for nodes
- **Network Policies** — default-deny on all namespaces with explicit allow rules for least-privilege pod communication
- **CI-validated** — Terraform validate + fmt, Ansible syntax check + lint, ShellCheck, critical file checks on every PR
- **Cluster health monitoring** — scheduled cluster sanity checks (nodes, pods, ArgoCD apps, ingress) every 6 hours
- **Local sanity suite** — run `./scripts/run-sanity-checks.sh` before committing to catch issues early

## Architecture

See [docs/architecture.md](docs/architecture.md) for a detailed breakdown of all components.

## Prerequisites

- [Hetzner Cloud](https://www.hetzner.com/cloud) account with API token
- [Terraform](https://developer.hashicorp.com/terraform/downloads) v1.0+
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) v2.10+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## License

MIT
