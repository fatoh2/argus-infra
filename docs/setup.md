# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl access to the Kubernetes cluster.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/

If your kubeconfig is not at the default location, ensure the KUBECONFIG environment variable is set.

## Steps

1.  **Provision VMs and Install k3s (if not already done)**

    Refer to the `terraform` and `ansible` directories for instructions on provisioning VMs and installing k3s.

2.  **Bootstrap ArgoCD**

    Run the bootstrap script to install ArgoCD and set up the root app-of-apps.

    Applying ArgoCD install manifests...
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

3.  **Retrieve ArgoCD Admin Password**

    After the bootstrap script completes, it will print the command to retrieve the initial admin password. Run it:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

    

4.  **Access ArgoCD UI**

    Port-forward the ArgoCD server to access the UI:
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:80 # Assuming HTTP on port 80. Adjust if using HTTPS on 443.
    ```


    


## Next Steps

- Review and customize the existing child application manifests in `k8s/argocd/apps` and add any additional ones for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the `develop` branch of the `argus-infra` repository. ArgoCD will automatically sync them.
