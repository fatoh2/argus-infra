# Argus Infra Architecture

This document provides an in-depth explanation of the Argus Infra components and their interactions, detailing the design choices and how they contribute to a robust and scalable Kubernetes homelab platform.

## 1. Overview

Argus Infra is a fully GitOps-driven Kubernetes homelab platform running on Hetzner Cloud. The architecture follows a layered approach:

1. **Infrastructure** — Hetzner Cloud VMs provisioned via Terraform
2. **Cluster** — k3s installed and configured via Ansible
3. **GitOps** — ArgoCD manages all Kubernetes workloads declaratively
4. **Ingress & TLS** — Traefik + cert-manager for routing and automatic certificates
5. **Observability** — Prometheus, Grafana, and Loki for metrics and logs
6. **Secrets** — External Secrets Operator with Doppler for secure credential management
7. **CI/CD & Testing** — GitHub Actions for validation, sanity checks, and cluster health monitoring

## 2. Infrastructure Provisioning (Terraform/OpenTofu)

Argus Infra leverages Terraform (or OpenTofu) to provision the underlying virtual machine infrastructure on Hetzner Cloud. This ensures that the infrastructure is defined as code, enabling reproducibility, version control, and automated deployment.

### Key Components:
- **Hetzner Cloud Project:** The entire infrastructure resides within a dedicated Hetzner Cloud project.
- **Private Network:** A dedicated private network (`10.0.0.0/16`) and subnet (`10.0.1.0/24`) are created to facilitate secure communication between Kubernetes nodes, isolated from the public internet. This network is crucial for stable internal IP addressing for Kubernetes components.
- **Virtual Machines:**
  - **Control Plane Node (`k8s-control`):** A single VM hosts the k3s control plane components (API Server, Controller Manager, Scheduler, embedded etcd). It is the brain of the cluster.
  - **Worker Nodes (`k8s-worker-X`):** Multiple VMs act as worker nodes, running the `kubelet` and `kube-proxy` to execute application workloads. They are responsible for running containers.
- **SSH Keys:** SSH keys are managed through Terraform to allow secure access to the VMs for initial setup and troubleshooting. Terraform references existing keys in Hetzner Cloud, it does not manage the key material itself.

## 3. Kubernetes Cluster (k3s)

k3s is chosen as the Kubernetes distribution for its lightweight nature, ease of installation, and suitability for homelab and edge environments. It provides a fully compliant Kubernetes API with a reduced footprint.

### Key Components:
- **k3s Server:** Runs on the `k8s-control` node, encompassing:
  - **API Server:** Exposes the Kubernetes API, acting as the front-end for the control plane.
  - **Controller Manager:** Runs controller processes, which watch the shared state of the cluster through the API server and make changes attempting to move the current state towards the desired state.
  - **Scheduler:** Assigns pods to nodes based on resource requirements and other constraints.
  - **Embedded etcd:** A lightweight, embedded datastore for cluster state, ensuring high availability and data consistency.
  - **CoreDNS:** Provides DNS services for the cluster.
- **k3s Agent:** Runs on `k8s-worker-X` nodes, encompassing:
  - **kubelet:** The agent that runs on each node in the cluster. It ensures that containers are running in a Pod.
  - **kube-proxy:** Maintains network rules on nodes, enabling network communication to your Pods from network sessions inside or outside of your cluster.

> **Note:** k3s ships with a built-in Traefik ingress controller by default. Argus Infra replaces this with a dedicated Traefik deployment managed via ArgoCD for finer control over configuration (see Section 7).

## 4. Configuration Management (Ansible)

Ansible is used for post-provisioning configuration of the VMs and for installing and configuring k3s. It automates tasks such as:
- System updates and package installation.
- User and SSH key management.
- Firewall configuration (e.g., opening necessary ports for Kubernetes).
- k3s installation and cluster joining, ensuring a consistent setup across all nodes.

## 5. GitOps with ArgoCD

