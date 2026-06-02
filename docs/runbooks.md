# Operational Runbooks for Argus Infra

This document provides operational guidance for deploying, rolling back, scaling, and troubleshooting the Argus Infra platform.

## 1. Tool Installation & Version Checks

### Install Required CLI Tools

Before working with the repo, install all required CLI tools:

```bash
# Install everything (Terraform, Ansible, kubectl, Helm, ArgoCD CLI, k3d, kubeseal)
make install-tools

# Or run the script directly (supports --quiet flag):
bash scripts/install-tools.sh
bash scripts/install-tools.sh --quiet   # minimal output
```

The script is idempotent — re-running it skips already-installed tools. It supports Ubuntu/Debian (22.04+), macOS, and Windows (Git Bash / WSL2). On Linux/macOS it requires `sudo` access for binary installation to `/usr/local/bin/`. On macOS, uses `sudo mv` + `sudo chmod` instead of `sudo install` for compatibility.

### Key Improvements in v2

| Feature | Description |
|---------|-------------|
| **Multi-OS detection** | `detect_os()` function catches Git Bash (`msys`/`cygwin`), WSL2 (`/proc/version`), macOS (`darwin*`), and Linux |
| **GitHub API fallback** | If rate-limited, uses hardcoded fallback versions (Terraform 1.7.5, kubeseal v0.27.1) with a warning |
| **macOS compat** | Uses `sudo mv` + `sudo chmod` instead of `sudo install -o root -g root` |
| **PATH fix** | Adds `~/.local/bin` to PATH before verifying pip-installed Ansible |
| **Explicit errors** | Failed `apt-get update` shows a clear warning instead of failing silently |
| **Quiet mode** | `--quiet` flag for minimal output in automated/CI environments |

### Check Tool Versions

To verify all tools are installed and see their versions:

```bash
make check-versions
# or directly:
bash scripts/versions.sh
```

This prints versions for Terraform, kubectl, Helm, k3d, Ansible, ArgoCD CLI, kubeseal, shellcheck, git, and Docker — plus system info (OS, kernel, arch). Useful for debugging environment issues.

### What Gets Installed

| Tool | Version | Source |
|------|---------|--------|
| Terraform | 1.7.5 (pinned) | HashiCorp releases |
| Ansible (ansible-core) | latest (apt) | Ubuntu repos |
| kubectl | latest stable | Kubernetes releases |
| Helm | v3.17.2 | Helm releases |
| ArgoCD CLI | latest | GitHub releases |
| k3d | latest | k3d releases |
| kubeseal | latest | GitHub releases |

The script also installs required Ansible Galaxy collections from `ansible/requirements.yml` and `kubernetes.core`.

### Makefile Quick Reference

The root `Makefile` provides convenient shortcuts for common operations:

| Command | What it does |
|---------|-------------|
| `make help` | Print all available targets |
| `make lint` | Terraform fmt -check + ansible-lint + shellcheck |
| `make validate` | Terraform init (no backend) + validate |
| `make plan` | Terraform plan (requires `HCLOUD_TOKEN`) |
| `make install-tools` | Install CLI tools (delegates to `scripts/install-tools.sh`) |
| `make local-up` | Spin up local k3d cluster |
| `make local-down` | Tear down local k3d cluster |
| `make check-versions` | Print installed tool versions |
| `make sanity` | Run full local sanity check suite |
| `make setup-windows` | Show Windows setup guide |
| `make bootstrap` | Run Windows bootstrap script (`BOOTSTRAP_WINDOWS.sh`) |

All targets gracefully skip missing tools. Run `make` (or `make help`) to see the full list.

## 2. Deployment
New deployments or updates to the infrastructure are primarily driven by changes in the Terraform or Ansible configurations, followed by ArgoCD syncing Kubernetes manifests.

### Terraform Changes (VMs, Networking)
1.  **Modify Terraform**: Make necessary changes in `terraform/environments/homelab/`.
2.  **Plan and Apply**:
    ```bash
    cd terraform/environments/homelab
    terraform plan
    terraform apply
    ```
    Review the plan carefully before applying.

### Ansible Changes (k3s Configuration)
1.  **Modify Ansible**: Update roles or playbooks in `ansible/`.
2.  **Run Playbook**:
    ```bash
    cd ansible
    ansible-playbook -i inventory/homelab.yml playbooks/site.yml
    ```
    This will apply configuration changes to the k3s cluster.

