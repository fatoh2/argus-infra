# Argus Infrastructure Setup Guide

This document outlines the comprehensive process for setting up the Argus infrastructure from scratch, including VM provisioning on Hetzner Cloud, Ansible configuration, k3s cluster deployment, and ArgoCD bootstrapping for GitOps management.

## Prerequisites

Before you begin, ensure you have the following:

-   **Hetzner Cloud Account:** An active account with sufficient credit.
-   **Hetzner Cloud API Token:** Generate a read/write API token from your Hetzner Cloud Project > Security > API Tokens. Keep this token secure.
-   **SSH Key Pair:** An SSH key pair (e.g., `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`). The public key must be uploaded to your Hetzner Cloud project.
-   **Local Tools:**
    -   **Terraform/OpenTofu (`>= 1.5`):** For infrastructure provisioning.
    -   **Ansible (`>= 2.10`):** For configuration management.
    -   **Git:** For cloning repositories and version control.
    -   **kubectl:** Kubernetes command-line tool (will be configured after k3s setup).
    -   **argocd CLI:** ArgoCD command-line tool (will be installed during setup).

## 1. Clone the Repository

Start by cloning the `argus-infra` repository to your local machine:

```bash
git clone https://github.com/fatoh2/argus-infra.git
cd argus-infra
```

## 2. VM Provisioning (Terraform/OpenTofu)

This step provisions the virtual machines on Hetzner Cloud that will form your Kubernetes cluster.

### 2.1. Configure Terraform Variables

Navigate to the Terraform environment directory and create your `terraform.tfvars` file. **This file is `.gitignore`d and should never be committed to Git.**

```bash
cd terraform/environments/homelab
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set the following variables:

-   `hcloud_token`: Your Hetzner Cloud API token.
-   `ssh_key_name`: The name of the SSH key you uploaded to Hetzner Cloud.
-   `location`: (Optional) The Hetzner Cloud datacenter location (e.g., `fsn1`, `nbg1`, `hel1`). Default is `fsn1`.
-   `control_plane_type`: (Optional) VM type for the control plane (e.g., `cx11`, `cpx21`). Default is `cpx11`.
-   `worker_type`: (Optional) VM type for worker nodes. Default is `cpx11`.
-   `worker_count`: (Optional) Number of worker nodes. Default is `2`.

Example `terraform.tfvars`:

```hcl
hcloud_token = "your_hetzner_cloud_api_token"
ssh_key_name = "your_ssh_key_name_on_hetzner"
location     = "fsn1"
```

### 2.2. Initialize and Apply Terraform

```bash
terraform init
terraform plan # Review the resources that will be created
terraform apply --auto-approve
```

Upon successful application, Terraform will output the public IP addresses of your control plane and worker nodes. Make a note of these, especially the `control_plane_ip` and `worker_ips`.

## 3. Ansible Configuration and k3s Deployment

Ansible is used to configure the provisioned VMs, install k3s, and join the worker nodes to the cluster.

### 3.1. Update Ansible Inventory

Navigate back to the root of the `argus-infra` repository and then into the `ansible` directory.

```bash
cd ../../ansible
```

Create or update the `inventory/homelab.yml` file with the public IP addresses of your control plane and worker nodes obtained from the Terraform output. Replace the placeholder IPs with your actual IPs. A good practice is to use a tool or script to generate this from Terraform outputs, but for manual setup, you can create it as follows:

Example `inventory/homelab.yml` snippet:

```yaml
all:
  hosts:
    k8s-control:
      ansible_host: YOUR_CONTROL_PLANE_PUBLIC_IP
    k8s-worker-1:
      ansible_host: YOUR_WORKER_1_PUBLIC_IP
    k8s-worker-2:
      ansible_host: YOUR_WORKER_2_PUBLIC_IP
  children:
    k3s_control_plane:
      hosts:
        k8s-control:
    k3s_node:
      hosts:
        k8s-worker-1:
        k8s-worker-2:
```

### 3.2. Run Ansible Playbook

Execute the Ansible playbook to set up k3s on your nodes, specifying the inventory file:

```bash
ansible-playbook -i inventory/homelab.yml playbooks/site.yml
```

This playbook will:
-   Install necessary dependencies.
-   Configure the firewall.
-   Install k3s on the control plane node.
-   Join worker nodes to the k3s cluster.
-   Copy the `kubeconfig` file from the control plane to your local machine.

### 3.3. Configure kubectl

The Ansible playbook will place the `kubeconfig` file in `~/.kube/config-argus-infra`. You can use it directly or merge it with your existing `kubeconfig`.

To use it directly:

```bash
export KUBECONFIG=~/.kube/config-argus-infra
kubectl get nodes
```

You should see your `k8s-control` and `k8s-worker-X` nodes in a `Ready` state.

## 4. ArgoCD Bootstrapping

ArgoCD is deployed to manage your Kubernetes applications using GitOps principles.

### 4.1. Install ArgoCD CLI

```bash
# For Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argocd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# For macOS (using Homebrew)
# brew install argocd
```

### 4.2. Run ArgoCD Bootstrap Script

Navigate to the `scripts` directory and execute the bootstrap script:

```bash
cd ../scripts
./bootstrap-argocd.sh
```

This script will:
-   Create the `argocd` namespace.
-   Install ArgoCD components into the cluster.
-   Configure ArgoCD to sync from the `k8s/argocd/apps` directory in this repository.

### 4.3. Access ArgoCD UI

To access the ArgoCD web UI, first retrieve the initial admin password:

```bash
argocd admin initial-password -n argocd
```

Then, port-forward the ArgoCD server to your local machine:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open your browser to `https://localhost:8080` and log in with username `admin` and the password you retrieved. Accept the self-signed certificate warning.

### 4.4. Configure Git Repository in ArgoCD

ArgoCD needs to know about your `argus-infra` Git repository. While the `bootstrap-argocd.sh` script attempts to set this up, you might need to manually add it if using a private repository or specific SSH keys.

From the ArgoCD UI:
1.  Go to `Settings` > `Repositories`.
2.  Click `+ NEW REPO`.
3.  Enter the repository URL (`https://github.com/fatoh2/argus-infra.git`).
4.  If it's a private repo, configure SSH or HTTPS credentials.

Alternatively, using the CLI:

```bash
argocd repo add https://github.com/fatoh2/argus-infra.git --username <your-github-username> --password <your-github-token>
```

**Note:** For private repositories, it is recommended to use SSH keys for ArgoCD to access the repository. Refer to the ArgoCD documentation for detailed instructions on configuring SSH repository access.
