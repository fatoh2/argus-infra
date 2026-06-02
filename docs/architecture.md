# Argus Infra Architecture

This document provides an in-depth explanation of the Argus Infra components and their interactions, detailing the design choices and how they contribute to a robust and scalable Kubernetes homelab platform.

## 1. Overview

Argus Infra is a fully GitOps-driven Kubernetes homelab platform running on Hetzner Cloud, with additional deployment options on GCP (Compute Engine, GKE) and AWS (EC2). The architecture follows a layered approach:

1. **Infrastructure** — Hetzner Cloud VMs, GCP Compute Engine VMs, GKE clusters, or AWS EC2 instances provisioned via Terraform
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

Secrets are managed securely using External Secrets Operator (ESO) with Doppler as the backend.

### External Secrets Operator
- **Deployment:** Deployed via Helm chart in the `security` namespace.
- **Secret Stores:** Configured to pull secrets from Doppler projects.
- **External Secrets:** Define which secrets to sync from Doppler into Kubernetes Secrets.

### Doppler
- **Backend:** Doppler serves as the central secrets management platform.
- **Projects:** Each application (e.g., `argus-monitor`, `argus-ai`) has its own Doppler project.
- **Integration:** ESO authenticates with Doppler using a service token stored in a Kubernetes Secret.

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
2. **CD (Continuous Deployment)** — runs on infrastructure-relevant merges to `main` (path-filtered) via `.github/workflows/cd-deploy.yml`

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

The `cluster-sanity.yml` workflow runs on a scheduled basis (every 6 hours) to perform cluster-level health checks:

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

## 15. GCP Compute Engine Module

Argus Infra includes a Terraform module for deploying a single VM on Google Cloud Platform (GCP). This is useful for lightweight deployments, testing, or running Argus components that don't require a full Kubernetes cluster.

### Module: `modules/gcp-compute-engine`

The GCP Compute Engine module provisions:

- **Compute Engine VM** — Ubuntu 22.04 LTS with configurable machine type and disk size
- **Firewall Rules** — SSH (22), HTTP (80), and HTTPS (443) with configurable source CIDR ranges
- **External IP** — Optional ephemeral public IP address
- **Startup Script** — Installs Docker and Docker Compose on first boot

### Usage

```hcl
module "argus_vm" {
  source = "../../modules/gcp-compute-engine"

  project_id      = "my-gcp-project"
  name            = "argus-vm"
  region          = "us-central1"
  machine_type    = "e2-standard-4"
  boot_disk_size  = 100
  enable_public_ip = true

  ssh_public_key = var.ssh_public_key
  ssh_user       = "argus"

  tags = ["argus", "argus-vm", "http-server", "https-server"]

  labels = {
    project = "argus"
    env     = "production"
  }

  create_firewall_rules = true
}
```

### Variables

| Variable | Default | Description |
|---|---|---|
| `project_id` | (required) | GCP project ID |
| `name` | `argus-vm` | VM instance name |
| `region` | `us-central1` | GCP region |
| `zone` | `null` (auto) | GCP zone |
| `machine_type` | `e2-standard-4` | Machine type |
| `boot_disk_size` | `100` | Boot disk size (GB) |
| `boot_disk_type` | `pd-standard` | Disk type |
| `boot_disk_image` | `ubuntu-os-cloud/ubuntu-2204-lts` | OS image |
| `enable_public_ip` | `true` | Assign external IP |
| `ssh_public_key` | `null` | SSH public key content |
| `ssh_user` | `argus` | SSH username |
| `create_firewall_rules` | `true` | Create SSH/HTTP/HTTPS rules |
| `allowed_ssh_cidrs` | `["0.0.0.0/0"]` | SSH source CIDRs |
| `allowed_http_cidrs` | `["0.0.0.0/0"]` | HTTP source CIDRs |
| `allowed_https_cidrs` | `["0.0.0.0/0"]` | HTTPS source CIDRs |

### Outputs

