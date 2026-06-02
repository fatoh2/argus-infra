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

### NetworkPolicy Deployments
NetworkPolicies are deployed via ArgoCD as part of the `security` application.
1.  **Modify Policies**: Edit manifests in `k8s/security/network-policies/`.
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new policies to the cluster.
4.  **Verify**:
    ```bash
    kubectl get networkpolicies -A
    ```

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

### NetworkPolicy Rollback
1.  **Revert Git**: Revert the NetworkPolicy manifest changes in `k8s/security/network-policies/`.
2.  **ArgoCD Sync**: ArgoCD will revert the policies. Note that removing a `default-deny-all` policy will immediately open all pod traffic in that namespace.
3.  **Emergency Workaround**: If ArgoCD sync is broken, delete policies directly:
    ```bash
    kubectl delete networkpolicy -n <namespace> default-deny-all
    ```

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

## 4. Running Sanity Checks

The repository includes a local sanity check suite to validate infrastructure code before committing.

### Local Sanity Suite
Run from the repository root:
```bash
# Basic checks (Terraform, Ansible, file structure)
./scripts/run-sanity-checks.sh

# Verbose output
./scripts/run-sanity-checks.sh --verbose

# Skip ansible-lint (if not installed)
./scripts/run-sanity-checks.sh --skip-ansible-lint
```

### Cluster-Level Checks (requires running cluster)
```bash
# Full cluster sanity (nodes, pods, ArgoCD apps, ingress)
./scripts/cluster-sanity.sh --verbose

# ArgoCD-specific health check
./scripts/argocd-health.sh --verbose
```

### CI Pipeline
- **Sanity Checks** run automatically on every PR to `develop` or `main`, and on push to those branches.
- **Cluster Sanity** runs every 6 hours via scheduled GitHub Actions workflow (requires `CLUSTER_SANITY_ENABLED` repository variable).

## 5. Troubleshooting

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
-   **Pod Status**: `kubectl get pods -A` to check if all pods are running.
-   **Logs**: `kubectl logs <pod-name> -n <namespace>` to view pod logs.
-   **Describe**: `kubectl describe pod <pod-name> -n <namespace>` for detailed pod information.

### NetworkPolicy Troubleshooting
-   **Verify Policies are Applied**:
    ```bash
    kubectl get networkpolicies -A
    ```
    Each namespace should show a `default-deny-all` policy plus any explicit allow policies.

-   **Test Connectivity**:
    ```bash
    # Deploy a temporary test pod
    kubectl run test-pod --image=busybox -n default --rm -it -- sh
    
    # Inside the pod, test connectivity
    wget -qO- http://some-service.some-namespace:port
    # If this times out, a NetworkPolicy is blocking it
    ```

-   **Check Policy Descriptions**:
    ```bash
    kubectl describe networkpolicy -n <namespace> <policy-name>
    ```

-   **CNI Support**: k3s uses Flannel by default, which does **not** enforce NetworkPolicies. If policies appear applied but traffic is not being blocked, install a CNI that supports NetworkPolicy enforcement (e.g., Calico or Cilium).

-   **ArgoCD Sync Issues**: If default-deny blocks ArgoCD from syncing applications across namespaces, you may need to add an allow policy for ArgoCD's service account or temporarily disable the default-deny on the `argocd` namespace.

-   **Pod Labels**: NetworkPolicies use pod selectors (labels). If a policy isn't working as expected, verify that the source/destination pods have the correct labels:
    ```bash
    kubectl get pods -n <namespace> --show-labels
    ```

### ArgoCD Troubleshooting
-   **Sync Status**: Check the ArgoCD UI or CLI for sync status and errors.
-   **App Health**: `argocd app list` to see all applications and their health status.
-   **Logs**: `kubectl logs -n argocd deployment/argocd-application-controller` for controller logs.
-   **NetworkPolicy Interference**: If ArgoCD apps show `OutOfSync` or `Unknown` after applying default-deny, ArgoCD may be unable to reach resources across namespaces. See NetworkPolicy troubleshooting above.
