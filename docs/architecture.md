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
- **ServiceMonitors:** Custom resources that Prometheus uses to discover and scrape metrics from Kubernetes services. PR #57 introduced ServiceMonitors for `argus-monitor` services (API, Chain Indexer, Solana Adapter) to automatically collect their metrics.
- **Hetzner Cloud Project:** The entire infrastructure resides within a dedicated Hetzner Cloud project.
- **Private Network:** A dedicated private network (`10.0.0.0/16`) and subnet (`10.0.1.0/24`) are created to facilitate secure communication between Kubernetes nodes, isolated from the public internet. This network is crucial for stable internal IP addressing for Kubernetes components.
- **Virtual Machines:**
  - **Control Plane Node (`k8s-control`):** A single VM hosts the k3s control plane components (API Server, Controller Manager, Scheduler, embedded etcd). It is the brain of the cluster.
  - **Worker Nodes (`k8s-worker-X`):** Multiple VMs act as worker nodes, running the `kubelet` and `kube-proxy` to execute application workloads. They are responsible for running containers.
- **SSH Keys:** SSH keys are managed through Terraform to allow secure access to the VMs for initial setup and troubleshooting. Terraform references existing keys in Hetzner Cloud, it does not manage the key material itself.

## 3. Kubernetes Cluster (k3s)

k3s is chosen as the Kubernetes distribution for its lightweight nature, ease of installation, and suitability for homelab and edge environments. It provides a fully compliant Kubernetes API with a reduced footprint.

### Key Components:
- **ServiceMonitors:** Custom resources that Prometheus uses to discover and scrape metrics from Kubernetes services. PR #57 introduced ServiceMonitors for `argus-monitor` services (API, Chain Indexer, Solana Adapter) to automatically collect their metrics.
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
| `cert-manager` | Helm chart (cert-manager/cert-manager) | `cert-manager` | TLS certificate management |
| `cluster-issuer` | `k8s/cluster-issuer/` | `cert-manager` | Let's Encrypt ClusterIssuer |
| `external-secrets` | `k8s/external-secrets/` | `external-secrets-operator` | External Secrets Operator + Doppler |
| `databases` | `k8s/databases/` | `databases` | PostgreSQL, Redis |
| `security` | `k8s/security/` | (cluster-wide) | NetworkPolicies, Pod Security, RBAC |

## 6. Observability (Prometheus, Grafana, Loki)

Observability is a core feature of Argus Infra, providing comprehensive monitoring and logging capabilities.

### Prometheus Stack
- **Deployment:** The Prometheus stack is deployed via the `kube-prometheus-stack` Helm chart, which includes Prometheus, Alertmanager, and various exporters.
- **Service Monitors:** Pre-configured to scrape metrics from all cluster components and applications.
- **Retention:** Metrics are retained for 30 days by default.

### Grafana
- **Deployment:** Grafana is deployed as a standalone ArgoCD application from `k8s/grafana/`, using the official Grafana Helm chart.
- **Dashboards:** Pre-configured with the "Node Exporter Full" and "Kubernetes Cluster Overview" dashboards, provisioned via ConfigMaps.
- **Datasources:** Prometheus and Loki are configured as default datasources.
- **Ingress:** Accessible at `https://grafana.argus.local` via Traefik IngressRoute with automatic TLS.
- **Storage:** Grafana uses a 5Gi PersistentVolumeClaim (`k8s/grafana/pvc.yaml`) mounted at `/var/lib/grafana` for persistent storage of dashboards, settings, and user data.

### Loki & Promtail
- **Loki:** Deployed via Helm for log aggregation, providing a scalable, multi-tenant log storage system.
- **Promtail:** Deployed as a DaemonSet to collect logs from all nodes and forward them to Loki.

## 7. Ingress & TLS (Traefik + cert-manager)

Argus Infra uses Traefik as its ingress controller, replacing the default k3s Traefik with a dedicated deployment managed via ArgoCD.

