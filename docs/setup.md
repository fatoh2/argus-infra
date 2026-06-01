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

ArgoCD applications are defined in the `argocd/apps/` directory. To deploy them, either:

1. **Via the ArgoCD UI:** Click "New App" and configure the source pointing to this repository.
2. **Via the ArgoCD CLI (requires ArgoCD CLI installed):**
   ```bash
   argocd app create <app-name> --repo https://github.com/fatoh2/argus-infra.git --path argocd/apps/<app-name> --dest-server https://kubernetes.default.svc --dest-namespace <namespace>
   ```
3. **Via kubectl:** Apply the Application manifests directly:
   ```bash
   kubectl apply -f argocd/apps/<app-name>/application.yaml
   ```


## 5. Deploy Cluster Applications via ArgoCD

Once ArgoCD is bootstrapped, deploy the cluster infrastructure applications. These are defined as ArgoCD Application manifests in `k8s/argocd/apps/` and can be applied in dependency order.

### 5.1 Ingress Stack (Traefik + cert-manager + TLS)

The ingress stack provides external routing and automatic TLS certificates:

```bash
# Create the ingress namespace
kubectl create namespace ingress

# Deploy the ingress application (manages Traefik, cert-manager, and wildcard cert)
kubectl apply -f k8s/argocd/apps/ingress.yaml
```

This deploys:
- **Traefik** — ingress controller with HTTP→HTTPS redirect (NodePorts 30080/30443)
- **cert-manager** — automatic TLS certificate management
- **ClusterIssuer** — Let's Encrypt production issuer
- **Wildcard certificate** — `*.argus-infra.dev` TLS certificate

> **Note:** Before the wildcard certificate provisions, update the domain and email placeholders in `k8s/ingress/wildcard-certificate.yaml` and `k8s/ingress/cluster-issuer.yaml` to match your actual domain.

### 5.2 Monitoring Stack (Prometheus + Grafana)

Deploy the monitoring stack for cluster metrics and visualization:

```bash
# Create the monitoring namespace
kubectl create namespace monitoring

# Deploy Prometheus via the monitoring app-of-apps
kubectl apply -f k8s/argocd/apps/monitoring.yaml

# Deploy Grafana (dashboards and provisioning)
kubectl apply -f k8s/argocd/apps/grafana.yaml
```

This deploys:
- **kube-prometheus-stack** — Prometheus, Alertmanager, node exporters, service monitors
- **Grafana** — pre-configured with dashboards and Prometheus datasource

### 5.3 Logging Stack (Loki + Promtail)

Deploy centralized log aggregation:

```bash
# Deploy Loki
kubectl apply -f k8s/argocd/apps/loki/application.yaml

# Deploy Promtail (DaemonSet for log collection)
kubectl apply -f k8s/argocd/apps/loki/promtail.yaml
```

This deploys:
- **Loki** — log aggregation system with persistent storage
- **Promtail** — log collection agent running on every node

### 5.4 Verify Deployments

Check that all applications are synced in ArgoCD:

```bash
argocd app list
```

Or via kubectl:

```bash
kubectl get applications -n argocd
```

Wait for all pods to be ready:

```bash
kubectl -n ingress get pods
kubectl -n monitoring get pods
kubectl -n traefik get pods
kubectl -n cert-manager get pods
```

## 6. CI Workflow

The repository includes a GitHub Actions workflow (`.github/workflows/sanity-checks.yml`) that runs on every PR to `develop`. It performs:

- **Terraform validate** — checks configuration syntax
- **Terraform format check** — ensures consistent formatting
- **Terraform plan** — validates configuration with dummy variable values (no real infrastructure is provisioned)
- **Ansible syntax check** — verifies playbook syntax using a CI-specific inventory (`inventory/homelab.ci.yml`) with dummy IPs
- **Ansible lint** — lints all playbooks and roles for best practices

> **CI implementation detail:** Ansible steps run inside a dedicated Python virtual environment (`/tmp/ansible-lint-venv`). Ansible Galaxy collections are installed using the venv's `ansible-galaxy` so that `ansible-lint` (which uses the venv's bundled `ansible-core`) can resolve modules like `community.general`. The syntax check also uses the venv's `ansible-playbook` for consistency. This avoids "couldn't resolve module/action" errors.
> **Note:** The Terraform plan step uses dummy values for `hcloud_token`, `ssh_key_name`, `ssh_key_id`, `location`, `server_type`, and `image`. These are for syntax validation only. In a real deployment, these variables are populated from `terraform.tfvars` or CI secrets.