### ArgoCD Application Deployments
ArgoCD continuously monitors your Git repositories for Kubernetes manifest changes.
1.  **Commit Kubernetes Manifests**: Push changes to your application's Git repository (e.g., `argus-monitor` Kubernetes manifests).
2.  **ArgoCD Sync**: ArgoCD will automatically detect the changes and sync them to the cluster. You can monitor the sync status in the ArgoCD UI.
3.  **Manual Sync/Rollback (ArgoCD UI)**: For immediate deployments or rollbacks, you can trigger these actions directly from the ArgoCD UI.

### Grafana Deployment
Grafana is deployed via ArgoCD as a standalone application from `k8s/grafana/`.
1.  **Modify Grafana Config**: Edit manifests in `k8s/grafana/` (dashboards, datasources, deployment settings).
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new configuration to the cluster.
4.  **Verify**:
    ```bash
    kubectl get pods -n monitoring -l app=grafana
    kubectl get ingress -n monitoring grafana
    ```
5.  **Access Grafana**: Open `https://grafana.argus.local` in your browser. Default credentials: `admin`/`admin`.

### Adding a New Dashboard
1.  **Create the dashboard JSON**: Export or create a Grafana dashboard JSON.
2.  **Add to ConfigMap**: Append the dashboard JSON to the `data` section of `k8s/grafana/configmap-dashboards.yaml` under a new key (e.g., `my-dashboard.json`).
3.  **Register in provisioning**: If adding a new dashboard file, update `k8s/grafana/configmap-provisioning.yaml` to include it in the `providers` section.
4.  **Commit and Sync**: Push changes and let ArgoCD sync. Grafana will pick up the new dashboard without restart.

### NetworkPolicy Deployments
NetworkPolicies are deployed via ArgoCD as part of the `security` application.
1.  **Modify Policies**: Edit manifests in `k8s/security/network-policies/`.
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new policies to the cluster.
4.  **Verify**:
    ```bash
    kubectl get networkpolicies -A
    ```


### Pod Security Standards Deployment
Pod Security Standards are enforced via namespace labels in `k8s/security/pod-security/`.
1.  **Apply Namespace Labels**:
    ```bash
    kubectl apply -f k8s/security/pod-security/
    ```
2.  **Verify Enforcement**:
    ```bash
    kubectl describe ns monitoring
    # Look for: pod-security.kubernetes.io/enforce: restricted
    ```
3.  **Verify Workload Compliance**: After labeling, check that all pods in restricted namespaces are running:
    ```bash
    kubectl get pods -n monitoring
    kubectl get pods -n databases
    ```
    Any pod that violates the restricted profile will be rejected by the admission controller.



### RBAC ServiceAccount Deployment
RBAC resources (ServiceAccounts, ClusterRoles, ClusterRoleBindings) are deployed via ArgoCD as part of the `security` application.
1.  **Modify RBAC**: Edit manifests in `k8s/security/rbac/`.
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new RBAC resources to the cluster.
4.  **Verify**:
    ```bash
    kubectl get serviceaccounts -A | grep -E 'api-service|argocd-manager|prometheus'
    kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus
    ```

