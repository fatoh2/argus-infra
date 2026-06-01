# Argus Infra Runbooks

This document provides operational runbooks for common tasks related to the Argus Infra Kubernetes homelab platform.

## 1. Provision the Homelab K8s VMs (Terraform)

This runbook details the process of provisioning the virtual machines for the Kubernetes cluster on Hetzner Cloud.

### Prerequisites
-   Terraform/OpenTofu `(>= 1.5)` installed locally.
-   A Hetzner Cloud account with an API token (read/write access) generated from Project > Security > API Tokens.
-   An SSH key pair, with the public key already uploaded to your Hetzner Cloud project.

### Steps
1.  Navigate to the Terraform environment directory:
    ```bash
    cd terraform/environments/homelab
    ```
2.  Copy the example `terraform.tfvars` file and edit it. **This file is `.gitignore`d and should never be committed to Git.**
    ```bash
    cp terraform.tfvars.example terraform.tfvars
    # Open terraform.tfvars and set your hcloud_token and ssh_key_name
    ```
3.  Initialize Terraform:
    ```bash
    terraform init
    ```
4.  Review the Terraform plan to understand what resources will be created:
    ```bash
    terraform plan
    ```
5.  Apply the Terraform configuration to provision the VMs:
    ```bash
    terraform apply --auto-approve
    ```
    This command will create the private network, subnet, and three virtual machines (one control plane, two workers) on Hetzner Cloud.

### Outputs
Upon successful application, Terraform will output important information:
-   `control_plane_ip`: The public IPv4 address of the `k8s-control` node.
-   `worker_ips`: A map of worker node names to their public IPv4 addresses.
-   `ssh_commands`: Ready-to-use `ssh root@<ip>` commands for each node.

### Internal Addressing
| Node          | Private IP  |
|---------------|-------------|
| k8s-control   | 10.0.1.10   |
| k8s-worker-1  | 10.0.1.11   |
| k8s-worker-2  | 10.0.1.12   |

The private network is `10.0.0.0/16`, with a subnet `10.0.1.0/24` in the `eu-central` zone.

## 2. Deploy/Update Applications (ArgoCD GitOps)

Applications are deployed and updated via ArgoCD, following GitOps principles. Changes to Kubernetes manifests in the configured Git repository will be automatically synchronized to the cluster.

### Prerequisites
-   ArgoCD is bootstrapped and configured to sync from your Git repository (as per `docs/setup.md`).
-   You have access to the Git repository containing your Kubernetes manifests.

### Steps
1.  Make changes to your application's Kubernetes manifests (e.g., deployments, services, ingresses) in the designated Git repository (e.g., `k8s/core` in `argus-infra`).
2.  Commit and push your changes to the `develop` branch (or the branch ArgoCD is configured to monitor).
    ```bash
    git add .
    git commit -m "feat: deploy new application version"
    git push origin develop
    ```
3.  ArgoCD, configured with `--sync-policy automated --self-heal`, will detect the changes in the Git repository.
4.  ArgoCD will automatically pull the latest manifests and apply them to the Kubernetes cluster, bringing the cluster's state in line with the Git repository.
5.  You can monitor the synchronization status and application health via the ArgoCD UI (`https://localhost:8080` after port-forwarding) or using the `argocd` CLI:
    ```bash
    argocd app list
    argocd app get argus-core
    ```

## 3. Rollback Application Deployments

Leveraging Git for version control, rolling back an application to a previous state is straightforward.

### Steps
1.  Identify the commit hash of the desired previous state in your Git repository.
2.  Revert the problematic commit or create a new commit that undoes the changes.
    ```bash
    # To revert the last commit
    git revert HEAD --no-edit
    git push origin develop

    # Or to revert a specific commit (replace <commit-hash>)
    git revert <commit-hash> --no-edit
    git push origin develop
    ```
3.  ArgoCD will detect the reverted changes in the Git repository and automatically apply the previous, stable version of your application manifests to the Kubernetes cluster.
4.  Verify the rollback through the ArgoCD UI or CLI.

## 4. Scale Kubernetes Worker Nodes

Scaling the cluster involves adding or removing worker nodes. This process combines Terraform for VM management and Ansible for k3s integration.

### To Add Worker Nodes
1.  **Update Terraform Configuration:**
    -   Edit `terraform/environments/homelab/main.tf` to increase the `worker_count` variable or add new worker node definitions.
    -   Run `terraform plan` to review the changes.
    -   Run `terraform apply --auto-approve` to provision the new VMs.
2.  **Update Ansible Inventory:**
    -   After new VMs are provisioned, update `ansible/inventory.ini` with the public IP addresses of the new worker nodes.
    -   Add new entries under the `[k3s_node]` section, similar to existing worker nodes.
3.  **Run Ansible Playbook:**
    -   Execute the Ansible playbook to join the new worker nodes to the k3s cluster:
        ```bash
        cd ansible
        ansible-playbook -i inventory.ini playbook.yml
        ```
4.  **Verify:** Check the cluster status to ensure the new nodes are `Ready`:
    ```bash
    kubeconfig=~/.kube/config-argus-infra kubectl get nodes
    ```

