# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- `kubectl` configured to control your Kubernetes cluster.

## Steps

1.  **Provision VMs and Install k3s**

    If you haven't already, provision your virtual machines using Terraform and install k3s using Ansible.
    Refer to the `terraform/` and `ansible/` directories for detailed instructions.

    Example (from the `terraform/` directory):
    ```bash
    terraform init
    terraform apply
    ```

    Example (from the `ansible/` directory, after updating `inventory/homelab.yml`):
    ```bash
    ansible-playbook -i inventory/homelab.yml playbooks/k3s-cluster.yml
    ```

2.  **Bootstrap ArgoCD**

    Run the bootstrap script to install ArgoCD and set up the root app-of-apps.
    This will apply the necessary manifests to your Kubernetes cluster.

    ```bash
    ./scripts/bootstrap-argocd.sh
    ```

3.  **Retrieve ArgoCD Admin Password**

    The initial admin password for ArgoCD is stored in a Kubernetes secret. Retrieve it using the following command:

    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

4.  **Access ArgoCD UI**

    Port-forward the ArgoCD UI service to your local machine to access it via your browser.

    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```
    Then navigate to `https://localhost:8080` in your browser. The default username is `admin`.

## Next Steps

- Add child application manifests to the `argocd/apps/` directory for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the `develop` branch of the `argus-infra` repository. ArgoCD will automatically sync them.
- For example, to add the `prometheus` application, you would create a file like `argocd/apps/prometheus.yaml` and commit it.
