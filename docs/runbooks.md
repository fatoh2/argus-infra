# Argus Infra — Operational Runbooks

This document is the authoritative reference for operating the Argus Kubernetes platform. Keep it updated when adding or changing operational procedures.

**Stack**: Terraform/OpenTofu (Hetzner Cloud) → Ansible (k3s) → ArgoCD (GitOps) → Prometheus/Grafana/Loki

---

## Table of Contents

1. [Cluster Build Procedure](#1-cluster-build-procedure)
2. [k3s Node Failure Recovery](#2-k3s-node-failure-recovery)
3. [pgbackrest Database Restore](#3-pgbackrest-database-restore)
4. [ArgoCD Troubleshooting](#4-argocd-troubleshooting)
5. [Common Troubleshooting](#5-common-troubleshooting)

---

## 1. Cluster Build Procedure

Full procedure to provision a new cluster from scratch: Terraform → Ansible → ArgoCD bootstrap.

### Prerequisites

- Hetzner Cloud account with a project and API token
- Doppler project configured with all required secrets (see `CLAUDE.md`)
- SSH key added to Hetzner Cloud project
- VPS provisioned and configured via `scripts/setup-agent.sh` (tools installed)
- Repo cloned at `/opt/argus/workspaces/argus-infra`

### Phase 1 — Terraform: Provision Hetzner VMs

```bash
cd /opt/argus/workspaces/argus-infra/terraform/environments/homelab

# 1. Authenticate to Hetzner (set token in tfvars or env)
export HCLOUD_TOKEN="<your-hetzner-api-token>"

# 2. Initialise providers
terraform init

# 3. Review the plan — ALWAYS review before applying
terraform plan -out=tfplan

# 4. Apply (creates VMs and private network)
terraform apply tfplan
```

**Expected output**: Server IPs printed in Terraform outputs. Note the control-plane and worker node IPs.

> ⚠️ **Never run `terraform destroy` without explicit user confirmation via Telegram.**

### Phase 2 — Ansible: Install k3s

> **Note**: The `ansible/` directory is the next planned milestone. Once implemented it will contain the k3s cluster playbook. This section documents the intended procedure.

```bash
cd /opt/argus/workspaces/argus-infra/ansible

# 1. Update inventory with IPs from Terraform output
# Edit ansible/inventory/hosts (this file is gitignored — never commit it)
vim ansible/inventory/hosts

# 2. Test SSH connectivity
ansible all -m ping -i ansible/inventory/hosts

# 3. Run the k3s install playbook (control-plane first)
ansible-playbook -i ansible/inventory/hosts ansible/playbooks/k3s-install.yml

# 4. Verify cluster is healthy
export KUBECONFIG=/opt/argus/workspaces/argus-infra/kubeconfig/homelab.yaml
kubectl get nodes -o wide
```

**Expected output**: All nodes in `Ready` state.

```
NAME           STATUS   ROLES                  AGE   VERSION
argus-cp-01    Ready    control-plane,master   2m    v1.31.x+k3s1
argus-work-01  Ready    <none>                 1m    v1.31.x+k3s1
```

### Phase 3 — ArgoCD Bootstrap

```bash
export KUBECONFIG=/opt/argus/workspaces/argus-infra/kubeconfig/homelab.yaml

# 1. Create the argocd namespace
kubectl create namespace argocd

# 2. Download chart dependencies
cd /opt/argus/workspaces/argus-infra/k8s/argocd/install
helm dependency update .

# 3. Install ArgoCD via Helm
helm install argocd . \
  --namespace argocd \
  --values values.yaml \
  --wait --timeout 5m

# 4. Verify ArgoCD pods are running
kubectl get pods -n argocd

# 5. Apply the ArgoCd AppProject and root app-of-apps
kubectl apply -f /opt/argus/workspaces/argus-infra/k8s/argocd/project.yaml
kubectl apply -f /opt/argus/workspaces/argus-infra/k8s/argocd/root-app.yaml

# 6. Get initial ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 7. Port-forward to access the UI (until Ingress is set up)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080  (user: admin, password from step 6)
```

**Expected output**: ArgoCD UI accessible, root-app syncing child applications.

```
NAME       CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH
root-app   https://kubernetes.default.svc  argocd     argus    Synced  Healthy
```

### Verification Checklist

- [ ] All nodes `Ready` in `kubectl get nodes`
- [ ] All ArgoCD pods `Running` in `kubectl get pods -n argocd`
- [ ] ArgoCD root-app status is `Synced / Healthy`
- [ ] `kubectl get applications -n argocd` shows all expected child apps
- [ ] Prometheus targets reachable (if monitoring stack deployed)
- [ ] No pods in `CrashLoopBackOff` or `Pending` state across namespaces

---

## 2. k3s Node Failure Recovery

Procedure for recovering from a k3s node failure (worker or control-plane).

### Prerequisites

- SSH access to remaining healthy nodes
- `KUBECONFIG` set to cluster kubeconfig
- Terraform state available if reprovisioning a VM

### 2a — Worker Node Failure

#### Step 1: Identify the failed node

```bash
kubectl get nodes
# Failed node will show NotReady
```

#### Step 2: Drain the node (if still reachable)

```bash
# Evicts all pods gracefully (60s timeout per pod)
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=60 \
  --timeout=300s
```

#### Step 3a — Repair existing node (SSH recoverable)

```bash
# SSH to the failed node
ssh root@<node-ip>

# Check k3s agent status
systemctl status k3s-agent

# Restart if stopped
systemctl restart k3s-agent
journalctl -u k3s-agent -f   # Watch logs

# Back on the management machine — verify node rejoins
kubectl get nodes --watch
```

#### Step 3b — Replace node (SSH not recoverable)

```bash
# 1. Delete the dead node from the cluster
kubectl delete node <node-name>

# 2. Reprovision via Terraform (update count or taint)
cd terraform/environments/homelab
terraform plan && terraform apply

# 3. Re-run the Ansible k3s-worker playbook targeting the new node
ansible-playbook -i ansible/inventory/hosts \
  ansible/playbooks/k3s-install.yml \
  --limit <new-node-ip>

# 4. Verify the new node joins
kubectl get nodes --watch
```

#### Step 4: Uncordon (if repaired, not replaced)

```bash
kubectl uncordon <node-name>
```

#### Step 5: Verify workloads rescheduled

```bash
kubectl get pods -A -o wide | grep -v Running
# Should show no Pending or Failed pods after a few minutes
```

### 2b — Control-Plane Node Failure

> ⚠️ **Escalate to the user via Telegram before proceeding with control-plane recovery** if the cluster state is uncertain.

```bash
# 1. Identify if etcd / k3s server is still reachable
kubectl cluster-info

# 2. SSH to the control-plane node
ssh root@<cp-node-ip>
systemctl status k3s

# 3. Restart if stopped
systemctl restart k3s
journalctl -u k3s -f

# 4. If data corruption suspected, restore from etcd snapshot
# k3s auto-snapshots are stored at /var/lib/rancher/k3s/server/db/snapshots/
ls /var/lib/rancher/k3s/server/db/snapshots/

# Stop k3s, restore snapshot, restart
systemctl stop k3s
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/<snapshot-file>
systemctl start k3s
```

---

## 3. pgbackrest Database Restore

Procedure to restore PostgreSQL from a pgbackrest backup stored in Backblaze B2.

### Prerequisites

- pgbackrest installed on the target server
- Backblaze B2 credentials available in Doppler
- pgbackrest configuration at `/etc/pgbackrest/pgbackrest.conf`
- PostgreSQL service accessible

> ⚠️ **This is a destructive operation. Always notify the user before restoring production data.**

### Step 1: Verify available backups

```bash
# List all available backup sets
pgbackrest --stanza=argus info

# Example output:
# stanza: argus
#   status: ok
#   db (current):
#     wal archive min/max (16): 000000010000000000000001/00000001000000000000000F
#     full backup: 20240115-020000F
#     diff backup: 20240115-020000F_20240116-020000D
```

### Step 2: Scale down the application

```bash
# Prevent writes to the database during restore
kubectl scale deployment api-service --replicas=0 -n argus-prod
kubectl scale deployment chain-indexer --replicas=0 -n argus-prod

# Verify no connections
kubectl exec -n argus-prod deploy/postgresql -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'argus';"
```

### Step 3: Stop PostgreSQL

```bash
# In the PostgreSQL pod / node
kubectl exec -n argus-prod deploy/postgresql -- \
  pg_ctl stop -D /var/lib/postgresql/data -m fast
```

### Step 4: Restore from backup

```bash
# Restore the latest full backup
pgbackrest --stanza=argus --delta restore

# Or restore a specific backup set
pgbackrest --stanza=argus --delta --set=20240115-020000F restore

# Point-in-time recovery (restore to a specific timestamp)
pgbackrest --stanza=argus --delta \
  --target="2024-01-16 03:00:00" \
  --target-action=promote \
  restore
```

### Step 5: Start PostgreSQL and verify

```bash
# Start PostgreSQL
kubectl exec -n argus-prod deploy/postgresql -- \
  pg_ctl start -D /var/lib/postgresql/data

# Check PostgreSQL is healthy
kubectl exec -n argus-prod deploy/postgresql -- \
  psql -U postgres -c "\l"

# Verify critical tables have expected row counts
kubectl exec -n argus-prod deploy/postgresql -- \
  psql -U postgres -d argus -c "SELECT count(*) FROM wallets;"
```

### Step 6: Scale application back up

```bash
kubectl scale deployment api-service --replicas=2 -n argus-prod
kubectl scale deployment chain-indexer --replicas=1 -n argus-prod

# Watch pods come healthy
kubectl get pods -n argus-prod --watch
```

### Step 7: Run the restore script (automated path)

Once `scripts/restore-db.sh` is implemented, the full procedure above is wrapped in:

```bash
bash scripts/restore-db.sh --stanza argus --target latest
```

---

## 4. ArgoCD Troubleshooting

### App stuck in `OutOfSync`

```bash
# Force a hard refresh (bypasses ArgoCD cache)
argocd app get <app-name> --hard-refresh

# Or via kubectl
kubectl annotate application <app-name> -n argocd \
  argocd.argoproj.io/refresh=hard

# Check sync status details
argocd app diff <app-name>
kubectl describe application <app-name> -n argocd
```

### App stuck in `Progressing`

```bash
# Check pod events in the target namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - PVC not bound (check StorageClass)
# - Image pull error (check imagePullSecrets)
# - Resource quota exceeded
kubectl get pvc -n <namespace>
kubectl get events -n <namespace> | grep -i warning
```

### Reset ArgoCD admin password

```bash
# Generate a new bcrypt hash
NEW_PASSWORD="<your-new-password>"
HASH=$(htpasswd -bnBC 10 "" "$NEW_PASSWORD" | tr -d ':\n')

# Patch the argocd-secret
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {\"admin.password\": \"$HASH\", \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"}}"
```

### ArgoCD self-signed cert causing sync failures

```bash
# The ArgoCD server runs with --insecure (TLS terminated at Ingress)
# If connecting directly (port-forward), bypass TLS:
argocd login localhost:8080 --insecure
```

---

## 5. Common Troubleshooting

### cert-manager: certificate not issued

```bash
# Check certificate and challenge status
kubectl get certificate -A
kubectl get certificaterequest -A
kubectl describe certificate <cert-name> -n <namespace>
kubectl get challenges -A  # ACME HTTP-01 or DNS-01 challenges

# Common issues:
# - DNS not propagated yet (wait ~2 min, then re-check)
# - Ingress annotations missing: kubernetes.io/ingress.class: nginx
# - cert-manager ClusterIssuer misconfigured
kubectl describe clusterissuer letsencrypt-prod
```

### Prometheus target missing

```bash
# Check ServiceMonitor was picked up
kubectl get servicemonitor -A
kubectl describe servicemonitor <name> -n <namespace>

# Verify the label selector matches the Service
# ServiceMonitor must have label: release: kube-prometheus-stack
kubectl get svc -n <namespace> --show-labels

# Check Prometheus config reload
kubectl rollout restart deployment prometheus-operator -n monitoring
```

### Pod stuck in `Pending`

```bash
# Most common causes: insufficient resources, taint/toleration mismatch, PVC unbound
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep <pod-name>

# Check node resource pressure
kubectl describe nodes | grep -A5 "Allocated resources"
```

### External Secrets not syncing

```bash
# Check ExternalSecret status
kubectl get externalsecret -A
kubectl describe externalsecret <name> -n <namespace>

# Verify Doppler SecretStore connection
kubectl get secretstore -A
kubectl describe clustersecretstore doppler
```

---

## Runbook Update Policy

- Update this file in the **same PR** as any operational procedure change.
- CLAUDE.md rule: `ALWAYS update docs/runbooks.md when adding or changing operational procedures`.
- ADRs for architecture decisions go in `docs/adr/YYYY-MM-DD-short-title.md`.