### Traefik
- **Deployment:** Deployed via Helm chart (`traefik/traefik`) in the `traefik` namespace.
- **Configuration:** Configured with `--providers.kubernetesingress` and `--providers.kubernetescrd` to support both standard Ingress resources and Traefik's custom CRD (IngressRoute).
- **EntryPoints:** Configured for HTTP (port 80) and HTTPS (port 443) with automatic redirection from HTTP to HTTPS.

### cert-manager
- **Deployment:** Deployed via Helm chart (`cert-manager/cert-manager`) in the `cert-manager` namespace.
- **ClusterIssuer:** Configured with a Let's Encrypt production ClusterIssuer for automatic TLS certificate issuance.
- **Wildcard Certificate:** A wildcard certificate for `*.argus.local` is automatically requested and renewed.

## 8. Secrets Management (External Secrets Operator + Doppler)

Secrets are managed securely using **External Secrets Operator (ESO)** with **Doppler** as the backend.

### Architecture

```
Doppler (source of truth)
    │
    ▼
External Secrets Operator (syncs secrets into the cluster)
    │
    ▼
Kubernetes Secrets (consumed by pods)
```

- **Doppler** is the single source of truth for all secrets (API keys, database URLs, tokens).
- **External Secrets Operator** runs in the `external-secrets-operator` namespace and syncs secrets from Doppler into Kubernetes `Secret` objects.
- **SecretStore** resources define how ESO authenticates to Doppler.
- **ExternalSecret** resources define which Doppler secrets to sync and where to store them.

### Deployment

ESO is deployed via ArgoCD (app-of-apps pattern). The ArgoCD application at `k8s/argocd/apps/external-secrets.yaml` points to `k8s/external-secrets/`, which contains:

- **`helm-repository.yaml`** — Flux HelmRepository pointing to `https://charts.external-secrets.io`
- **`helm-release.yaml`** — Flux HelmRelease deploying ESO v0.9.x with CRDs
- **`secretstore.yaml`** — A `SecretStore` resource named `doppler-backend` in the `default` namespace
- **`example-external-secret.yaml`** — An example `ExternalSecret` syncing `DATABASE_URL`, `REDIS_URL`, and `API_KEY`
- **`doppler-auth-secret.yaml`** — A placeholder Kubernetes `Secret` for the Doppler service token (token must be applied manually — never committed to git)
- **`kustomization.yaml`** — Kustomize resources list

### Doppler Authentication

ESO authenticates to Doppler using a service token stored in a Kubernetes Secret:

```bash
kubectl create secret generic doppler-auth   --namespace external-secrets-operator   --from-literal=token='dp.st.your_token_here'   --dry-run=client -o yaml | kubectl apply -f -
```

> **Never** commit the actual token to the repository. The file `k8s/external-secrets/doppler-auth-secret.yaml` contains a placeholder only.

### SecretStore

The `SecretStore` resource (`k8s/external-secrets/secretstore.yaml`) configures ESO to use Doppler as the provider:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: doppler-backend
  namespace: default
spec:
  provider:
    doppler:
      auth:
        secretRef:
          dopplerToken:
            name: doppler-auth
            key: token
```

### ExternalSecret Example

An `ExternalSecret` defines which Doppler secrets to sync and where to store them:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: example-app-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: doppler-backend
    kind: SecretStore
  target:
    name: example-app-secret
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: DATABASE_URL
    - secretKey: REDIS_URL
      remoteRef:
        key: REDIS_URL
    - secretKey: API_KEY
      remoteRef:
        key: API_KEY
```

### Verification

```bash
# Check ESO pods are running
kubectl get pods -n external-secrets-operator

# Check SecretStore status
kubectl get secretstore -n default doppler-backend -o wide

# Check ExternalSecret status
kubectl get externalsecret -n default example-app-secret -o wide

# Verify the synced secret exists
kubectl get secret -n default example-app-secret
```

### Security Notes

