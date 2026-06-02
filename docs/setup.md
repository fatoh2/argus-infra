# Argus Infra Setup

This document outlines the steps to set up the Argus Infrastructure repository — a Kubernetes homelab platform on Hetzner Cloud using Terraform, Ansible, and ArgoCD.

## Prerequisites

Before you begin, ensure you have the following installed on your local machine:

- **Git** — for cloning the repository
- **Terraform** (v1.0.0+) — for provisioning Hetzner Cloud VMs
- **Ansible** (v2.10+) — for configuring the k3s cluster
- **kubectl** — for interacting with the Kubernetes cluster
- **Hetzner Cloud API Token** — create one in your Hetzner Cloud project under **Security > API Tokens**

> **ArgoCD CLI** is optional. It is only needed if you prefer CLI-based management of ArgoCD applications over the Web UI or `kubectl`. Installation instructions are provided in the ArgoCD section below.

## 1. Clone the Repository

```bash
git clone git@github.com:fatoh2/argus-infra.git
cd argus-infra
```

## 2. Terraform Provisioning (Hetzner VMs)

### Configure Variables

Navigate to the Terraform environment directory:

```bash
cd terraform/environments/homelab
```

Copy the example variables file and fill in your Hetzner API token and desired VM configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your Hetzner API token and other settings:

```hcl
hcloud_token = "YOUR_HETZNER_API_TOKEN"   # Required: your Hetzner Cloud API token
ssh_key_name = "argus-homelab"            # Required: name of an SSH key uploaded to your Hetzner project
location     = "nbg1"                     # Optional: default is nbg1
server_type  = "cx22"                     # Optional: default is cx22
image        = "ubuntu-24.04"             # Optional: default is ubuntu-24.04
```

> **Security note:** `terraform.tfvars` is gitignored and should never be committed. The example file (`terraform.tfvars.example`) is what gets version-controlled.

### Initialize and Apply

```bash
terraform init
```

Review the plan before applying:

```bash
terraform plan
```

Apply the configuration to provision the VMs:

```bash
terraform apply
```

You will be prompted to confirm with `yes`. For non-interactive runs, use `-auto-approve`:

```bash
terraform apply -auto-approve
```

### Get VM IP Addresses from Terraform Output

After Terraform completes, retrieve the IP addresses of your provisioned VMs:

```bash
terraform output control_plane_ip
terraform output worker_ips
```

These IPs are needed for the Ansible inventory in the next step.

## 3. Ansible Configuration (k3s Cluster Setup)

### Prepare Inventory

Navigate to the Ansible directory:

```bash
cd ../../ansible
```

Copy the example inventory file:

```bash
cp inventory/homelab.yml.example inventory/homelab.yml
```

Edit `inventory/homelab.yml` with the actual IP addresses from Terraform's output:

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/argus_homelab
    k3s_version: ""
  children:
    k3s_server:
      hosts:
        k8s-control:
          ansible_host: <CONTROL_PLANE_IP>   # Replace with the IP from `terraform output control_plane_ip`
    k3s_agent:
      hosts:
        k8s-worker-1:
          ansible_host: <WORKER_1_IP>        # Replace with the first worker IP
        k8s-worker-2:
          ansible_host: <WORKER_2_IP>        # Replace with the second worker IP
    k3s_cluster:
      children:
        k3s_server:
        k3s_agent:
```

> **CI note:** The repository includes `inventory/homelab.ci.yml` with dummy IPs (RFC 5737 TEST-NET range) for use in CI syntax checks. This file is not used for actual deployments.

### Run Playbook

Install required Ansible Galaxy collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

Run the site playbook to install k3s on your VMs:

```bash
ansible-playbook -i inventory/homelab.yml playbooks/site.yml
```

This will install and configure k3s on your VMs, setting up the Kubernetes cluster with one control-plane node and two worker nodes.

## 4. ArgoCD Bootstrap (GitOps)

### Access the Kubernetes Cluster

Once Ansible completes, retrieve the kubeconfig from the k3s server. If you don't know the server IP, check the Terraform output again:

```bash
cd ../terraform/environments/homelab
terraform output control_plane_ip
```

Then copy the kubeconfig from the server:

```bash
# Replace <CONTROL_PLANE_IP> with the actual IP from the step above
scp root@<CONTROL_PLANE_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config-argus-infra
```

Set the `KUBECONFIG` environment variable:

```bash
export KUBECONFIG=~/.kube/config-argus-infra
```

Verify cluster access:

```bash
kubectl get nodes
```

### Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for all ArgoCD pods to be ready:

```bash
kubectl -n argocd wait --for=condition=ready pod --all --timeout=300s
```

### Access the ArgoCD UI

By default, the ArgoCD API server is not exposed externally. To access the UI, you can port-forward:

```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Then open https://localhost:8080 in your browser.

### Get ArgoCD Initial Password

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

> **Security note:** This command prints the password to your terminal. In a shared or CI environment, be mindful of terminal logging. Consider storing it in a password manager immediately after first login.

Log in to the ArgoCD UI or CLI with:
- **Username:** `admin`
- **Password:** (the output of the command above)

