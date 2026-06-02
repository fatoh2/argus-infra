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

### Grafana Deployment
Grafana is deployed via ArgoCD as a standalone application from `k8s/grafana/`.
1.  **Modify Grafana Config**: Edit manifests in `k8s/grafana/` (dashboards, datasources, deployment settings).
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new configuration to the cluster.
4.  **Verify**:
    ```bash
    kubectl get pods -n monitoring -l app=grafana
    kubectl get ingress -n monitoring grafana
    ```
5.  **Access Grafana**: Open `https://grafana.argus.local` in your browser. Default credentials: `admin`/`admin`.

### Adding a New Dashboard
1.  **Create the dashboard JSON**: Export or create a Grafana dashboard JSON.
2.  **Add to ConfigMap**: Append the dashboard JSON to the `data` section of `k8s/grafana/configmap-dashboards.yaml` under a new key (e.g., `my-dashboard.json`).
3.  **Register in provisioning**: If adding a new dashboard file, update `k8s/grafana/configmap-provisioning.yaml` to include it in the `providers` section.
4.  **Commit and Sync**: Push changes and let ArgoCD sync. Grafana will pick up the new dashboard without restart.

### NetworkPolicy Deployments
NetworkPolicies are deployed via ArgoCD as part of the `security` application.
1.  **Modify Policies**: Edit manifests in `k8s/security/network-policies/`.
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new policies to the cluster.
4.  **Verify**:
    ```bash
    kubectl get networkpolicies -A
    ```


### Pod Security Standards Deployment
Pod Security Standards are enforced via namespace labels in `k8s/security/pod-security/`.
1.  **Apply Namespace Labels**:
    ```bash
    kubectl apply -f k8s/security/pod-security/
    ```
2.  **Verify Enforcement**:
    ```bash
    kubectl describe ns monitoring
    # Look for: pod-security.kubernetes.io/enforce: restricted
    ```
3.  **Verify Workload Compliance**: After labeling, check that all pods in restricted namespaces are running:
    ```bash
    kubectl get pods -n monitoring
    kubectl get pods -n databases
    ```
    Any pod that violates the restricted profile will be rejected by the admission controller.



### RBAC ServiceAccount Deployment
RBAC resources (ServiceAccounts, ClusterRoles, ClusterRoleBindings) are deployed via ArgoCD as part of the `security` application.
1.  **Modify RBAC**: Edit manifests in `k8s/security/rbac/`.
2.  **Commit and Push**: Push changes to the `develop` branch. After review, merge to `main`.
3.  **ArgoCD Sync**: ArgoCD will automatically sync the new RBAC resources to the cluster.
4.  **Verify**:
    ```bash
    kubectl get serviceaccounts -A | grep -E 'api-service|argocd-manager|prometheus'
    kubectl auth can-i list pods --as=system:serviceaccount:monitoring:prometheus
    ```