- Doppler service tokens are stored as Kubernetes Secrets in the `external-secrets-operator` namespace
- The `doppler-auth` secret is **never** committed to git with a real token
- ExternalSecrets use `creationPolicy: Owner` so ESO manages the lifecycle
- Secrets are refreshed every hour (`refreshInterval: 1h`)
- ESO RBAC is scoped to only manage secrets in namespaces where ExternalSecrets are defined

See [docs/secrets.md](secrets.md) for the full setup guide, verification steps, and troubleshooting.

## 9. Security (NetworkPolicies, Pod Security, RBAC)

Security is implemented at multiple layers to ensure least-privilege access and defense in depth.

### Network Policies
- **Default Deny:** A default-deny-all NetworkPolicy is applied to all namespaces, blocking all ingress and egress traffic by default.
- **Explicit Allow:** Specific NetworkPolicies are created to allow necessary traffic:
  - `allow-ingress-to-api`: Allows ingress traffic from Traefik to the API service.
  - `allow-api-to-postgres`: Allows the API service to connect to PostgreSQL.
  - `allow-api-to-redis`: Allows the API service to connect to Redis.
  - `allow-solana-adapter-egress`: Allows the Solana adapter to make outbound connections to the Solana RPC.

### Pod Security Standards
- **Restricted Profile:** All namespaces are labeled with `pod-security.kubernetes.io/enforce: restricted`, enforcing the most restrictive Pod Security Standard.
- **Workload Compliance:** All pods must run with `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, and dropped capabilities.

### RBAC
- **Least-Privilege ServiceAccounts:** Each service has a dedicated ServiceAccount with minimum required permissions:
  - `api-service`: No Kubernetes API access (zero permissions).
  - `argocd-manager`: Cluster-admin access (required for ArgoCD to manage the cluster).
  - `prometheus`: Read-only access to pods, services, and endpoints for metrics scraping.

## 10. CI/CD & Testing

Argus Infra uses a two-tier CI/CD approach with GitHub Actions:

1. **CI (Continuous Integration)** — runs on every PR to `develop` via `.github/workflows/sanity-checks.yml`
2. **CD (Continuous Deployment)** — runs on every merge to `main` via `.github/workflows/cd-deploy.yml`

The pipeline is designed to catch issues early and ensure cluster reliability.

### CI: Sanity Checks (PR-level)

The `sanity-checks.yml` workflow runs on every PR to `develop` and every push to `develop`/`main`. It validates:

| Step | What it checks |
|------|----------------|
| Terraform Format | `terraform fmt -check` ensures consistent formatting |
| Terraform Validate | `terraform validate` on the homelab environment |
| Terraform Plan | Dry-run plan (targeting network module only) to catch config errors |
| Ansible Syntax | `ansible-playbook --syntax-check` validates playbook structure |
| Ansible Lint | `ansible-lint` enforces best practices across all playbooks and roles |
| ShellCheck | Static analysis for shell scripts in `scripts/` |
| Critical Files | Ensures all required files exist (manifests, configs, docs) |

### CD: Continuous Deployment

The `cd-deploy.yml` workflow runs on every push to `main` — but only when the push touches infrastructure-relevant paths (`terraform/**`, `ansible/**`, `k8s/**`, `scripts/**`, or `.github/workflows/cd-deploy.yml`). Docs-only changes are automatically skipped.

The workflow runs three sequential stages:

| Stage | Steps | Graceful skip behavior |
|-------|-------|------------------------|
| **Lint** | Critical files check, Terraform format, Ansible lint, ShellCheck | Terraform/Ansible steps skip if directories absent |
| **Build** | Terraform validate + plan | Plan skips gracefully if `HCLOUD_TOKEN` not configured |
| **Deploy** | Placeholder (prints instructions) | Skips until `KUBECONFIG`, `ARGOCD_SERVER`, `ARGOCD_TOKEN` are set |

All steps are guarded with existence checks so the workflow passes even when infrastructure directories or secrets are not yet configured.

ArgoCD watches the `main` branch and automatically reconciles the cluster to match the manifests in Git. Sync can be triggered via:

- **Webhook** (recommended) — ArgoCD receives a GitHub webhook on push and syncs within seconds
- **Polling** (fallback) — ArgoCD polls the Git repository every 3 minutes by default

See [docs/cicd.md](cicd.md) for full pipeline documentation, including webhook setup and troubleshooting.

### Cluster Health Monitoring

The `cluster-sanity.yml` workflow runs on a scheduled basis (every 6 hours) to perform cluster-level health checks. It uses a `gate` job that conditionally enables the checks based on the `CLUSTER_SANITY_ENABLED` repository variable — this ensures the cron job always succeeds even when the cluster is not yet configured.

| Check | What it validates |
|-------|-------------------|
| Node Status | All nodes are in `Ready` state |
| Pod Health | All pods in critical namespaces are running |
| ArgoCD Sync | All ArgoCD applications are in `Synced` status |
| Certificate Expiry | TLS certificates are not expiring within 30 days |
| Disk Usage | Node disk usage is below 80% |
| API Response | Cluster API is responsive |

## 11. Data Flow

```
User → Traefik (Ingress) → cert-manager (TLS) → Service → Pod
                                                      │
                                                      ├── PostgreSQL (databases namespace)
                                                      ├── Redis (databases namespace)
                                                      └── External Services (via Egress)
```

1. A user makes an HTTPS request to `https://grafana.argus.local`.
2. Traefik terminates TLS using the wildcard certificate managed by cert-manager.
3. Traefik routes the request to the Grafana service in the `monitoring` namespace.
4. Grafana queries Prometheus for metrics and Loki for logs.
5. All inter-pod communication is governed by NetworkPolicies.

## 12. Backup & Disaster Recovery

### PostgreSQL Backups
- **Tool:** pgbackrest
- **Schedule:** Daily full backups, hourly incremental backups
- **Destination:** Backblaze B2 (S3-compatible object storage)
- **Retention:** 30 days of daily backups, 12 monthly backups

### Restore Procedure
See [docs/runbooks.md](runbooks.md) for detailed restore procedures, including:
- Point-in-time recovery
- Full cluster restore
- Individual database restore

## 13. Design Decisions

### Why k3s over kubeadm?
- **Simplicity:** Single binary installation, embedded etcd, built-in CoreDNS and Traefik.
- **Resource Efficiency:** Lower memory and CPU footprint, ideal for homelab environments.
- **Compatibility:** Fully compliant with the Kubernetes API, ensuring compatibility with all standard tools (ArgoCD, Prometheus, etc.).

### Why Traefik over NGINX Ingress?
- **Dynamic Configuration:** Traefik supports automatic service discovery and dynamic configuration updates without reloads.
- **CRD Support:** Traefik's IngressRoute CRD provides more flexible routing rules compared to standard Ingress resources.
- **Built-in Let's Encrypt:** Traefik has native support for automatic TLS certificate management, though we use cert-manager for consistency across the cluster.

### Why ArgoCD over Flux?
- **Maturity:** ArgoCD has a more mature ecosystem and wider community adoption.
- **UI:** ArgoCD provides a comprehensive web UI for managing applications and monitoring sync status.
- **App-of-Apps:** ArgoCD's app-of-apps pattern allows for modular and scalable management of cluster components.

### Why External Secrets Operator over Sealed Secrets?
- **Dynamic Updates:** ESO can automatically update secrets when they change in Doppler, without requiring a new commit.
- **Centralized Management:** Secrets are managed in Doppler, providing a single source of truth for all secrets across all environments.
- **Audit Trail:** Doppler provides detailed audit logs for all secret access and changes.

## 14. Future Considerations

- **Multi-Node Control Plane:** For production environments, consider adding multiple control plane nodes for high availability.
- **Cluster Autoscaling:** Implement cluster autoscaler to automatically add/remove worker nodes based on resource utilization.
- **Service Mesh:** Evaluate Istio or Linkerd for advanced traffic management, observability, and security features.
- **Disaster Recovery:** Implement cross-region backup and recovery for the entire cluster state.
