# Argus Infra

## Project Overview

Argus Infra is the foundational Kubernetes homelab platform for the Argus project. It provides the infrastructure layer for deploying and managing our blockchain monitoring SaaS (`argus-monitor`) and AI infrastructure assistant (`argus-ai`).

This repository uses Infrastructure as Code (IaC) principles to provision and manage a highly available, self-healing Kubernetes cluster on Hetzner Cloud. Our goal is to create a robust, production-ready environment suitable for continuous deployment and operation of our services.

## What it Does

-   **Automated VM Provisioning:** Uses Terraform/OpenTofu to provision virtual machines on Hetzner Cloud, including network configuration and SSH key management.
-   **Kubernetes Cluster Setup:** Deploys a lightweight k3s Kubernetes cluster across the provisioned VMs using Ansible, handling node roles (control plane, workers) and initial cluster configuration.
-   **GitOps Management:** Leverages ArgoCD for declarative, GitOps-driven application deployment and cluster state management, ensuring that the cluster state always matches the desired state defined in Git.
-   **Secrets Management:** Integrates External Secrets Operator with Doppler for secure, centralized management and injection of sensitive data into the Kubernetes cluster.
-   **Observability:** Integrates Prometheus for monitoring and alerting, and Grafana for visualization (future work).
-   **Ingress & TLS:** Manages external access to services via NGINX Ingress Controller and automates TLS certificate provisioning with cert-manager.

## Tech Stack

-   **Cloud Provider:** Hetzner Cloud
-   **Infrastructure as Code:** Terraform / OpenTofu
-   **Configuration Management:** Ansible
-   **Kubernetes Distribution:** k3s
-   **GitOps:** ArgoCD
-   **Secrets Management:** External Secrets Operator, Doppler
-   **Ingress:** NGINX Ingress Controller
-   **TLS:** cert-manager
-   **Monitoring:** Prometheus, Grafana (future)

## Architecture Diagram (Conceptual)

```
+---------------------+       +---------------------+       +---------------------+
| Hetzner Cloud       |       | GitHub              |       | External Services   |
|                     |       | (argus-infra repo)  |       |                     |
| +-----------------+ |       |                     |       | +---------------+   |
| | Private Network | |       | +-----------------+ |       | | Doppler       |   |
| | 10.0.1.0/24     | |       | | GitOps Repo     | |       | +-------^-------+   |
| |                 | |       | | (k8s manifests) | |       |         |           |
| | +-------------+ | |       | +--------^--------+ |       |         | ESO       |
| | | k8s-control |<----+-----+----------|-----------+-------+---------+           |
| | | (k3s server)| | |       |          | ArgoCD    |       |                     |
| | +-------------+ | |       |          | Sync      |       | +---------------+   |
| |       |         | |       |          v          |       | | DNS Provider  |   |
| | +-------------+ | |       | +-----------------+ |       | +-------^-------+   |
| | | k8s-worker-1|<----+-----+ | ArgoCD          | |       |         | External  |
| | | (k3s agent) | | |       | | (running in k8s)| |       |         | DNS       |
| | +-------------+ | |       | +-----------------+ |       |         |           |
| |       |         | |       |                     |       | +---------------+   |
| | +-------------+ | |       |                     |       | | Let's Encrypt |   |
| | | k8s-worker-2|<----+---------------------------+-------+ +-------^-------+   |
| | | (k3s agent) | | |                                       |         | cert-mgr  |
| | +-----------------+ |                                       +---------------------+
+---------------------+
```

## Getting Started

To deploy a full Argus Infra cluster, please refer to the [Setup Guide](docs/setup.md). This guide will walk you through the prerequisites, Terraform provisioning, Ansible configuration, and ArgoCD bootstrapping.

## Further Documentation

-   [Full Infra Architecture](docs/architecture.md): In-depth explanation of the infrastructure components and their interactions, including networking, Kubernetes internals, and GitOps flow.
-   [Setup Guide](docs/setup.md): Detailed instructions for setting up the infrastructure from scratch.
-   [Operational Runbooks](docs/runbooks.md): Guides for common operational tasks like deployment, rollback, scaling, and troubleshooting.
-   [Architecture Decision Records (ADRs)](docs/adr/): Documentation of key architectural decisions made during the project.

---

**Note for Argus PM Agent:** When any PR merges to this repository, the Argus PM Agent must review what changed and update relevant documentation to keep it in sync.