### To Remove Worker Nodes
1.  **Drain and Delete Node (Kubernetes):**
    -   First, cordon and drain the node you wish to remove to gracefully evict pods:
        ```bash
        kubeconfig=~/.kube/config-argus-infra kubectl cordon k8s-worker-X
        kubeconfig=~/.kube/config-argus-infra kubectl drain k8s-worker-X --ignore-daemonsets --delete-emptydir-data
        ```
    -   Then, delete the node from the Kubernetes cluster:
        ```bash
        kubeconfig=~/.kube/config-argus-infra kubectl delete node k8s-worker-X
        ```
2.  **Update Terraform Configuration:**
    -   Edit `terraform/environments/homelab/main.tf` to decrease the `worker_count` variable or remove the specific worker node definition.
    -   Run `terraform plan` to review the changes.
    -   Run `terraform apply --auto-approve` to de-provision the VM from Hetzner Cloud.
3.  **Update Ansible Inventory:**
    -   Remove the corresponding entry for the deleted worker node from `ansible/inventory.ini`.

## 5. Troubleshooting Common Issues

This section provides guidance for diagnosing and resolving common issues within the Argus Infra environment.

### 5.1. SSH Connection Issues to VMs

**Problem:** Cannot SSH into a newly provisioned VM or an existing node.

**Possible Causes & Solutions:**
-   **Incorrect IP Address:** Double-check the public IP address from Terraform outputs or Hetzner Cloud console.
-   **SSH Key Mismatch:** Ensure the correct SSH key is loaded in your SSH agent (`ssh-add -l`) and that the corresponding public key is registered with Hetzner Cloud and associated with the VM.
-   **Firewall Rules:** Verify Hetzner Cloud firewall rules allow SSH (port 22) traffic from your IP address.
-   **VM Not Running:** Check the VM status in the Hetzner Cloud console.

### 5.2. Kubernetes Nodes Not Ready

**Problem:** `kubectl get nodes` shows one or more nodes in `NotReady` state.

**Possible Causes & Solutions:**
-   **Network Connectivity:** Ensure private network connectivity between control plane and worker nodes. Check `ping` between nodes using their private IPs.
-   **k3s Service Status:** SSH into the problematic node and check the k3s service status:
    ```bash
    systemctl status k3s # For control plane
    systemctl status k3s-agent # For worker nodes
    journalctl -u k3s # Or k3s-agent for logs
    ```
-   **Resource Constraints:** Check CPU, memory, and disk usage on the node. Insufficient resources can cause nodes to become `NotReady`.
-   **Firewall on Node:** Ensure `ufw` or other host firewalls on the VM are not blocking necessary Kubernetes ports (e.g., 6443, 10250).

### 5.3. ArgoCD Application Sync Failures

**Problem:** ArgoCD application shows `Sync Failed` or `Degraded` status.

**Possible Causes & Solutions:**
-   **Manifest Errors:** Check the Kubernetes manifests in your Git repository for syntax errors or invalid configurations. ArgoCD UI will often show specific error messages.
-   **Resource Conflicts:** Another resource might already exist with the same name in the target namespace. Check `kubectl get events -n <namespace>`.
-   **Permissions Issues:** ArgoCD might not have sufficient permissions to create/update resources. Review ArgoCD's RBAC configuration.
-   **Network Connectivity to API Server:** Ensure ArgoCD can reach the Kubernetes API server.
-   **Git Repository Access:** Verify ArgoCD has correct credentials (SSH key or token) to access the Git repository.

### 5.4. Terraform Apply Failures

**Problem:** `terraform apply` fails during provisioning.

**Possible Causes & Solutions:**
-   **Hetzner Cloud API Token:** Ensure your `hcloud_token` is correct and has sufficient permissions.
-   **Resource Limits:** You might have hit resource limits in your Hetzner Cloud project (e.g., maximum VMs). Check your project limits.
-   **SSH Key Name:** Verify `ssh_key_name` in `terraform.tfvars` exactly matches the name of the SSH key uploaded to Hetzner Cloud.
-   **Provider Issues:** Check Terraform provider documentation for Hetzner Cloud for any known issues or specific requirements.

## 6. Architecture Decision Records (ADRs)

ADRs document significant architectural decisions made for the Argus Infra project. They explain the context, decision, and consequences.

-   [ADR-0001-k3s-vs-kubeadm.md](adr/ADR-0001-k3s-vs-kubeadm.md): Decision to use k3s over kubeadm for Kubernetes cluster setup.
-   [ADR-0002-argocd-for-gitops.md](adr/ADR-0002-argocd-for-gitops.md): Decision to use ArgoCD for GitOps management.

**Note:** New ADRs should be created for any significant architectural choices made during the project's evolution.

## 7. Teardown Infrastructure

This runbook describes how to completely destroy the Argus Infra environment. **This is a destructive operation and MUST be confirmed by the user in Telegram before execution.**

### Steps
1.  Navigate to the Terraform environment directory:
    ```bash
    cd terraform/environments/homelab
    ```
2.  Initiate the destroy process:
    ```bash
    terraform destroy
    ```
3.  Terraform will display a plan of all resources that will be destroyed. Carefully review this plan.
4.  Confirm the destruction by typing `yes` when prompted.

**WARNING:** This will permanently delete all provisioned VMs, networks, and associated data on Hetzner Cloud. Ensure you have backed up any necessary data before proceeding.
