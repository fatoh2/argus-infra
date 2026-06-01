# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl controls the Kubernetes cluster manager.



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

    
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

    

4.  **Access ArgoCD UI**

    
    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443\n\nThen navigate to https://localhost:8080 in your browser. The username is `admin`.
    ```


    


## Next Steps

- Add child application manifests to `argocd/apps` for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the `develop` branch of the `argus-infra` repository. ArgoCD will automatically sync them.\n- For example, to add the `argus-monitor` application, you would create a file like `argocd/apps/argus-monitor.yaml` and commit it.
