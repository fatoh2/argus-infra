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
7. **Security** — Kubernetes NetworkPolicies for least-privilege pod network access
8. **CI/CD & Testing** — GitHub Actions for validation, sanity checks, and cluster health monitoring

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
| `security` | `k8s/security/network-policies/` | `default` | NetworkPolicies (default deny + explicit allow) |

## 6. Secret Management (External Secrets Operator)

Secrets are managed securely using External Secrets Operator (ESO) with Doppler as the external secrets provider. This approach ensures that sensitive credentials are never stored in Git and are dynamically injected into the cluster.

### Key Components:
- **External Secrets Operator:** A Kubernetes operator that synchronizes secrets from external APIs (Doppler) into Kubernetes Secrets.
- **Doppler:** A cloud-based secrets management platform that provides a centralized, auditable, and encrypted store for all environment variables and secrets.
- **SecretStore:** A namespaced or cluster-scoped ESO resource that defines how to authenticate and connect to the external secrets provider (Doppler).
- **ExternalSecret:** A namespaced ESO resource that declares which secrets to fetch from the external provider and how to map them into a Kubernetes Secret.

### Workflow:
1. A `SecretStore` is configured with a Doppler API token (stored as a Kubernetes Secret, bootstrapped manually).
2. An `ExternalSecret` resource references the `SecretStore` and specifies which Doppler secrets to fetch.
3. ESO periodically syncs the specified secrets from Doppler and creates/updates the corresponding Kubernetes `Secret`.
4. Application pods reference the Kubernetes `Secret` as environment variables or volume mounts.

## 7. Ingress & TLS (Traefik + cert-manager)

Traefik serves as the ingress controller, routing external HTTP/HTTPS traffic to internal services. cert-manager automates TLS certificate provisioning and renewal using Let's Encrypt.

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
- **Grafana:** Deployed via ArgoCD from `k8s/grafana/` as a standalone deployment (not part of kube-prometheus-stack). Provides dashboards for visualizing Prometheus metrics and Loki logs. Pre-configured with:
  - Kubernetes cluster monitoring dashboards (CPU, memory, network).
  - Prometheus datasource auto-configured via ConfigMap.
  - Loki as a data source for log exploration.
  - Ingress at `grafana.argus.local` with Traefik and automatic TLS via cert-manager.
- **Loki:** A horizontally-scalable, highly-available log aggregation system. It indexes metadata (labels) rather than full-text, making it cost-effective.
- **Promtail:** A log collector that runs on each node, shipping container logs to Loki.

### Grafana Deployment Details

Grafana is deployed as a standalone ArgoCD application (separate from the `monitoring` app that manages kube-prometheus-stack). The deployment consists of:

| Resource | File | Purpose |
|----------|------|---------|
| ArgoCD Application | `k8s/argocd/apps/grafana.yaml` | Declares the Grafana app for ArgoCD GitOps |
| Deployment | `k8s/grafana/deployment.yaml` | Single replica running `grafana/grafana:latest` on port 3000 |
| Service | `k8s/grafana/service.yaml` | ClusterIP service exposing port 80 → 3000 |
| Ingress | `k8s/grafana/ingress.yaml` | Traefik ingress at `grafana.argus.local` with TLS via cert-manager |
| Datasource ConfigMap | `k8s/grafana/configmap-datasources.yaml` | Pre-configures Prometheus datasource |
| Dashboard ConfigMap | `k8s/grafana/configmap-dashboards.yaml` | Provisioned dashboards (Node Exporter Full, Kubernetes Cluster Overview) |

**Datasource:** Grafana is pre-configured with a Prometheus datasource pointing to the kube-prometheus-stack Prometheus service at `http://prometheus-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090`.

**Dashboards:** Two dashboards are provisioned via ConfigMap:
- **Node Exporter Full** (`uid: node-exporter-full`) — Node-level CPU usage, memory usage, and resource utilization across all worker nodes.
- **Kubernetes Cluster Overview** (`uid: kubernetes-cluster-overview`) — CPU usage by pod, memory usage by pod, and cluster-level resource health.

