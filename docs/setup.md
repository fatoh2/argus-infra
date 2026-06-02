# Argus Infra Setup

This document outlines the steps to set up the Argus Infrastructure repository — a Kubernetes homelab platform on Hetzner Cloud (k3s), GCP Compute Engine (single VM), or GCP GKE (managed Kubernetes) using Terraform, Ansible, and ArgoCD.

## Prerequisites

Before you begin, ensure you have the following:

- **Git** — for cloning the repository
- **Hetzner Cloud API Token** — create one in your Hetzner Cloud project under **Security > API Tokens**
- **Google Cloud Platform account** — with billing enabled (required for GCP deployments)
- **CLI tools** — install all required tools with one command (see below)

### Automated Tool Installation

The recommended way to install all required CLI tools is via the Makefile:

```bash
make install-tools
```

This is equivalent to running `bash scripts/install-tools.sh` and installs (or skips if already present):

| Tool | Version | Purpose |
|------|---------|---------|
| **Terraform** | 1.5.7 (pinned) | Provision Hetzner Cloud VMs |
| **Ansible** (ansible-core) | latest | Configure k3s cluster |
| **kubectl** | latest stable | Interact with Kubernetes |
| **Helm** | 3.17.2 | Package manager for K8s |
| **ArgoCD CLI** | latest | GitOps management (optional — can use Web UI instead) |
| **k3d** | latest | Local K8s cluster for testing |
| **kubeseal** | latest | SealedSecrets management |

The script also installs required Ansible Galaxy collections from `ansible/requirements.yml` and `kubernetes.core`.

> **Note:** The script targets Ubuntu/Debian (22.04+) and requires `sudo` access for binary installation to `/usr/local/bin/`. Each tool checks if already installed and skips if present. One tool failure doesn't block others.

To verify all tools are installed correctly:

```bash
make check-versions
```

Or directly:

```bash
bash scripts/versions.sh
```

### Manual Installation (if needed)

If you prefer to install tools individually, refer to each tool's official documentation.

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

> **Note:** If you used `make install-tools` (or `scripts/install-tools.sh`), Ansible Galaxy collections are already installed. Skip to running the playbook.

Install required Ansible Galaxy collections (if not already done):

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

By default, the ArgoCD API server is exposed via a `ClusterIP` service. To access the UI, you can port-forward:

```bash
kubectl port-forward -n argocd service/argocd-server 8080:443
```

Then open `https://localhost:8080` in your browser.

The default username is `admin`. Retrieve the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Configure ArgoCD with Git Repository

1. Log in to the ArgoCD UI or CLI
2. Add your Git repository:
   ```bash
   argocd repo add git@github.com:fatoh2/argus-infra.git --ssh-private-key-path ~/.ssh/argus_homelab
   ```
3. Create the root application:
   ```bash
   argocd app create argocd-root \
     --repo git@github.com:fatoh2/argus-infra.git \
     --path k8s/argocd \
     --dest-server https://kubernetes.default.svc \
     --dest-namespace argocd \
     --sync-policy automated
   ```

ArgoCD will now sync all applications defined in `k8s/argocd/apps/` to the cluster.

## 5. Verify the Cluster

### Check Node Status

```bash
kubectl get nodes
```

All nodes should show `Ready`.

### Check System Pods

```bash
kubectl get pods -A
```

### Run Local Sanity Checks

```bash
make sanity
```

Or directly:

```bash
bash scripts/run-sanity-checks.sh
```

## Next Steps

- Review the [Architecture](docs/architecture.md) document for a deep dive into component design
- Check the [CI/CD Pipeline](docs/cicd.md) for how changes are validated and deployed
- See the [Runbooks](docs/runbooks.md) for operational procedures
- Browse [Architecture Decision Records](docs/adr/) for design rationale


## 6. Alternative: GCP Compute Engine (Single VM)

For lightweight deployments, testing, or running Argus components that don't require a full Kubernetes cluster, you can deploy a single VM on Google Cloud Platform instead of provisioning a Hetzner k3s cluster.

### Prerequisites