ArgoCD is the cornerstone of the GitOps workflow, enabling declarative and automated deployment of applications and cluster configurations. It continuously monitors the `argus-infra` Git repository for changes in Kubernetes manifests and automatically synchronizes the cluster state to match the desired state defined in Git.

### Key Aspects:
- **Source of Truth:** The Git repository (`k8s/` directory) serves as the single source of truth for all cluster configurations and application deployments. All changes to the cluster state are made via Git commits.
- **Automated Sync:** ArgoCD automatically detects divergences between the desired state (Git) and the actual state (cluster) and reconciles them, ensuring continuous deployment and self-healing capabilities.
- **Application of Applications (App-of-Apps):** A hierarchical structure where a root ArgoCD application manages other ArgoCD applications, allowing for modular and scalable management of various components (e.g., core services, monitoring, logging, security).

### Application Structure

The ArgoCD app-of-apps structure is defined in `k8s/argocd/apps/`:

| Application | Source | Namespace | Purpose |
|-------------|--------|-----------|---------|
| `ingress` | `k8s/ingress/` | `ingress` | Traefik, cert-manager, wildcard TLS |
| `monitoring` | `k8s/monitoring/` | `monitoring` | Prometheus stack (kube-prometheus-stack) |
| `grafana` | `k8s/grafana/` | `monitoring` | Grafana dashboards and provisioning |
| `loki` | Helm chart (grafana/loki) | `monitoring` | Log aggregation |
| `promtail` | Helm chart (grafana/promtail) | `monitoring` | Log collection agent |
| `traefik` | Helm chart (traefik/traefik) | `traefik` | Ingress controller |
| `cert-manager` | Helm chart (jetstack/cert-manager) | `cert-manager` | TLS certificate automation |

## 6. Secrets Management (External Secrets Operator & Doppler)

Sensitive information (e.g., API keys, database credentials) is managed through a secure, external secrets management system. This approach ensures that secrets are never stored in the Git repository.

### Key Components:
- **External Secrets Operator:** A Kubernetes operator that synchronizes secrets from external providers (like Doppler) into Kubernetes Secrets.
- **Doppler:** A cloud-based secrets management platform that serves as the single source of truth for all sensitive configuration data.
- **ClusterSecretStore:** A cluster-scoped resource that defines how to connect to the external secrets provider (Doppler). It is configured once and used by all ExternalSecrets across namespaces.

### Workflow:
1. Secrets are defined and managed in the Doppler dashboard.
2. External Secrets Operator, configured via a `ClusterSecretStore`, periodically fetches the required secrets from Doppler.
3. The operator creates or updates native Kubernetes `Secret` objects in the specified namespaces.
4. Pods access these secrets as environment variables or volume mounts, just like any other Kubernetes secret.

## 7. Ingress and TLS (Traefik & cert-manager)

Traefik serves as the ingress controller, managing external access to services running in the cluster. cert-manager automates the lifecycle of TLS certificates from Let's Encrypt.