### Workload SecurityContext Updates
When adding a new workload to a restricted namespace, ensure its `securityContext` complies:
- Pod-level: `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`
- Container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`
- Add `emptyDir` volumes for any writable paths (e.g., `/tmp`)

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

### Grafana Rollback
1.  **Revert Git**: Revert the Grafana manifest changes in `k8s/grafana/`.
2.  **ArgoCD Sync**: ArgoCD will revert Grafana to the previous state.
3.  **Emergency Workaround**: If ArgoCD sync is broken, delete the Grafana deployment directly:
    ```bash
    kubectl delete deployment grafana -n monitoring
    kubectl delete configmap grafana-dashboards grafana-datasource-config grafana-datasources -n monitoring
    ```
    ArgoCD will recreate them from the last synced state.

### NetworkPolicy Rollback
1.  **Revert Git**: Revert the NetworkPolicy manifest changes in `k8s/security/network-policies/`.
2.  **ArgoCD Sync**: ArgoCD will revert the policies. Note that removing a `default-deny-all` policy will immediately open all pod traffic in that namespace.
3.  **Emergency Workaround**: If ArgoCD sync is broken, delete policies directly:
    ```bash
    kubectl delete networkpolicy -n <namespace> default-deny-all
    ```




### RBAC ServiceAccount Rollback
1.  **Revert Git**: Revert the RBAC manifest changes in `k8s/security/rbac/`.
2.  **ArgoCD Sync**: ArgoCD will revert the RBAC resources.
3.  **Emergency Workaround**: If ArgoCD sync is broken, delete or patch resources directly:
    ```bash
    kubectl delete serviceaccount api-service -n default
    kubectl delete clusterrole argocd-manager-cluster-role
    kubectl delete clusterrolebinding argocd-manager-cluster-role-binding
    ```

### Pod Security Standards Rollback
1.  **Revert Git**: Revert the namespace label changes in `k8s/security/pod-security/`.
2.  **ArgoCD Sync**: ArgoCD will revert the namespace labels, removing the restricted profile enforcement.
3.  **Emergency Workaround**: If ArgoCD sync is broken, remove labels directly:
    ```bash
    kubectl label ns monitoring pod-security.kubernetes.io/enforce- pod-security.kubernetes.io/audit- pod-security.kubernetes.io/warn-
    ```
4.  **Revert Workload Changes**: If a workload's `securityContext` changes caused issues, revert those changes in Git and sync via ArgoCD.

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


### Pod Security Standards Troubleshooting
-   **Pods Failing to Start After Labeling**: If pods in a namespace are stuck in `Pending` or `ContainerCreating` after applying the restricted profile, check the admission controller events:
    ```bash
    kubectl describe pod <pod-name> -n <namespace>
    # Look for: "violates PodSecurity" in the Events section
    ```
    Common violations and fixes:
    | Violation | Fix |
    |-----------|-----|
    | `runAsNonRoot` is required | Add `securityContext.runAsNonRoot: true` to pod spec |
    | `readOnlyRootFilesystem` is required | Add `securityContext.readOnlyRootFilesystem: true` and mount `emptyDir` for writable paths |
    | `capabilities.drop` is required | Add `securityContext.capabilities.drop: [ALL]` |
    | `seccompProfile` is required | Add `securityContext.seccompProfile.type: RuntimeDefault` |

-   **Grafana Fails to Start**: If Grafana cannot write to its filesystem, ensure the `emptyDir` volume for `/tmp` is present in the deployment:
    ```bash
    kubectl get deployment grafana -n monitoring -o yaml | grep -A5 emptyDir
    ```

-   **Postgres Backup CronJob Fails**: The `amazon/aws-cli:latest` image may run as root. If the CronJob fails after applying the restricted profile:
    ```bash
    kubectl logs job/postgres-backup-<id> -n databases
    ```
    If the error is permission-related, switch to a non-root AWS CLI image or remove `runAsNonRoot: true` from the CronJob's securityContext.

-   **Temporarily Disable Enforcement**: To debug a namespace without the restricted profile blocking pods:
    ```bash
    kubectl label ns <namespace> pod-security.kubernetes.io/enforce- --overwrite
    # Re-enable after debugging:
    kubectl label ns <namespace> pod-security.kubernetes.io/enforce=restricted --overwrite
    ```

-   **Check Policy Version**: Verify the enforce-version is compatible with your cluster:
    ```bash
    kubectl describe ns monitoring | grep enforce-version
    ```
    If using an older Kubernetes version (< 1.25), change `latest` to a specific version like `v1.24`.

### ArgoCD Troubleshooting
-   **Sync Status**: Check the ArgoCD UI or CLI for sync status and errors.
-   **App Health**: `argocd app list` to see all applications and their health status.
-   **Logs**: `kubectl logs -n argocd deployment/argocd-application-controller` for controller logs.
-   **NetworkPolicy Interference**: If ArgoCD apps show `OutOfSync` or `Unknown` after applying default-deny, ArgoCD may be unable to reach resources across namespaces. See NetworkPolicy troubleshooting above.

### Grafana Troubleshooting
-   **Grafana Pod Not Starting**: Check pod logs for errors:
    ```bash
    kubectl logs -n monitoring deployment/grafana
    ```
    Common issues:
    - **Permission denied**: Grafana's `securityContext` may need `runAsUser: 472` (Grafana's default UID) or an `emptyDir` volume for `/var/lib/grafana`.
    - **Datasource not found**: Verify the Prometheus datasource URL in `k8s/grafana/configmap-datasources.yaml`. The service DNS must match the actual Prometheus service name.
    - **ConfigMap not mounted**: Check that the ConfigMaps referenced in the Deployment exist:
      ```bash
      kubectl get configmap -n monitoring | grep grafana
      ```

-   **Grafana Not Accessible via Ingress**:
    ```bash
    # Check ingress status
    kubectl get ingress -n monitoring grafana
    # Check Traefik is routing correctly
    kubectl get ingressroute -n monitoring
    # Verify DNS resolves grafana.argus.local to the cluster IP
    ```
    If using a local cluster without DNS, add a hosts file entry:
    ```
    <CLUSTER_IP>  grafana.argus.local
    ```

-   **Dashboards Not Showing**:
    ```bash
    # Verify dashboard ConfigMap exists and has content
    kubectl get configmap grafana-dashboards -n monitoring -o yaml | head -20
    # Check Grafana provisioning logs
    kubectl logs -n monitoring deployment/grafana | grep -i provisioning
    ```
    If dashboards are missing, ensure the provisioning ConfigMap (`grafana-datasource-config`) has the correct `dashboards` provider section pointing to the dashboard ConfigMap.

-   **Default Credentials Not Working**: If `admin`/`admin` doesn't work, the password may have been changed. Reset by exec-ing into the pod:
    ```bash
    kubectl exec -n monitoring deployment/grafana -- grafana-cli admin reset-admin-password newpassword
    ```

-   **Grafana Shows "No data" in Panels**:
    ```bash
    # Verify Prometheus is reachable from Grafana
    kubectl exec -n monitoring deployment/grafana -- wget -qO- http://prometheus-kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/query?query=up
    # Check Prometheus targets are up
    kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-stack-prometheus 9090:9090
    # Then visit http://localhost:9090/targets
    ```

---

## 6. CI/CD Pipeline

### CI: Pull Request Validation
Every PR to `develop` runs sanity checks automatically via GitHub Actions (`.github/workflows/sanity-checks.yml`).

**What's checked:**
- Terraform validate + format
- Terraform plan (dry-run)
- Ansible syntax + lint
- ShellCheck (shell script static analysis)
- Critical files existence check

**If CI fails:**
1. Click "Details" on the failing check in the PR
2. Fix the issue in your branch
3. Push again — CI re-runs automatically

### CD: Continuous Deployment (Three-Stage Pipeline)
Every merge to `main` triggers the CD workflow (`.github/workflows/cd-deploy.yml`), which runs three sequential stages:

**Stage 1 — Lint:** Terraform format check, Ansible lint, ShellCheck
**Stage 2 — Build:** Terraform validate + plan (dry-run), Ansible syntax check, critical files check
**Stage 3 — Deploy:** ArgoCD sync notification + optional API sync

**What happens:**
1. Lint stage runs code quality checks
2. Build stage validates infrastructure config compiles end-to-end
3. Deploy stage notifies ArgoCD of the change
4. ArgoCD detects the change (via webhook or polling) and syncs the cluster

**Monitoring a deployment:**
```bash
# Check ArgoCD app status
argocd app list

# Check sync status of root app
argocd app get argocd-root

# Watch sync in real-time
argocd app sync argocd-root --watch
```

**If ArgoCD sync fails:**
1. Check the ArgoCD UI for error details
2. Fix the manifest in a new branch
3. Open a PR, merge to `develop`, then merge to `main`
4. ArgoCD will re-sync automatically

See `docs/cicd.md` for full pipeline documentation.
