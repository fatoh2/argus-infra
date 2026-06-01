# ArgoCD GitOps Bootstrap

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using a GitOps app-of-apps pattern.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- kubectl controls the Kubernetes cluster manager.

 Find more information at: https://kubernetes.io/docs/reference/kubectl/

  api-resources   Print the supported API resources on the server
  api-versions    Print the supported API versions on the server, in the form of "group/version"
  config          Modify kubeconfig files
  kuberc          Manage kuberc configuration files
  plugin          Provides utilities for interacting with plugins
  version         Print the client and server version information

Usage:
  kubectl [flags] [options]

Use "kubectl <command> --help" for more information about a given command.
Use "kubectl options" for a list of global command-line options (applies to all commands). configured to connect to your cluster.
-  environment variable set if your kubeconfig is not at .

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
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```


    


## Next Steps

- Add child application manifests to `argocd/apps` for your specific workloads (e.g., monitoring, databases, ingress, security).
- Commit these changes to the `develop` branch of the `argus-infra` repository. ArgoCD will automatically sync them.