### Workload SecurityContext Updates
When adding a new workload to a restricted namespace, ensure its `securityContext` complies:
- Pod-level: `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`
- Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`
- Add `emptyDir` volumes for any writable paths (e.g., `/tmp`)

## 3. Rollback
Rollbacks depend on the component being rolled back.

### Terraform Rollback
Terraform maintains state. To rollback to a previous state:
1.  **Revert Terraform Changes**: Revert the changes in your Git repository to a previous commit.
2.  **Apply Previous State**:
    ```bash
    cd terraform/environments/homelab
    terraform plan
    terraform apply
    ```
    This will attempt to revert the infrastructure to the state defined in the previous commit.

### Ansible Rollback
Ansible playbooks are idempotent. To rollback a configuration:
1.  **Revert Ansible Changes**: Revert the changes in your Git repository to a previous commit.
2.  **Re-run Playbook**:
    ```bash
    cd ansible
    ansible-playbook -i inventory/homelab.yml playbooks/site.yml
    ```
    The playbook will re-apply the older configuration.

### ArgoCD Application Rollback
ArgoCD allows easy rollbacks to previous application versions.
1.  **ArgoCD UI**: In the ArgoCD UI, navigate to the application, select "History and Rollback," and choose the desired previous version to roll back to.
2.  **Git Revert**: Alternatively, revert the Kubernetes manifest changes in your application's Git repository. ArgoCD will detect this and sync the cluster back to the previous state.

## 3. Scaling

### Adding Worker Nodes
1.  **Update Terraform**: Increase the `worker_count` variable in `terraform/environments/homelab/terraform.tfvars`.
2.  **Apply Terraform**: Run `terraform apply` to provision the new VM.
3.  **Update Ansible Inventory**: Add the new worker IP to `ansible/inventory/homelab.yml`.
4.  **Run Ansible**: Run `ansible-playbook -i inventory/homelab.yml playbooks/site.yml` to join the new node to the cluster.

### Removing Worker Nodes
1.  **Drain the Node**: `kubectl drain k8s-worker-X --ignore-daemonsets --delete-emptydir-data`
2.  **Delete the Node**: `kubectl delete node k8s-worker-X`
3.  **Update Terraform**: Decrease the `worker_count` variable.
4.  **Apply Terraform**: Run `terraform apply` to destroy the VM.

## 4. Backup and Restore

### PostgreSQL Backup (pgbackrest)
Backups are automated via a CronJob in `k8s/postgres-backup-cronjob.yaml`.

**Manual Backup:**
```bash
kubectl create job --from=cronjob/postgres-backup manual-backup -n databases
```

**Verify Backup:**
```bash
kubectl logs job/manual-backup -n databases
```

### Restore from Backup
1.  **Identify the backup**: Check pgbackrest info:
    ```bash
    kubectl exec -n databases deployment/postgres -- pgbackrest info
    ```
2.  **Restore**:
    ```bash
    kubectl apply -f k8s/databases/restore-job.yaml
    ```
    See `docs/runbooks.md` for detailed restore procedures.

## 5. Monitoring and Alerting

### Accessing Grafana
- **URL**: `https://grafana.argus.local`
- **Default Credentials**: `admin` / `admin`