Additional dashboards can be added by extending the `configmap-dashboards.yaml` ConfigMap.

**Ingress:** Grafana is accessible at `https://grafana.argus.local` via Traefik ingress with automatic TLS from cert-manager (Let's Encrypt). Default credentials are `admin`/`admin` (change on first login).

**Storage:** Grafana uses an `emptyDir` volume for `/var/lib/grafana`. This means dashboards and settings are lost on pod restart if not provisioned via ConfigMaps. For persistent storage, replace with a PVC backed by Longhorn or similar.


## 9. Security (Kubernetes NetworkPolicies)

Argus Infra enforces least-privilege network access between pods using Kubernetes NetworkPolicies. A **default-deny** approach is applied to all namespaces, with explicit allow rules for legitimate traffic flows.

### Default Deny

A `default-deny-all` NetworkPolicy is applied to the following namespaces, blocking all ingress and egress traffic by default:

- `databases`
- `default`
- `monitoring`
- `ingress`
- `traefik`
- `cert-manager`
- `external-secrets-operator`
- `argocd`

### Explicit Allow Rules

| Policy | Namespace | Source | Destination | Port | Purpose |
|--------|-----------|--------|-------------|------|---------|
| `allow-api-to-postgres` | databases | `api-service` (label) | `postgres` (pod) | TCP 5432 | Application database access |
| `allow-api-to-redis` | databases | `api-service` (label) | `redis` (pod) | TCP 6379 | Application cache access |
| `allow-solana-adapter-egress` | default | `solana-adapter` (label) | Internet (HTTPS) | TCP 443 | Blockchain RPC calls (RFC1918 excluded) |
| `allow-ingress-to-api` | default | `ingress` namespace | `api-service` (pod) | TCP 3000 | Ingress to application traffic |

### Deployment

NetworkPolicies are deployed via ArgoCD as part of the `security` application, which sources from `k8s/security/network-policies/`. The app-of-apps root application includes `security` in its list of child applications.

### Risks & Considerations

- Applying default-deny to the `argocd` namespace may interfere with ArgoCD's ability to sync applications across namespaces. Monitor after deployment.
- Policies are label-based and will only take effect when pods with matching labels are deployed. Pre-created policies for future services (e.g., `solana-adapter`, `api-service`) are harmless until those pods exist.
- NetworkPolicies require a CNI plugin that supports them (k3s uses Flannel by default, which does not enforce NetworkPolicies). For enforcement, install a CNI like Calico or Cilium.


## 9.5 Pod Security Standards

Argus Infra enforces Kubernetes [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) at the **restricted** level across all application namespaces. This is the strictest built-in policy level and provides defense-in-depth alongside NetworkPolicies.

### Namespace Labeling

Each application namespace is labeled with Pod Security admission controller labels:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

The following namespaces are labeled (manifests in `k8s/security/pod-security/`):

| Namespace | Purpose |
|-----------|---------|
| `monitoring` | Prometheus, Grafana, Loki, Promtail |
| `databases` | PostgreSQL, Redis |
| `ingress` | Traefik, cert-manager, wildcard TLS |
| `traefik` | Traefik ingress controller |
| `cert-manager` | cert-manager operator |
| `default` | General application workloads |

### Workload Compliance

All workloads deployed to restricted namespaces must comply with the restricted profile. Key requirements enforced by the admission controller:

| Requirement | Example Configuration |
|-------------|----------------------|
| **Run as non-root** | `securityContext.runAsNonRoot: true` |
| **No privilege escalation** | `securityContext.allowPrivilegeEscalation: false` |
| **Drop all capabilities** | `securityContext.capabilities.drop: [ALL]` |
| **Read-only root filesystem** | `securityContext.readOnlyRootFilesystem: true` |
| **Seccomp profile** | `securityContext.seccompProfile.type: RuntimeDefault` |

### Updated Workloads

The following workloads have been updated to comply with the restricted profile:

- **Grafana Deployment** (`k8s/grafana/deployment.yaml`):
  - Pod-level: `runAsNonRoot: true`, `runAsUser: 472`, `runAsGroup: 472`, `fsGroup: 472`, `seccompProfile: RuntimeDefault`
  - Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`
  - Added `emptyDir` volume mounted at `/tmp` for Grafana temp files

- **Postgres Backup CronJob** (`k8s/postgres-backup-cronjob.yaml`):
  - Pod-level: `runAsNonRoot: true`, `seccompProfile: RuntimeDefault`
  - Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`
  - Added `emptyDir` volume mounted at `/tmp`

### Applying the Policies

```bash
# Apply namespace labels
kubectl apply -f k8s/security/pod-security/

# Verify enforcement
kubectl describe ns monitoring
# Should show: pod-security.kubernetes.io/enforce: restricted
```

### Risks & Considerations

- The `amazon/aws-cli:latest` image used in the Postgres Backup CronJob may run as root by default. If the CronJob fails after applying the restricted profile, switch to a non-root AWS CLI image or adjust the securityContext.
- `readOnlyRootFilesystem: true` requires all writable paths to be explicitly mounted as `emptyDir` volumes. Any workload that writes to its container filesystem without an `emptyDir` mount will fail.
- Grafana's default image runs as user 472, which satisfies `runAsNonRoot: true`. If using a custom Grafana image, verify the user ID.
- The `kube-system` and `argocd` namespaces are intentionally not labeled with the restricted profile, as system-level components may require elevated privileges.


## 9.6 RBAC — Least-Privilege ServiceAccounts

Argus Infra enforces least-privilege Kubernetes RBAC by creating dedicated ServiceAccounts for each service, scoped to the minimum permissions required. This follows the principle of least privilege and limits the blast radius of a compromised pod.

### ServiceAccounts

The following ServiceAccounts are defined in `k8s/security/rbac/`:

| ServiceAccount | Namespace | Permissions | Rationale |
|----------------|-----------|-------------|-----------|
| `api-service` | `default` | None (no k8s API access) | Application pods do not need to interact with the Kubernetes API |
| `argocd-manager` | `argocd` | Full management of namespaces, apps, RBAC, CRDs (read-only), and all namespaced resources | ArgoCD needs to create and manage resources across namespaces |
| `prometheus` | `monitoring` | Read-only (get/list/watch) on nodes, pods, services, deployments, ingresses, and monitoring.coreos.com resources | Prometheus scrapes metrics and needs discovery but should never create or modify resources |

### Key Design Decisions

- **`automountServiceAccountToken: false`** is set on the `api-service` ServiceAccount since it has no k8s API access. This eliminates the attack surface of a mounted token.
- **No wildcard verbs** — ArgoCD's ClusterRole uses explicit verbs per resource type (e.g., `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`) rather than `["*"]`.
- **Read-only for Prometheus** — Prometheus only needs to discover targets and read metrics. It has no create/update/delete permissions.

### Verification

```bash
# api-service has zero k8s API access
kubectl auth can-i list pods --as=system:serviceaccount:default:api-service
# → no

# Prometheus is read-only
kubectl auth can-i create pods --as=system:serviceaccount:monitoring:prometheus
# → no
kubectl auth can-i get pods --as=system:serviceaccount:monitoring:prometheus
# → yes

# ArgoCD can still manage resources
kubectl auth can-i create deployments --as=system:serviceaccount:argocd:argocd-manager
# → yes
```

### Deployment

RBAC resources are deployed via ArgoCD as part of the `security` application, which sources from `k8s/security/` (a kustomization that includes both `network-policies` and `rbac` subdirectories).


## 10. CI/CD Pipeline & Testing

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

## 11. Data Flow Summary

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
       ├──► External Secrets (Doppler)
       ├──► RBAC (least-privilege ServiceAccounts)
       └──► NetworkPolicies (default deny, least-privilege)
```

## 12. Design Decisions

Key architecture decisions are documented as Architecture Decision Records (ADRs) in `docs/adr/`:

- **ADR-0001:** Hetzner Cloud VM provisioning with Terraform
- **ADR-0002:** k3s vs kubeadm for Kubernetes cluster
- **ADR-0003:** ArgoCD for GitOps
