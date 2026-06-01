# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl access to the Kubernetes cluster.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/

Ensure the `KUBECONFIG` environment variable is set if your kubeconfig file is not at the default location (`~/.kube/config`).

## Steps

1.  **Provision VMs and Install k3s (if not already done)**

    Refer to the `terraform` directory for VM provisioning (e.g., `cd terraform/hetzner Refer to the `terraform` directory for VM provisioning (e.g., `cd terraform/hetzner && terraform apply`) and the `ansible` directory for k3s installation (e.g., `cd ansible/k3s && ansible-playbook site.yaml`).Refer to the `terraform` directory for VM provisioning (e.g., `cd terraform/hetzner && terraform apply`) and the `ansible` directory for k3s installation (e.g., `cd ansible/k3s && ansible-playbook site.yaml`). terraform apply` to create VMs) and the `ansible` directory for k3s installation (e.g., `cd ansible/k3s Refer to the `terraform` directory for VM provisioning (e.g., `cd terraform/hetzner && terraform apply`) and the `ansible` directory for k3s installation (e.g., `cd ansible/k3s && ansible-playbook site.yaml`).Refer to the `terraform` directory for VM provisioning (e.g., `cd terraform/hetzner && terraform apply`) and the `ansible` directory for k3s installation (e.g., `cd ansible/k3s && ansible-playbook site.yaml`). ansible-playbook site.yaml` to install k3s on the provisioned VMs).

2.  **Bootstrap ArgoCD**

    Apply the following commands to install ArgoCD and set up the root app-of-apps.

    Applying ArgoCD install manifests...
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f k8s/argocd/install.yaml
    ```
    Wait for ArgoCD pods to be ready:
    ```bash
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s
    ```
    Apply the root app-of-apps manifest:
    ```bash
    kubectl apply -n argocd -f k8s/argocd/app-of-apps.yaml
    ```

3.  **Retrieve ArgoCD Admin Password**

    After the bootstrap script completes, it will print the command to retrieve the initial admin password. Run it:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

4.  **Access ArgoCD UI**

    Port-forward the ArgoCD server to access the UI:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443 # Access via HTTPS on port 8080
    ```

## Next Steps

- Review and customize the existing child application manifests in `k8s/argocd/apps` and add any additional ones for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the `develop` branch of the `argus-infra` repository. ArgoCD will automatically sync them.