- **Google Cloud Platform account** — with billing enabled
- **GCP project** — create one at [console.cloud.google.com](https://console.cloud.google.com)
- **SSH key pair** — for accessing the VM
- **CLI tools** — `make install-tools` installs Terraform (the GCP provider is downloaded automatically)

### Provision the VM

```bash
cd terraform/environments/gcp-single-vm

# Copy and edit the example vars
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your GCP project ID and SSH public key:

```hcl
project_id      = "my-gcp-project"       # Required: your GCP project ID
ssh_public_key  = "ssh-rsa AAA..."        # Required: your public SSH key
region          = "us-central1"           # Optional: GCP region
machine_type    = "e2-standard-4"         # Optional: VM size
boot_disk_size  = 100                     # Optional: disk size in GB
```

Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

### Connect to the VM

```bash
# Using the SSH key configured in terraform.tfvars
ssh argus@$(terraform output -raw public_ip)

# Or using gcloud (if you have the Google Cloud SDK installed)
gcloud compute ssh argus-vm --zone=us-central1-a --project=<project-id>
```

### Verify Docker

After the VM boots (wait ~2 minutes), verify Docker and Docker Compose are installed:

```bash
ssh argus@$(terraform output -raw public_ip) "docker --version && docker compose version"
```

### Destroy the VM

```bash
cd terraform/environments/gcp-single-vm
terraform destroy
```

> **Warning:** `terraform destroy` will delete the VM, boot disk, and firewall rules. Data on the boot disk is lost unless a snapshot was taken.

### Full Reference

See the [architecture documentation](architecture.md#15-gcp-compute-engine-module) for the complete module reference (all variables, outputs, and configuration options). See the [runbooks](runbooks.md#gcp-vm-deployment) for operational procedures.

## 7. Alternative: GCP GKE (Managed Kubernetes)

For a fully managed Kubernetes cluster on Google Cloud Platform, Argus Infra includes a Terraform module for deploying a GKE cluster with Autopilot mode. This eliminates the need to manage control plane nodes or worker VMs.

### Prerequisites

- **Google Cloud Platform account** — with billing enabled
- **GCP project** — create one at [console.cloud.google.com](https://console.cloud.google.com)
- **Google Cloud SDK (`gcloud`)** — for authenticating with GCP and configuring kubectl
- **CLI tools** — `make install-tools` installs Terraform (the GCP provider is downloaded automatically)

### Provision the GKE Cluster

```bash
cd terraform/environments/gcp-gke

# Copy and edit the example vars
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your GCP project ID:

```hcl
project_id = "my-gcp-project"       # Required: your GCP project ID
# region           = "us-central1"  # Optional: GCP region
# cluster_name     = "argus-cluster" # Optional: cluster name
# enable_autopilot = true           # Optional: Autopilot mode (default: true)
# release_channel  = "REGULAR"      # Optional: GKE release channel
```

Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

### Configure kubectl

After the cluster is created, configure kubectl to point to your new GKE cluster:

```bash
# Using the output command
$(terraform output -raw kubectl_configure_command)

# Or manually using gcloud
gcloud container clusters get-credentials argus-cluster --region us-central1 --project my-gcp-project
```

### Verify the Cluster

```bash
kubectl get nodes
# All nodes should show Ready state
kubectl get pods -A
# CoreDNS and other system pods should be running
```

### Default Helm Repos

The GKE module automatically adds the following Helm repositories after cluster creation:

| Name | URL |
|------|-----|
| argo | `https://argoproj.github.io/argo-helm` |
| traefik | `https://traefik.github.io/charts` |
| prometheus-community | `https://prometheus-community.github.io/helm-charts` |
| grafana | `https://grafana.github.io/helm-charts` |
| jetstack | `https://charts.jetstack.io` |
| external-secrets | `https://charts.external-secrets.io` |

### Destroy the Cluster

```bash
cd terraform/environments/gcp-gke
terraform destroy
```

> **Warning:** `terraform destroy` will delete the GKE cluster and all associated resources (nodes, disks, load balancers). Persistent volumes and their data will be lost unless backed up.

### Full Reference

See the [architecture documentation](architecture.md#16-gcp-gke-module) for the complete module reference (all variables, outputs, and configuration options). See the [runbooks](runbooks.md#gcp-gke-deployment) for operational procedures.
