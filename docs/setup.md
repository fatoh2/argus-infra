# Setup Guide for Argus Infra

This guide will walk you through the process of setting up the Argus Infra Kubernetes homelab platform.

## Prerequisites
Before you begin, ensure you have the following installed on your local machine:
- Git
- Terraform (v1.0.0+)
- Ansible (v2.10+)
- kubectl
- Helm
- Hetzner Cloud API Token: Create one in your Hetzner Cloud project settings.

## 1. Clone the Repository
```bash
git clone https://github.com/fatoh2/argus-infra.git
cd argus-infra
```

## 2. Terraform Provisioning (Hetzner VMs)

### Configuration
Navigate to the Terraform environment directory:
```bash
cd terraform/environments/homelab
```
Copy the example variables file and fill in your Hetzner API token and desired VM configuration:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Hetzner API token and other settings
```

### Initialize and Apply
```bash
terraform init
terraform plan
terraform apply
```
This will provision the virtual machines on Hetzner Cloud.

## 3. Ansible Configuration (k3s Cluster Setup)

### Inventory
After Terraform completes, it will output the IP addresses of your provisioned VMs. Update the Ansible inventory file with these IPs.
Navigate to the Ansible directory:
```bash
cd ../../../ansible
```
Copy the example inventory and update it:
```bash
cp inventory/homelab.yml.example inventory/homelab.yml
# Edit inventory/homelab.yml with the actual IP addresses of your VMs
```

### Run Playbook
```bash
ansible-galaxy install -r requirements.yml
ansible-playbook -i inventory/homelab.yml playbooks/site.yml
```
This will install k3s on your VMs, setting up the Kubernetes cluster.

## 4. ArgoCD Bootstrap (GitOps)

### Access Kubernetes
Once Ansible completes, your Kubernetes cluster will be running. You can get the kubeconfig from your k3s server.
```bash
# Example: scp user@your-k3s-server-ip:~/.kube/config ~/.kube/config-argus-infra
export KUBECONFIG=~/.kube/config-argus-infra
```

### Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Get ArgoCD Initial Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### Access ArgoCD UI
Forward the ArgoCD server port to your local machine:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Open your browser to `https://localhost:8080` and log in with username `admin` and the password retrieved above.

## 5. Deploy Applications with ArgoCD
Once ArgoCD is running, you can configure it to sync with your application repositories (e.g., `argus-monitor`, `argus-ai`) to deploy applications using GitOps principles.
