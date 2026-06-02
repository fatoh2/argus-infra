# Argus Infra Setup

This document outlines the steps to set up the Argus Infrastructure repository — a Kubernetes homelab platform on Hetzner Cloud (k3s), GCP Compute Engine (single VM), GCP GKE (managed Kubernetes), or AWS EC2 (single VM) using Terraform, Ansible, and ArgoCD.

## Prerequisites

Before you begin, ensure you have the following:

- **Git** — for cloning the repository
- **Hetzner Cloud API Token** — create one in your Hetzner Cloud project under **Security > API Tokens**
- **Google Cloud Platform account** — with billing enabled (required for GCP deployments)
- **AWS account** — with billing enabled and AWS credentials configured (required for AWS deployments)
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

SSH into the control plane node:

```bash
ssh root@<CONTROL_PLANE_IP>
```

The k3s kubeconfig is at `/etc/rancher/k3s/k3s.yaml`. Copy it to your local machine:

```bash
# On your local machine:
scp root@<CONTROL_PLANE_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

### Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Access the ArgoCD Web UI

By default, the ArgoCD API server is not exposed externally. To access it:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Then open https://localhost:8080 in your browser.

The default username is `admin`. Get the initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Deploy Applications via ArgoCD

The repository includes ArgoCD Application manifests in the `k8s/argocd/` directory. To deploy monitoring:

```bash
kubectl apply -f k8s/argocd/monitoring.yaml
```

This will deploy Prometheus, Grafana, and Loki to your cluster via ArgoCD.

## GCP Compute Engine (Single VM)

### Prerequisites

- Google Cloud Platform account with billing enabled
- GCP project created
- Service account with `compute.admin` role (or use `gcloud auth application-default login`)

### Configure Variables

```bash
cd terraform/environments/gcp-single-vm
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"
ssh_public_key = "ssh-ed25519 AAAAC3... your@email.com"
```

### Provision

```bash
terraform init
terraform apply
```

### Connect

```bash
ssh argus@$(terraform output -raw public_ip)
```

## GCP GKE (Managed Kubernetes)

### Prerequisites

- Google Cloud Platform account with billing enabled
- GCP project with Kubernetes Engine API enabled
- Service account with `container.admin` and `compute.admin` roles

### Configure Variables

```bash
cd terraform/environments/gcp-gke
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
```

### Provision

```bash
terraform init
terraform apply
```

### Configure kubectl

```bash
gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region=us-central1
kubectl get nodes
```

## AWS EC2 (Single VM)

### Prerequisites

- AWS account with billing enabled
- AWS CLI configured with credentials (`aws configure`)
- EC2 key pair created in your chosen region

### Configure Variables

```bash
cd terraform/environments/aws-single-vm
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region      = "us-east-1"
key_name        = "your-ec2-key-pair-name"
ssh_public_key  = "ssh-ed25519 AAAAC3... your@email.com"
```

### Provision

```bash
terraform init
terraform apply
```

### Connect

```bash
ssh argus@$(terraform output -raw public_ip)
```

## Troubleshooting

### Terraform

- **"Error: No valid credential sources found"** — Ensure your cloud provider credentials are configured correctly.
- **"Error: Quota exceeded"** — Request a quota increase in your cloud provider console.

### Ansible

- **"Permission denied (publickey)"** — Verify the SSH key path in your inventory file and ensure the key is added to your SSH agent.
- **"Timeout when waiting for k3s"** — Check that the VM has outbound internet access and sufficient resources.

### ArgoCD

- **"Connection refused"** — Ensure the ArgoCD server pod is running: `kubectl get pods -n argocd`
- **"Invalid username or password"** — Reset the admin password: `argocd account update-password`

### GKE

- **"Error 403: Required 'container.clusters.get' permission"** — Ensure your service account has the `container.admin` role.
- **"Cluster is in 'ERROR' state"** — Check the GCP Console for specific error details. Common causes include insufficient quota or misconfigured networking.

## Cleanup

To avoid ongoing charges, destroy resources when not in use:

### Hetzner

```bash
cd terraform/environments/homelab
terraform destroy
```

### GCP Compute Engine

```bash
cd terraform/environments/gcp-single-vm
terraform destroy
```

### GCP GKE

```bash
cd terraform/environments/gcp-gke
terraform destroy
```

### AWS EC2

```bash
cd terraform/environments/aws-single-vm
terraform destroy
```

### Local k3d

```bash
make local-down
```