| Output | Description |
|---|---|
| `instance_id` | Instance ID |
| `instance_name` | Instance name |
| `instance_self_link` | Self-link (URI) of the instance |
| `zone` | GCP zone where the instance was created |
| `machine_type` | Machine type of the instance |
| `network_ip` | Private IP address |
| `nat_ip` | Public IP address (if enabled) |
| `nat_ips` | List of external IPs assigned to the instance |
| `instance_public_ip` | Alias for `nat_ip` — external public IP (if enabled) |
| `ssh_command` | Ready-to-use SSH command |
| `firewall_rule_names` | Created firewall rule names |

### Quick Start

```bash
cd terraform/environments/gcp-single-vm

# Copy and edit the example vars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and SSH key

# Initialize and plan
terraform init
terraform plan

# Apply
terraform apply

# Connect
ssh argus@$(terraform output -raw public_ip)
```

## 16. GCP GKE Module

Argus Infra includes a Terraform module for deploying a Google Kubernetes Engine (GKE) cluster on GCP. This enables running Argus on a managed Kubernetes service with Autopilot mode for reduced operational overhead.

### Module: `modules/gcp-gke/`

**Purpose:** Provision a GKE cluster (Autopilot by default) with kubectl configured and Helm repositories pre-added.

**Key Variables:**
- `project_id` (required) — GCP project ID
- `region` — GCP region (default: `us-central1`)
- `cluster_name` — GKE cluster name (default: `argus-cluster`)
- `num_nodes` — Node count for Standard mode (default: 3; ignored by Autopilot)
- `node_machine_type` — Machine type for Standard mode (default: `e2-standard-4`; ignored by Autopilot)
- `enable_autopilot` — Enable Autopilot mode (default: `true`)
- `release_channel` — GKE release channel (default: `REGULAR`)
- `network` / `subnetwork` — VPC configuration
- `enable_private_endpoint` / `enable_private_nodes` — Private cluster settings
- `deletion_protection` — Prevent accidental cluster deletion
- `helm_repos` — Map of Helm repositories to add after cluster creation

**Outputs:**

| Output | Description |
|---|---|
| `cluster_id` | GKE cluster ID |
| `cluster_name` | GKE cluster name |
| `cluster_location` | Location (region or zone) of the GKE cluster |
| `cluster_endpoint` | Cluster Kubernetes endpoint IP/DNS |
| `cluster_ca_certificate` | Base64-encoded CA certificate (sensitive) |
| `cluster_kubernetes_version` | Kubernetes version running on the cluster |
| `cluster_autopilot_enabled` | Whether Autopilot mode is enabled |
| `cluster_release_channel` | GKE release channel (REGULAR/RAPID/STABLE) |
| `kubeconfig_path` | Path to generated kubeconfig file (if `generate_kubeconfig` is enabled) |
| `kubeconfig_generated` | Whether a kubeconfig file was generated |
| `kubectl_configure_command` | Command to configure kubectl for this cluster |
| `network` | VPC network used by the cluster |
| `subnetwork` | Subnetwork used by the cluster |
| `cluster_self_link` | Self-link (URI) of the GKE cluster |
| `node_pool_name` | Primary node pool name (Standard mode only) |
| `node_pool_node_count` | Primary node pool node count (Standard mode only) |

**Default Helm Repos Added:**
| Name | URL |
|------|-----|
| argo | `https://argoproj.github.io/argo-helm` |
| traefik | `https://traefik.github.io/charts` |
| prometheus-community | `https://prometheus-community.github.io/helm-charts` |
| grafana | `https://grafana.github.io/helm-charts` |
| jetstack | `https://charts.jetstack.io` |
| external-secrets | `https://charts.external-secrets.io` |

**Usage:**
```hcl
module "argus_gke" {
  source = "../../modules/gcp-gke"

  project_id = var.project_id
  region     = var.region

  cluster_name      = "argus-cluster"
  enable_autopilot  = true
  release_channel   = "REGULAR"
}
```

**Done when:** `kubectl get nodes` shows all nodes in Ready state.


## 17. AWS EC2 Module

Argus Infra includes a Terraform module for deploying a single EC2 instance on Amazon Web Services (AWS). This mirrors the GCP Compute Engine module and is useful for lightweight deployments, testing, or running Argus components on AWS without a full Kubernetes cluster.

### Module: `modules/aws-ec2`

The AWS EC2 module provisions:

