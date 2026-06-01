# Operational Runbooks for Argus Infra

This document provides operational guidance for deploying, rolling back, scaling, and troubleshooting the Argus Infra platform.

## 1. Deployment
New deployments or updates to the infrastructure are primarily driven by changes in the Terraform or Ansible configurations, followed by ArgoCD syncing Kubernetes manifests.

### Terraform Changes (VMs, Networking)
1.  **Modify Terraform**: Make necessary changes in `terraform/environments/homelab/`.
2.  **Plan and Apply**:
    ```bash
    cd terraform/environments/homelab
    terraform plan
    terraform apply
    ```
    Review the plan carefully before applying.

### Ansible Changes (k3s Configuration)
1.  **Modify Ansible**: Update roles or playbooks in `ansible/`.
2.  **Run Playbook**:
    ```bash
    cd ansible
    ansible-playbook -i inventory/homelab.yml playbooks/site.yml
    ```
    This will apply configuration changes to the k3s cluster.

### ArgoCD Application Deployments
ArgoCD continuously monitors your Git repositories for Kubernetes manifest changes.
1.  **Commit Kubernetes Manifests**: Push changes to your application's Git repository (e.g., `argus-monitor` Kubernetes manifests).
2.  **ArgoCD Sync**: ArgoCD will automatically detect the changes and sync them to the cluster. You can monitor the sync status in the ArgoCD UI.
3.  **Manual Sync/Rollback (ArgoCD UI)**: For immediate deployments or rollbacks, you can trigger these actions directly from the ArgoCD UI.

## 2. Rollback
Rollbacks depend on the component being rolled back.

### Terraform Rollback
Terraform maintains state. To rollback to a previous state:
1.  **Revert Terraform Changes**: Revert the changes in your Git repository to a previous commit.
2.  **Apply Previous State**:
    ```bash
    cd terraform/environments/homelab
    terraform plan
    terraform apply
    ```
    This will attempt to revert the infrastructure to the state defined in the previous commit.

### Ansible Rollback
Ansible playbooks are idempotent. To rollback a configuration:
1.  **Revert Ansible Changes**: Revert the changes in your Git repository to a previous commit.
2.  **Re-run Playbook**:
    ```bash
    cd ansible
    ansible-playbook -i inventory/homelab.yml playbooks/site.yml
    ```
    The playbook will re-apply the older configuration.

### ArgoCD Application Rollback
ArgoCD allows easy rollbacks to previous application versions.
1.  **ArgoCD UI**: In the ArgoCD UI, navigate to the application, select "History and Rollback," and choose the desired previous version to roll back to.
2.  **Git Revert**: Alternatively, revert the Kubernetes manifest changes in your application's Git repository. ArgoCD will detect this and sync the older manifests.

## 3. Scaling
Scaling in Argus Infra primarily involves adding or removing virtual machines and configuring k3s to utilize them.

### Scaling VMs (Hetzner)
1.  **Modify Terraform**: Update the `count` or define new VM resources in `terraform/environments/homelab/main.tf`.
2.  **Apply Terraform**:
    ```bash
    cd terraform/environments/homelab
    terraform apply
    ```
    This will provision new VMs.

### Adding k3s Agents
1.  **Update Ansible Inventory**: Add the IP addresses of the newly provisioned VMs to `ansible/inventory/homelab.yml` under the `k3s-agent` group.
2.  **Run Ansible Playbook**:
    ```bash
    cd ansible
    ansible-playbook -i inventory/homelab.yml playbooks/site.yml
    ```
    Ansible will install k3s agents on the new VMs, joining them to the cluster.

### Scaling Applications (Kubernetes)
For applications deployed via ArgoCD, scaling is managed within Kubernetes:
1.  **Modify Kubernetes Manifests**: Update the `replicas` count in your Deployment manifests.
2.  **Commit and Push**: Push the updated manifests to your application's Git repository. ArgoCD will sync the changes, and Kubernetes will scale your application pods.

## 4. Troubleshooting

### General Troubleshooting Steps
-   **Check Logs**: Review logs of relevant components (VMs, k3s, ArgoCD, application pods).
-   **Verify Status**: Check the status of Kubernetes nodes, pods, deployments, and services.
-   **Network Connectivity**: Ensure proper network connectivity between components.

### Terraform Troubleshooting
-   **Syntax Errors**: `terraform validate` can help catch syntax issues.
-   **State Issues**: If Terraform state gets corrupted, use `terraform state rm` or `terraform import` with extreme caution. Always back up your state.
-   **Hetzner API Errors**: Verify your Hetzner API token and ensure it has the necessary permissions.

### Ansible Troubleshooting
-   **Connectivity**: Ensure Ansible can connect to target VMs (SSH access, correct credentials).
-   **Idempotency Issues**: If a playbook fails, fix the issue and re-run. Ansible is designed to be idempotent.
-   **Verbose Output**: Run playbooks with `-vvv` for more detailed debugging information.

### k3s Troubleshooting
-   **Node Status**: `kubectl get nodes` to check if all nodes are `Ready`.
-   **Pod Status**: `kubectl get pods -A` to check for pending or crashing pods.
-   **k3s Logs**: Check k3s server and agent logs on the VMs: `journalctl -u k3s` or `journalctl -u k3s-agent`.
-   **Network Issues**: Verify CNI (Container Network Interface) is working correctly.

### ArgoCD Troubleshooting
-   **ArgoCD Pods**: Check the status of ArgoCD pods in the `argocd` namespace.
-   **Application Sync Status**: In the ArgoCD UI, check the sync status and health of your applications.
-   **Resource Errors**: If an application fails to sync, check the events and logs of the problematic Kubernetes resources.
