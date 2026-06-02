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

ArgoCD applications are defined in `k8s/argocd/apps/`. To deploy them:

```bash
kubectl apply -f k8s/argocd/apps/
```

This will create the app-of-apps structure, which will then deploy all the individual applications (ingress, monitoring, databases, etc.).

## 5. Grafana Setup

Grafana is deployed automatically by ArgoCD as part of the app-of-apps structure. This section covers post-deployment configuration and verification.

### Verify Grafana Deployment

```bash
kubectl get pods -n monitoring -l app=grafana
kubectl get ingress -n monitoring grafana
```

### Access Grafana

1.  Ensure DNS resolves `grafana.argus.local` to your cluster's ingress IP (or add a hosts file entry for local testing).
2.  Open `https://grafana.argus.local` in your browser.
3.  Log in with the default credentials: `admin` / `admin`.

### Verify Datasources and Dashboards

1.  In Grafana, go to **Configuration > Data Sources**.
2.  You should see **Prometheus** and **Loki** pre-configured.
3.  Go to **Dashboards > Browse**.
4.  You should see two provisioned dashboards: **Node Exporter Full** and **Kubernetes Cluster Overview**.
5.  Open the **Node Exporter Full** dashboard — you should see metrics from all cluster nodes.
6.  Open the **Kubernetes Cluster Overview** dashboard — you should see cluster-level metrics.

### Troubleshooting Grafana

If dashboards or datasources are missing:

1.  Check that the ConfigMaps exist:
    ```bash
    kubectl get configmap -n monitoring | grep grafana
    ```
2.  Check Grafana logs:
    ```bash
    kubectl logs -n monitoring deployment/grafana
    ```
3.  Verify the provisioning files are correctly mounted:
    ```bash
    kubectl exec -n monitoring deployment/grafana -- ls /etc/grafana/provisioning/datasources/
    kubectl exec -n monitoring deployment/grafana -- ls /etc/grafana/provisioning/dashboards/
    ```

## 6. CI/CD Pipeline

The repository includes three GitHub Actions workflows:

- **Sanity Checks** — on every PR to `develop`, validates Terraform, Ansible, and critical files
- **CD Deploy** — on every merge to `main`, validates and triggers ArgoCD sync
- **Cluster Sanity** — scheduled every 6 hours, checks cluster health

See [docs/cicd.md](cicd.md) for full pipeline documentation.

## 7. Next Steps

After the cluster is running and ArgoCD is deployed, the platform is ready for application deployments. See the [architecture document](architecture.md) for details on how components interact, and the [CI/CD pipeline documentation](cicd.md) for how changes flow from Git to the cluster.
