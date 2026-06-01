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

Sensitive information (e.g., API keys, database credentials) is managed securely using a combination of External Secrets Operator (ESO) and Doppler.

### Workflow:
1. **Doppler:** Stores secrets securely in a centralized, managed service, providing versioning and access control.
2. **External Secrets Operator:** Deployed within the Kubernetes cluster, ESO fetches secrets from Doppler and injects them as native Kubernetes `Secret` objects. This eliminates the need to store secrets directly in Git.
3. **Kubernetes Secrets:** Applications consume these Kubernetes `Secret` objects, ensuring that sensitive data is never committed to Git and is handled securely within the cluster.

## 7. Ingress and TLS (Traefik & cert-manager)

External access to applications within the cluster is managed by **Traefik** as the ingress controller, with TLS certificates automatically provisioned and renewed by **cert-manager** using Let's Encrypt.

### Key Components:
- **Traefik:** Routes external HTTP/S traffic to the appropriate services within the Kubernetes cluster based on Ingress resources and Traefik's custom CRDs (IngressRoute, Middleware, etc.). It acts as a reverse proxy and load balancer, with automatic HTTP-to-HTTPS redirection configured.
- **cert-manager:** Automates the management and issuance of TLS certificates from Let's Encrypt. It ensures that applications have valid and up-to-date certificates for secure communication.
- **ClusterIssuer:** A `letsencrypt-prod` ClusterIssuer is configured to use the HTTP-01 challenge with Traefik as the solver ingress class.
- **Wildcard Certificate:** A `*.argus-infra.dev` wildcard certificate is defined as a cert-manager `Certificate` resource, stored in the `wildcard-argus-infra-tls` Secret in the `ingress` namespace. This single certificate covers all subdomains.

### Ingress Architecture

```
Internet
   │
   ▼
Traefik (NodePort 30080/30443)
   │
   ├── HTTP (port 30080) → redirects to HTTPS
   └── HTTPS (port 30443) → TLS termination
        │
        ├── cert-manager (HTTP-01 challenges)
        └── Ingress/IngressRoute → Services → Pods
```

### Deployment

The ingress stack is deployed via ArgoCD from `k8s/ingress/`:
- `traefik-helmrelease.yaml` — Traefik HelmRelease with HTTP→HTTPS redirect, dashboard, CRDs
- `cert-manager-helmrelease.yaml` — cert-manager HelmRelease with CRDs
- `cluster-issuer.yaml` — Let's Encrypt production ClusterIssuer
- `wildcard-certificate.yaml` — Wildcard TLS certificate for `*.argus-infra.dev`
- `helm-repositories.yaml` — Helm repository definitions
- `kustomization.yaml` — Kustomize configuration

## 8. Monitoring and Alerting (Prometheus & Grafana)

To ensure the health and performance of the cluster and deployed applications, Argus Infra integrates Prometheus for metrics collection and alerting, and Grafana for visualization.

### Key Components:
- **Prometheus (kube-prometheus-stack):** A powerful open-source monitoring system that collects metrics from configured targets at given intervals, evaluates rule expressions, displays the results, and can trigger alerts if some condition is observed to be true. Deployed via the `kube-prometheus-stack` Helm chart which bundles Prometheus, Alertmanager, and node exporters.
- **Grafana:** An open-source platform for monitoring and observability. It allows you to query, visualize, alert on, and explore your metrics, logs, and traces no matter where they are stored. Pre-configured with dashboards and a Prometheus datasource via ConfigMaps.

### Deployment

The monitoring stack is deployed via ArgoCD:
- **Prometheus stack** — from `k8s/monitoring/prometheus.yaml` (HelmRelease for kube-prometheus-stack)
- **Grafana** — from `k8s/grafana/` directory (deployment, service, ingress, ConfigMaps for dashboards and provisioning)

## 9. Log Aggregation (Loki & Promtail)

Centralized log aggregation is provided by Grafana Loki, with Promtail as the log collection agent deployed on each node.

### Key Components:
- **Loki:** A horizontally-scalable, highly-available, multi-tenant log aggregation system inspired by Prometheus. It is designed to be cost-effective and easy to operate, indexing only metadata about logs rather than the full log content.
- **Promtail:** An agent that ships the contents of local logs to a Loki instance. It is deployed as a DaemonSet to collect logs from every node in the cluster.

### Deployment

The logging stack is deployed via ArgoCD:
- **Loki** — from `k8s/argocd/apps/loki/application.yaml` (Helm chart from grafana/loki)
- **Promtail** — from `k8s/argocd/apps/loki/promtail.yaml` (Helm chart from grafana/promtail)

Both deploy into the `monitoring` namespace and are configured with persistent storage for Loki.

## 10. CI/CD Pipeline

The repository includes a GitHub Actions workflow (`.github/workflows/sanity-checks.yml`) that runs on every PR to `develop`. It performs:

- **Terraform validate** — checks configuration syntax
- **Terraform format check** — ensures consistent formatting
- **Terraform plan** — validates configuration with dummy variable values (no real infrastructure is provisioned)
- **Ansible syntax check** — verifies playbook syntax using a CI-specific inventory with dummy IPs
- **Ansible lint** — lints all playbooks and roles for best practices

## 11. Architecture Decision Records

Key architectural decisions are documented in `docs/adr/`:

- [ADR-0001](adr/0001-hetzner-terraform-vm-provisioning.md): Hetzner Terraform VM Provisioning
- [ADR-0002](adr/0002-k3s-vs-kubeadm.md): k3s vs kubeadm
- [ADR-0003](adr/0003-argocd-for-gitops.md): ArgoCD for GitOps