- **VPC** — Custom VPC (10.0.0.0/16) with DNS support and hostnames enabled
- **Internet Gateway** — For public internet access
- **Public Subnet** — In a configurable availability zone
- **Route Table** — Default route to the Internet Gateway
- **Security Group** — SSH (22), HTTP (80), and HTTPS (443) with configurable source CIDR ranges
- **EC2 Instance** — Ubuntu 22.04 LTS with configurable instance type (default: t3.xlarge) and 100 GB gp3 root volume
- **Elastic IP** — Static public IP address (optional, enabled by default)
- **SSH Key Pair** — Injected from a provided public key
- **IAM Role** — Optional IAM role with configurable policy attachments
- **Startup Script** — Installs Docker and Docker Compose on first boot

### Usage

```hcl
module "argus_ec2" {
  source = "../../modules/aws-ec2"

  name            = "argus-vm"
  region          = "us-east-1"
  instance_type   = "t3.xlarge"
  root_volume_size = 100

  ssh_public_key = var.ssh_public_key
  ssh_user       = "argus"

  enable_elastic_ip = true

  tags = {
    Name    = "argus-vm"
    Project = "argus"
    Env     = "production"
  }
}
```

### Variables

| Variable | Default | Description |
|---|---|---|
| `name` | `argus-vm` | EC2 instance name |
| `region` | `us-east-1` | AWS region |
| `availability_zone` | `null` (auto) | AWS availability zone |
| `instance_type` | `t3.xlarge` | EC2 instance type |
| `root_volume_size` | `100` | Root volume size (GB) |
| `root_volume_type` | `gp3` | Root volume type |
| `ami_owner` | `099720109477` | Canonical (Ubuntu) AWS account ID |
| `ami_name_filter` | `ubuntu/images/hvm-ssd-gp3/ubuntu-22.04-amd64-server-*` | AMI name filter |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `subnet_cidr` | `10.0.1.0/24` | Public subnet CIDR |
| `enable_dns_hostnames` | `true` | Enable DNS hostnames in VPC |
| `enable_elastic_ip` | `true` | Allocate and associate Elastic IP |
| `ssh_public_key` | `null` | SSH public key content |
| `ssh_user` | `argus` | SSH username |
| `allowed_ssh_cidrs` | `["0.0.0.0/0"]` | SSH source CIDRs |
| `allowed_http_cidrs` | `["0.0.0.0/0"]` | HTTP source CIDRs |
| `allowed_https_cidrs` | `["0.0.0.0/0"]` | HTTPS source CIDRs |
| `create_iam_role` | `false` | Create an IAM role for the instance |
| `iam_role_name` | `argus-ec2-role` | IAM role name |
| `iam_policy_arns` | `[]` | List of IAM policy ARNs to attach |
| `tags` | `{}` | Resource tags |

### Outputs

| Output | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `instance_arn` | EC2 instance ARN |
| `instance_state` | EC2 instance state |
| `instance_type` | EC2 instance type |
| `public_ip` | Public IP address (if Elastic IP enabled) |
| `private_ip` | Private IP address |
| `public_dns` | Public DNS name |
| `vpc_id` | VPC ID |
| `subnet_id` | Subnet ID |
| `security_group_id` | Security group ID |
| `ssh_command` | Ready-to-use SSH command |
| `elastic_ip` | Elastic IP address (if enabled) |
| `elastic_ip_allocation_id` | Elastic IP allocation ID |
| `key_pair_name` | SSH key pair name |
| `iam_role_name` | IAM role name (if created) |
| `iam_role_arn` | IAM role ARN (if created) |

### Quick Start

```bash
cd terraform/environments/aws-single-vm

# Copy and edit the example vars
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH public key

# Initialize and plan
terraform init
terraform plan

# Apply
terraform apply

# Connect
ssh argus@$(terraform output -raw public_ip)
```

### What the module does NOT do

- It does **not** install Kubernetes or k3s — this is intentionally a single-VM module
- It does **not** manage DNS records (Route53)
- It does **not** provision additional EBS volumes beyond the root volume
- It does **not** set up monitoring or observability
- It does **not** create a VPC with private subnets or NAT gateways (single public subnet only)

These are left to the user or future enhancements. See [ADR 0006](adr/0006-aws-ec2-module.md) for the full decision record.