### Checking Prometheus Targets
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
# Then visit http://localhost:9090/targets
```

### Viewing Logs in Loki
- Use Grafana's Explore view with the Loki datasource.
- Query example: `{namespace="monitoring"} |= "error"`

## 6. Troubleshooting

### General Troubleshooting

- **Pod CrashLoopBackOff**: Check logs with `kubectl logs <pod> -n <namespace>` and events with `kubectl describe pod <pod> -n <namespace>`.
- **ArgoCD OutOfSync**: Check the ArgoCD UI for details. Common causes: manual changes to the cluster, missing ConfigMaps, or Helm chart issues.
- **Certificate Issues**: Check cert-manager logs and certificate status:
  ```bash
  kubectl get certificates -A
  kubectl describe certificate <name> -n <namespace>
  ```
- **Node NotReady**: Check node status and kubelet logs:
  ```bash
  kubectl describe node <node-name>
  # SSH into the node and check:
  sudo journalctl -u k3s-agent
  ```

### Grafana Troubleshooting
-   **Grafana Pod Not Starting**: Check pod logs for errors:
    ```bash
    kubectl logs -n monitoring deployment/grafana
    ```
    Common issues:
    - **Permission denied**: Grafana's `securityContext` may need `runAsUser: 472` (Grafana's default UID) or an `emptyDir` volume for `/var/lib/grafana`.
    - **Datasource not found**: Verify the Prometheus datasource URL in `k8s/grafana/configmap-datasources.yaml`. The service DNS must match the actual Prometheus service name.
    - **ConfigMap not mounted**: Check that the ConfigMaps referenced in the Deployment exist:
      ```bash
      kubectl get configmap -n monitoring | grep grafana
      ```

-   **Grafana Not Accessible via Ingress**:
    ```bash
    # Check ingress status
    kubectl get ingress -n monitoring grafana
    # Check Traefik is routing correctly
    kubectl get ingressroute -n monitoring
    # Verify DNS resolves grafana.argus.local to the cluster IP
    ```
    If using a local cluster without DNS, add a hosts file entry:
    ```
    <CLUSTER_IP>  grafana.argus.local
    ```

-   **Dashboards Not Showing**:
    ```bash
    # Verify dashboard ConfigMap exists and has content
    kubectl get configmap grafana-dashboards -n monitoring -o yaml | head -20
    # Check Grafana provisioning logs
    kubectl logs -n monitoring deployment/grafana | grep -i provisioning
    ```
    If dashboards are missing, ensure the provisioning ConfigMap (`grafana-datasource-config`) has the correct `dashboards` provider section pointing to the dashboard ConfigMap.

-   **Default Credentials Not Working**: If `admin`/`admin` doesn't work, the password may have been changed. Reset by exec-ing into the pod:
    ```bash
    kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password newpassword
    ```

-   **Grafana Shows "No data" in Panels**:
    ```bash
    # Verify Prometheus is reachable from Grafana
    kubectl exec -n monitoring deployment/grafana -- wget -qO- http://prometheus-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
    # Check Prometheus targets are up
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
    # Then visit http://localhost:9090/targets
    ```

## 7. CI/CD Pipeline

### CI: Sanity Checks (PR-level)
Every PR to `develop` triggers the CI workflow (`.github/workflows/sanity-checks.yml`), which runs:
- Terraform format check
- Terraform validate
- Terraform plan (dry-run)
- Ansible syntax check
- Ansible lint
- ShellCheck (shell script static analysis)
- Critical files existence check

**Required to pass** before a PR can be merged to `develop`.

### CD: Continuous Deployment
Every merge to `main` triggers the CD workflow (`.github/workflows/cd-deploy.yml`) — but only when the merge touches infrastructure-relevant paths (`terraform/**`, `ansible/**`, `k8s/**`, `scripts/**`, or `.github/workflows/cd-deploy.yml`). Docs-only changes are skipped automatically.

The workflow runs three sequential stages:

**Stage 1 — Lint:** Critical files check, Terraform format check, Ansible lint, ShellCheck
**Stage 2 — Build:** Terraform validate + plan (guarded — skips gracefully if `HCLOUD_TOKEN` is not configured)
**Stage 3 — Deploy:** Placeholder (prints instructions for setting up cluster secrets)

All steps are guarded with directory/file existence checks so the workflow passes even when infrastructure directories or secrets are absent.

The deployment flow:
1. Lint stage runs code quality checks and verifies critical files exist
2. Build stage validates infrastructure config compiles end-to-end (skips gracefully if no Terraform or no token)
3. Deploy stage prints setup instructions (placeholder until cluster secrets are configured)
4. ArgoCD detects the change (via webhook or polling) and syncs the cluster

### Cluster Health Monitoring
The `cluster-sanity.yml` workflow runs every 6 hours (conditionally enabled via the `CLUSTER_SANITY_ENABLED` repo variable — a `gate` job ensures the cron always succeeds when the cluster is not configured) and checks:
- All nodes are in `Ready` state
- All pods in critical namespaces are running
- All ArgoCD applications are in `Synced` status
- TLS certificates are not expiring within 30 days
- Node disk usage is below 80%
- Cluster API is responsive

## 8. Security Procedures

### Network Policy Changes
- All changes to `k8s/security/network-policies/` must be reviewed by the PM before merging.
- Test policies in a non-production namespace first if possible.
- After applying, verify connectivity for all affected services.

### Secret Rotation
Secrets are managed via Doppler. To rotate a secret:
1. Update the secret in the Doppler dashboard.
2. External Secrets Operator will automatically sync the new value to the cluster.
3. Restart the affected pods to pick up the new secret:
   ```bash
   kubectl rollout restart deployment/<name> -n <namespace>
   ```

### External Secrets Operator Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|------|
| SecretStore not Ready | Invalid or missing Doppler token | Check `doppler-auth` secret in `external-secrets-operator` namespace: `kubectl get secret -n external-secrets-operator doppler-auth -o jsonpath='{.data.token}' \| base64 -d` |
| ExternalSecret not syncing | SecretStore not Ready | Check SecretStore status: `kubectl get secretstore -n default doppler-backend -o wide` |
| Secret not created | Namespace mismatch | Ensure ExternalSecret and SecretStore are in the same namespace (or use a ClusterSecretStore) |
| ESO pod crash looping | Resource limits too low | Check pod logs: `kubectl logs -n external-secrets-operator deployment/external-secrets` |
| Secret value is stale | refreshInterval not elapsed | Force a refresh by deleting the ExternalSecret pod or waiting for the next sync interval (default: 1h) |

See [docs/secrets.md](secrets.md) for complete setup and verification steps.


### Pod Security Violations
If a pod is rejected due to Pod Security Standards:
1. Check the violation details: `kubectl describe pod <pod> -n <namespace>`
2. Update the pod's `securityContext` to comply with the restricted profile.
3. Re-apply the manifest.

## 9. Disaster Recovery

### Full Cluster Restore
1. Provision new VMs with Terraform.
2. Install k3s with Ansible.
3. Install ArgoCD and point it to the Git repository.
4. ArgoCD will automatically sync all applications to their desired state.
5. Restore PostgreSQL from the latest pgbackrest backup.

### etcd Backup and Restore
k3s uses embedded etcd. To backup:
```bash
kubectl exec -n kube-system etcd-<node-name> -- etcdctl snapshot save /tmp/etcd-snapshot.db
```

To restore, follow the k3s etcd restoration guide.


## 8. Database Backup and Restore

### 7.1 Overview

PostgreSQL backups are handled by a Kubernetes CronJob (`postgres-backup`) running daily at 2 AM UTC in the `databases` namespace. Backups use `pg_dump` with the custom format (compressed, parallel-restore capable) and are uploaded to S3-compatible object storage (MinIO / Backblaze B2 / AWS S3).

**Backup retention**: 30 days (automatic cleanup of older backups).

### 7.2 Backup Architecture

```
CronJob (postgres-backup)
  │  Runs daily at 02:00 UTC
  │
  ├─ pg_dump --format=custom --compress=9
  │     → /tmp/backup.dump
  │
  └─ aws s3 cp → s3://<bucket>/postgres-argus-db-<timestamp>.dump
               → s3://<bucket>/postgres-argus-db-latest.dump (overwrite)
```

**Key files**:
- `k8s/databases/postgres-backup-cronjob.yaml` — CronJob definition
- `k8s/databases/postgres-backup-secret.yaml` — Database credentials
- `k8s/databases/restore-db.sh` — Restore script (run locally with kubectl)

### 7.3 Prerequisites

- PostgreSQL must be deployed and running in the `databases` namespace
- A PostgreSQL user with read access (`backup_user`) must exist
- S3-compatible storage must be configured (see `k8s/aws-s3-credentials.yaml`)
- The `aws-s3-credentials` secret must contain:
  - `access_key_id`
  - `secret_access_key`
  - `endpoint_url` (e.g., `https://s3.eu-central-1.amazonaws.com` or internal MinIO URL)
  - `bucket` (e.g., `argus-backups`)

### 7.4 Creating the Backup User

If the `backup_user` does not exist in PostgreSQL, create it:

```bash
# Connect to the PostgreSQL pod
kubectl exec -n databases deploy/postgresql -- psql -U postgres

# Inside psql:
CREATE USER backup_user WITH PASSWORD 'strong-password';
GRANT CONNECT ON DATABASE argus_db TO backup_user;
GRANT USAGE ON SCHEMA public TO backup_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO backup_user;
\q
```

Then update the password in `k8s/databases/postgres-backup-secret.yaml`:
```bash
echo -n "strong-password" | base64
```

### 7.5 Manual Backup Trigger

To trigger an immediate backup (e.g., before a risky operation):

```bash
kubectl create job --from=cronjob/postgres-backup -n databases manual-backup-$(date +%s)
```

Monitor the backup:
```bash
kubectl logs -n databases -l job-name=manual-backup-<timestamp> --tail=50 -f
```

### 7.6 Restore Procedure

#### Option A: Restore using the script (recommended)

```bash
# From the repo root:
./k8s/databases/restore-db.sh latest
```

The script will:
1. Fetch the latest backup from S3
2. Find the running PostgreSQL pod
3. Copy the backup file to the pod
4. Run `pg_restore --clean --if-exists` (drops existing data first)
5. Verify the restore by counting tables

#### Option B: Restore a specific backup

```bash
# Restore from a specific S3 backup
S3_ENDPOINT=https://s3.eu-central-1.amazonaws.com S3_BUCKET=argus-backups ./k8s/databases/restore-db.sh s3://argus-backups/postgres-argus-db-2024-01-01T02-00-00Z.dump

# Restore from a local file
./k8s/databases/restore-db.sh /path/to/backup.dump
```

#### Option C: Manual restore (step by step)

```bash
# 1. Download the backup
aws s3 cp s3://argus-backups/postgres-argus-db-latest.dump /tmp/restore.dump   --endpoint-url=https://s3.eu-central-1.amazonaws.com

# 2. Find the PostgreSQL pod
PG_POD=$(kubectl get pods -n databases -l app.kubernetes.io/name=postgresql   --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

# 3. Copy backup to pod
kubectl cp /tmp/restore.dump databases/${PG_POD}:/tmp/restore.dump

# 4. Run restore inside the pod
kubectl exec -n databases ${PG_POD} --   pg_restore --dbname=argus_db --username=argus_admin   --clean --if-exists --verbose /tmp/restore.dump

# 5. Clean up
kubectl exec -n databases ${PG_POD} -- rm -f /tmp/restore.dump
rm -f /tmp/restore.dump

# 6. Verify
kubectl exec -n databases ${PG_POD} --   psql -U argus_admin -d argus_db -c   "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';"
```

### 7.7 Restore Drill Checklist

Use this checklist to verify the restore procedure works:

- [ ] Backup file exists in S3 bucket
- [ ] Backup file is valid (not corrupted)
- [ ] PostgreSQL pod is running and accessible
- [ ] Restore completes without errors
- [ ] Table count matches expected value
- [ ] Application can connect and read data after restore
- [ ] No data loss in other databases on the same instance

### 7.8 Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| Backup job fails with "password authentication failed" | Wrong backup credentials | Update `postgres-backup-credentials` secret |
| Backup job fails with "could not translate host name" | PostgreSQL service name wrong | Check `PGHOST` env var in CronJob |
| Backup upload fails with "403" | Invalid S3 credentials | Check `aws-s3-credentials` secret |
| Restore fails with "role does not exist" | Wrong restore user | Use `postgres` superuser or create the role first |
| Restore fails with "database already exists" | Use `--clean` flag | Already included in the script |
| Restore is slow | Large database | Consider using `--jobs=4` for parallel restore |



## 10. Local Cluster Testing with k3d

For development and testing without a production Hetzner Cloud cluster, use the local k3d scripts.

### Prerequisites

The script checks that the following tools are installed before proceeding:

- **k3d** — local Kubernetes cluster (install via `bash scripts/install-tools.sh` or [k3d.io](https://k3d.io))
- **kubectl** — Kubernetes CLI (install via `bash scripts/install-tools.sh` or [kubernetes.io](https://kubernetes.io/docs/tasks/tools/))
- **Helm** — Kubernetes package manager (install via `bash scripts/install-tools.sh` or [helm.sh](https://helm.sh/docs/intro/install/))

If any are missing, the script exits with a clear error message and link to installation instructions.

### Spin Up Local Cluster

```bash
bash scripts/local-cluster.sh
```

This creates a k3d cluster named `argus-local` with:
- Port mappings: `80:80` (HTTP) and `443:443` (HTTPS) via the k3d loadbalancer
- **ArgoCD** installed via Helm in the `argocd` namespace (admin password: `admin`)
- **kube-prometheus-stack** (Prometheus + Grafana + AlertManager) in the `monitoring` namespace
- **Loki** (log aggregation) in the `logging` namespace

The script is fully idempotent:
- Namespace creation uses `--dry-run=client -o yaml | kubectl apply -f -` (safe to re-run)
- Helm repo addition checks if already present before adding (`helm repo list | grep -q`)
- The script waits up to 300 seconds for all pods to become ready

### Access Local Services

```bash
# ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Open: https://localhost:8080
# User: admin | Password: admin

# Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Loki
kubectl port-forward svc/loki -n logging 3100:3100
```

### Test Kubernetes Manifests Locally

Before deploying to production, validate manifests against the local cluster:

```bash
# Apply manifests
kubectl apply -f k8s/security/network-policies/

# Verify pods come up
kubectl get pods -A

# Check ArgoCD syncs correctly
argocd app list
```

### Tear Down Local Cluster

```bash
bash scripts/local-cluster-down.sh
```

This deletes the entire `argus-local` k3d cluster. All resources (pods, volumes, namespaces) are removed.

### Troubleshooting Local Cluster

| Symptom | Likely Cause | Fix |
|---------|-------------|------|
| `k3d: command not found` | k3d not installed | Run `bash scripts/install-tools.sh` |
| `kubectl: command not found` | kubectl not installed | Run `bash scripts/install-tools.sh` |
| `helm: command not found` | helm not installed | Run `bash scripts/install-tools.sh` |
| Cluster already exists | Previous cluster not torn down | Run `bash scripts/local-cluster-down.sh` first |
| ArgoCD pods stuck in Pending | Insufficient resources | Increase Docker resources (min 4GB RAM, 2 CPUs) |
| Helm install fails | Helm repo not updated | Script handles this with `helm repo update` |
| Port conflicts | `:80` or `:443` already in use | Stop other services using those ports, or modify the script |

## GCP VM Deployment

### Provision a Single VM on GCP

```bash
cd terraform/environments/gcp-single-vm

# 1. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID and SSH public key

# 2. Initialize
terraform init

# 3. Preview
terraform plan

# 4. Apply
terraform apply

# 5. Connect
ssh argus@$(terraform output -raw public_ip)
```

### Destroy the VM

```bash
cd terraform/environments/gcp-single-vm
terraform destroy
```

> **Warning:** `terraform destroy` will delete the VM, boot disk, and firewall rules. Data on the boot disk is lost unless a snapshot was taken.

### SSH Access

If you configured `ssh_public_key`, connect with:
```bash
ssh argus@<public-ip>
```

If using `gcloud`:
```bash
gcloud compute ssh argus-vm --zone=us-central1-a --project=<project-id>
```

### Docker Verification

After the VM boots (wait ~2 minutes), verify Docker is running:
```bash
ssh argus@<public-ip> "docker --version && docker compose version"
```

## GCP GKE Deployment

### Provision a GKE Cluster on GCP

```bash
cd terraform/environments/gcp-gke

# 1. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your GCP project ID

# 2. Initialize
terraform init

# 3. Preview
terraform plan

# 4. Apply
terraform apply

# 5. Configure kubectl
$(terraform output -raw kubectl_configure_command)

# 6. Verify
kubectl get nodes
```

### Destroy the GKE Cluster

```bash
cd terraform/environments/gcp-gke
terraform destroy
```

> **Warning:** `terraform destroy` will delete the GKE cluster and all associated resources (nodes, disks, load balancers). Persistent volumes and their data will be lost unless backed up.

### Adding Custom Helm Repos

The GKE module accepts a `helm_repos` variable to add additional Helm repositories:

```hcl
module "argus_gke" {
  source = "../../modules/gcp-gke"

  project_id = var.project_id
  region     = var.region

  helm_repos = {
    "bitnami" = "https://charts.bitnami.com/bitnami"
    "ingress-nginx" = "https://kubernetes.github.io/ingress-nginx"
  }
}
```

### Switching Between Autopilot and Standard

By default, the cluster uses Autopilot mode (`enable_autopilot = true`). To use Standard mode:

```hcl
enable_autopilot   = false
num_nodes          = 3
node_machine_type  = "e2-standard-4"
```

> **Note:** Autopilot and Standard are mutually exclusive. You cannot switch a cluster from Autopilot to Standard (or vice versa) after creation — you must destroy and recreate.


## AWS EC2 Deployment

### Provision a Single EC2 Instance on AWS

```bash
cd terraform/environments/aws-single-vm

# 1. Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your SSH public key

# 2. Initialize
terraform init

# 3. Preview
terraform plan

# 4. Apply
terraform apply

# 5. Connect
ssh argus@$(terraform output -raw public_ip)
```

### Destroy the EC2 Instance

```bash
cd terraform/environments/aws-single-vm
terraform destroy
```

> **Warning:** `terraform destroy` will delete the EC2 instance, VPC, subnet, security group, and Elastic IP. Data on the root volume is lost unless an AMI or snapshot was created.

### SSH Access

If you configured `ssh_public_key`, connect with:
```bash
ssh argus@<public-ip>
```

### Docker Verification

After the instance boots (wait ~2 minutes), verify Docker is running:
```bash
ssh argus@<public-ip> "docker --version && docker compose version"
```

### Module Reference

See the [architecture documentation](architecture.md#17-aws-ec2-module) for the complete module reference (all variables, outputs, and configuration options). See [ADR 0006](adr/0006-aws-ec2-module.md) for the architecture decision record.