For CLI login (requires ArgoCD CLI — optional, only needed if you prefer CLI over the Web UI):

```bash
argocd login localhost:8080 --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
```

### Deploy ArgoCD Applications

ArgoCD applications are defined in the `k8s/argocd/apps/` directory. The root application (`app-of-apps.yaml`) manages all child applications.

To deploy, apply the root application manifest:

```bash
kubectl apply -f k8s/argocd/app-of-apps.yaml
```

ArgoCD will automatically detect the new application and sync it, deploying all child applications defined in `k8s/argocd/apps/`.


### 4.3 Access Grafana

After ArgoCD syncs the Grafana application, Grafana will be available at `https://grafana.argus.local`.

1.  **Verify Grafana is running**:
    ```bash
    kubectl get pods -n monitoring -l app=grafana
    ```
    Wait until the pod shows `Running` and `READY 1/1`.

2.  **Check the Ingress**:
    ```bash
    kubectl get ingress -n monitoring grafana
    ```
    The ingress should show the host `grafana.argus.local` with the Traefik ingress class.

3.  **Access Grafana**:
    - If DNS is configured, open `https://grafana.argus.local` in your browser.
    - If DNS is not configured, add a hosts file entry:
      ```
      <CLUSTER_IP>  grafana.argus.local
      ```
      Where `<CLUSTER_IP>` is the IP of any cluster node (or the Traefik load balancer IP).

4.  **Log in** with the default credentials:
    - **Username:** `admin`
    - **Password:** `admin`
    
    > **Security note:** Change the default password on first login. For production use, configure a secure password via Doppler and External Secrets Operator.

5.  **Verify the Prometheus datasource**:
    - Go to **Configuration > Data Sources** in the Grafana UI.
    - The Prometheus datasource should be pre-configured and show a green "Data source is working" badge.

6.  **Explore starter dashboards**:
    - Go to **Dashboards > Browse**.
    - You should see the provisioned dashboards: **Node Exporter Full** and **Kubernetes Cluster Overview**.
    - Open a dashboard and verify it shows metrics from the cluster.

### 4.4 Deploy Pod Security Standards

After the cluster applications are deployed, enforce Pod Security Standards (restricted profile) on all application namespaces:

```bash
# Apply namespace labels for restricted profile
kubectl apply -f k8s/security/pod-security/

# Verify enforcement
kubectl describe ns monitoring
# Should show: pod-security.kubernetes.io/enforce: restricted
```

This labels the following namespaces with `pod-security.kubernetes.io/enforce: restricted`:
- `monitoring` — Prometheus, Grafana, Loki, Promtail
- `databases` — PostgreSQL, Redis
- `ingress` — Traefik, cert-manager, wildcard TLS
- `traefik` — Traefik ingress controller
- `cert-manager` — cert-manager operator
- `default` — General application workloads

> **Note:** The `kube-system` and `argocd` namespaces are intentionally excluded from the restricted profile, as system-level components may require elevated privileges.

### 4.5 Verify Workload Compliance

After applying the restricted profile, verify that all existing workloads comply:

```bash
# Check all pods are running
kubectl get pods -A

# Check for any admission controller rejections
kubectl describe pod -n monitoring | grep -i "violates PodSecurity"
```

If any pods fail to start due to Pod Security violations, refer to the [runbooks](runbooks.md#pod-security-standards-troubleshooting) for remediation steps.

## 5. Running Sanity Checks

The repository includes a local sanity check suite to validate changes before committing. Run it from the repository root:

```bash
# Basic sanity check (Terraform validate + fmt, Ansible syntax check + lint, file structure)
./scripts/run-sanity-checks.sh

# With verbose output
./scripts/run-sanity-checks.sh --verbose

# Skip ansible-lint (useful if not installed)
./scripts/run-sanity-checks.sh --skip-ansible-lint
```

The sanity suite performs:
- **Terraform**: `init -backend=false`, `validate`, `fmt -check -recursive`, `plan` (syntax-only, no apply)
- **Ansible**: `--syntax-check` on `site.yml` with CI inventory, `ansible-lint` on playbooks/roles
- **File structure**: verifies all critical files exist (Terraform configs, Ansible playbooks, ArgoCD manifests)
- **ArgoCD**: kubectl dry-run validation of manifests (if a cluster is available)

### Cluster-Level Checks (with a running cluster)

If you have access to a running cluster, you can run additional checks:

```bash
# Full cluster sanity (nodes, pods, ArgoCD apps, ingress)
./scripts/cluster-sanity.sh --verbose

# ArgoCD-specific health check
./scripts/argocd-health.sh --verbose
```

These scripts are also run automatically via GitHub Actions:
- **Sanity Checks** — on every PR to `develop` or `main`, and on push to those branches
- **Cluster Sanity** — every 6 hours via scheduled workflow (requires `CLUSTER_SANITY_ENABLED` repository variable)

## Next Steps

After the cluster is running and ArgoCD is deployed, the platform is ready for application deployments. See the [architecture document](architecture.md) for details on how components interact.
