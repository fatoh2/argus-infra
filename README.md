# Argus Infra

## Project Overview

Argus Infra is the foundational Kubernetes homelab platform for the Argus project. It provides the infrastructure layer for deploying and managing our blockchain monitoring SaaS (`argus-monitor`) and AI infrastructure assistant (`argus-ai`).

This repository uses Infrastructure as Code (IaC) principles to provision and manage a highly available, self-healing Kubernetes cluster on Hetzner Cloud.

## What it Does

-   **Automated VM Provisioning:** Uses Terraform to provision virtual machines on Hetzner Cloud.
-   **Kubernetes Cluster Setup:** Deploys a lightweight k3s Kubernetes cluster across the provisioned VMs using Ansible.
-   **GitOps Management:** Leverages ArgoCD for declarative, GitOps-driven application deployment and cluster state management.
-   **Observability:** Integrates Prometheus for monitoring and alerting (future work).

## Tech Stack

-   **Cloud Provider:** Hetzner Cloud
-   **Infrastructure as Code:** Terraform / OpenTofu
-   **Configuration Management:** Ansible
-   **Kubernetes Distribution:** k3s
-   **GitOps:** ArgoCD
-   **Monitoring:** Prometheus (future)

## Architecture Diagram (Conceptual)

```
+---------------------+       +---------------------+
| Hetzner Cloud       |       | GitHub              |
|                     |       | (argus-infra repo)  |
| +-----------------+ |       |                     |
| | Private Network | |       | +-----------------+ |
| | 10.0.1.0/24     | |       | | GitOps Repo     | |
| |                 | |       | | (k8s manifests) | |
| | +-------------+ | |       | +--------^--------+ |
| | | k8s-control |<----+-----+----------|-----------+
| | | (k3s server)| | |       |          | ArgoCD
| | +-------------+ | |       |          | Sync
| |       |         | |       |          v
| | +-------------+ | |       | +-----------------+ |
| | | k8s-worker-1|<----+-----+ | ArgoCD          | |
| | | (k3s agent) | | |       | | (running in k8s)| |
| | +-------------+ | |       | +-----------------+ |
| |       |         | |       |                     |
| | +-------------+ | |       |                     |
| | | k8s-worker-2|<----+---------------------------+
| | | (k3s agent) | | |
| | +-------------+ | |
| +-----------------+ |
+---------------------+
```

## Getting Started

To deploy a full Argus Infra cluster, please refer to the [Setup Guide](docs/setup.md).

## Further Documentation
-   [Full Infra Architecture](docs/architecture.md): In-depth explanation of the infrastructure components and their interactions.

-   [Setup Guide](docs/setup.md): Detailed instructions for setting up the infrastructure.
-   [Operational Runbooks](docs/runbooks.md): Guides for common operational tasks like deployment, rollback, and troubleshooting.
-   [Architecture Decision Records (ADRs)](docs/adr/): Documentation of key architectural decisions.

---

**Note for Argus PM Agent:** When any PR merges to this repository, the Argus PM Agent must review what changed and update relevant documentation to keep it in sync.