### Key Components:
- **Traefik:** A modern, cloud-native HTTP reverse proxy and load balancer. It handles ingress routing based on `IngressRoute` (Traefik's CRD) or standard Kubernetes `Ingress` resources.
- **cert-manager:** A Kubernetes add-on that automates the issuance and renewal of TLS certificates from various issuers, including Let's Encrypt.
- **ClusterIssuer:** A cluster-scoped cert-manager resource that defines how to obtain certificates from Let's Encrypt (using the HTTP-01 challenge via Traefik).
- **Wildcard Certificate:** A single certificate covering `*.argus-infra.dev` is issued and automatically renewed, securing all subdomains.

### Traffic Flow:
1. A DNS `A` record (e.g., `*.argus-infra.dev`) points to the public IP of the Traefik load balancer (or the node port).
2. An incoming HTTPS request for `app.argus-infra.dev` hits Traefik.
3. Traefik terminates TLS using the wildcard certificate managed by cert-manager.
4. Traefik routes the request to the appropriate backend service based on the `IngressRoute` or `Ingress` rules.
5. The backend service forwards the request to the application pods.

## 8. Observability (Prometheus, Grafana, Loki)

A comprehensive observability stack provides metrics collection, visualization, and log aggregation.

### Key Components:
- **Prometheus (kube-prometheus-stack):** Collects and stores metrics from the cluster and applications. Includes:
  - **Prometheus Server:** Scrapes metrics from configured targets.
  - **Alertmanager:** Handles alerts based on Prometheus rules.
  - **ServiceMonitors/PodMonitors:** CRDs that define which services/pods to scrape.
- **Grafana:** Provides dashboards for visualizing Prometheus metrics and Loki logs. Pre-configured with:
  - Kubernetes cluster monitoring dashboards.
  - Custom dashboards for application-specific metrics.
  - Loki as a data source for log exploration.
- **Loki:** A horizontally-scalable, highly-available log aggregation system. It indexes metadata (labels) rather than full-text, making it cost-effective.
- **Promtail:** A log collector that runs on each node, shipping container logs to Loki.

## 9. CI/CD Pipeline & Testing

Argus Infra uses GitHub Actions for continuous integration and cluster health monitoring. The pipeline is designed to catch issues early and ensure cluster reliability.

### Sanity Checks (PR-level)

The `sanity-checks.yml` workflow runs on every pull request to `develop` or `main`, and on every push to those branches. It validates:

| Check | Tool | What it validates |
|-------|------|-------------------|
| Terraform Validate | `terraform validate` | Configuration syntax and internal consistency |
| Terraform Format | `terraform fmt -check -recursive` | Code style compliance |
| Terraform Plan | `terraform plan` | Execution plan (syntax-only, no apply) |
| Ansible Syntax | `ansible-playbook --syntax-check` | Playbook and role syntax |
| Ansible Lint | `ansible-lint` | Best practices and common errors |
| ShellCheck | `shellcheck` (advisory) | Shell script quality |
| Critical Files | File existence checks | All required config files are present |

### Cluster Sanity (Scheduled)

The `cluster-sanity.yml` workflow runs every 6 hours (and can be triggered manually via `workflow_dispatch`). It requires a running cluster and the `CLUSTER_SANITY_ENABLED` repository variable set to `true`. It checks:

- **Cluster connectivity** — `kubectl cluster-info`
- **Node health** — all nodes are `Ready`
- **Pod health** — all pods in key namespaces are running
- **ArgoCD app health** — all ArgoCD applications are `Synced` and `Healthy`
- **Ingress reachability** — key endpoints respond correctly

### Local Sanity Suite

The `scripts/` directory contains scripts that replicate the CI checks locally:

| Script | Purpose | Requires cluster? |
|--------|---------|-------------------|
| `run-sanity-checks.sh` | Terraform + Ansible + file structure validation | No |
| `argocd-health.sh` | ArgoCD application health check | Yes |
| `cluster-sanity.sh` | Full cluster-level sanity (nodes, pods, ArgoCD, ingress) | Yes |

Run `./scripts/run-sanity-checks.sh` before committing to catch issues early.

## 10. Data Flow Summary

```
User commits to Git
       │
       ▼
  GitHub Actions ──► Sanity Checks (PR validation)
       │
       ▼
  Git Repository (source of truth)
       │
       ▼
  ArgoCD (polls Git, syncs cluster)
       │
       ▼
  Kubernetes Cluster
       │
       ├──► Traefik (ingress, TLS termination)
       ├──► Application Pods
       ├──► Prometheus (metrics)
       ├──► Loki (logs)
       └──► External Secrets (Doppler)
```

## 11. Design Decisions

Key architecture decisions are documented as Architecture Decision Records (ADRs) in `docs/adr/`:

- **ADR-0001:** Hetzner Cloud VM provisioning with Terraform
- **ADR-0002:** k3s vs kubeadm for Kubernetes cluster
- **ADR-0003:** ArgoCD for GitOps
