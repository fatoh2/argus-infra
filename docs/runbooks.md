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
    This command will create the private network, subnet, and virtual machines (one control plane, two workers by default) on Hetzner Cloud.

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
1.  Make changes to your application's Kubernetes manifests (e.g., deployments, services, ingresses) in the designated Git repository (e.g., `k8s/argocd/apps` in `argus-infra`).
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
    -   After new VMs are provisioned, update `ansible/inventory/homelab.yml` with the public IP addresses of the new worker nodes.
    -   Add new entries under the `k3s_node` group, similar to existing worker nodes.
3.  **Run Ansible Playbook:**
    -   Execute the Ansible playbook to join the new worker nodes to the k3s cluster:
        ```bash
        cd ansible
        ansible-playbook -i inventory/homelab.yml playbooks/site.yml
        ```
4.  **Verify:** Check the cluster status to ensure the new nodes are `Ready`:
    ```bash
    export KUBECONFIG=~/.kube/config-argus-infra
    kubectl get nodes
    ```

### To Remove Worker Nodes
1.  **Drain and Delete Node (Kubernetes):**
    -   First, cordon and drain the node you wish to remove to gracefully evict pods:
        ```bash
        export KUBECONFIG=~/.kube/config-argus-infra
        kubectl cordon k8s-worker-X
        kubectl drain k8s-worker-X --ignore-daemonsets --delete-emptydir-data
        ```
    -   Then, delete the node from the Kubernetes cluster:
        ```bash
        export KUBECONFIG=~/.kube/config-argus-infra
        kubectl delete node k8s-worker-X
        ```
2.  **Update Terraform Configuration:**
    -   Edit `terraform/environments/homelab/main.tf` to decrease the `worker_count` variable or remove the specific worker node definition.
    -   Run `terraform plan` to review the changes.
    -   Run `terraform apply --auto-approve` to de-provision the VM from Hetzner Cloud.
3.  **Update Ansible Inventory:**
    -   Remove the entry for the deleted worker node from `ansible/inventory/homelab.yml`.
4.  **Verify:** Check the cluster status to ensure the node is no longer present:
    ```bash
    export KUBECONFIG=~/.kube/config-argus-infra
    kubectl get nodes
    ```

## 5. Troubleshoot Common Issues

### 5.1. SSH Connection Issues

-   **Verify SSH Key:** Ensure your public SSH key is uploaded to Hetzner Cloud and the private key is correctly configured on your local machine.
-   **Firewall:** Check Hetzner Cloud firewall rules and any host-based firewalls (e.g., `ufw` on Ubuntu) to ensure SSH port 22 is open.
-   **IP Address:** Double-check the public IP address of the VM you are trying to connect to.

### 5.2. Terraform Apply Failures

-   **API Token:** Ensure your `hcloud_token` in `terraform.tfvars` is correct and has read/write permissions.
-   **Resource Limits:** Check your Hetzner Cloud project limits. You might be trying to provision more VMs or resources than allowed.
-   **Syntax Errors:** Review your `terraform.tfvars` and `.tf` files for any syntax errors.
-   **State File Corruption:** If `terraform apply` fails repeatedly, consider backing up and then deleting `terraform.tfstate` (only as a last resort in development environments) and re-running `terraform init` and `terraform apply`.

### 5.3. Ansible Playbook Failures

-   **SSH Connectivity:** Ensure Ansible can connect to all target VMs via SSH. Test with `ssh root@<ip>`.
-   **Inventory File:** Verify that `ansible/inventory/homelab.yml` is correctly populated with the public IP addresses of your VMs.
-   **Permissions:** Ensure the SSH user (default `root`) has necessary permissions on the target VMs.
-   **Idempotency:** Ansible playbooks are designed to be idempotent. Rerunning the playbook often resolves transient issues.

### 5.4. Kubernetes Pods Not Starting/Crashing

-   **Check Pod Logs:**
    ```bash
    export KUBECONFIG=~/.kube/config-argus-infra
    kubectl logs <pod-name> -n <namespace>
    ```
-   **Describe Pod:** Get detailed information about the pod, including events and conditions:
    ```bash
    export KUBECONFIG=~/.kube/config-argus-infra
    kubectl describe pod <pod-name> -n <namespace>
    ```
-   **Resource Limits:** Check if the pod is requesting more resources (CPU/memory) than available on the node.
-   **Image Pull Issues:** Ensure the container image exists and is accessible from the cluster.

### 5.5. ArgoCD Sync Issues

-   **Repository Access:** Verify ArgoCD has correct credentials to access the Git repository.
-   **Manifest Errors:** Check Kubernetes manifests in Git for syntax errors or invalid configurations.
-   **ArgoCD Logs:** Check ArgoCD server and application controller logs for errors:
    ```bash
    export KUBECONFIG=~/.kube/config-argus-infra
    kubectl logs -f deploy/argocd-server -n argocd
    kubectl logs -f deploy/argocd-application-controller -n argocd
    ```
-   **Manual Sync/Refresh:** In the ArgoCD UI, try a manual `Refresh` or `Sync` to force reconciliation.
