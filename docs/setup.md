# ArgoCD Setup Guide

This document outlines the steps to set up ArgoCD on the Kubernetes cluster using k3s.

## Prerequisites

- A running Kubernetes cluster (e.g., provisioned by Terraform and Ansible).
- `kubectl` installed and configured to control your Kubernetes cluster. Refer to the official [kubectl documentation](https://kubernetes.io/docs/reference/kubectl/) for installation and configuration instructions.

## Steps

1.  **Provision VMs and Install k3s**

    If you haven't already, provision your virtual machines using Terraform and install k3s using Ansible.
    Refer to the `terraform` and `ansible` directories for detailed instructions.

    **Example: Terraform Initialization**
    ```bash
    terraform init
    ```
    ```
    Initializing the backend...

    Initializing provider plugins...
    - Reusing previous version of hashicorp/libvirt from the dependency lock file
    - Installing hashicorp/libvirt v0.7.1...
    - Installed hashicorp/libvirt v0.7.1 (signed by HashiCorp)

    Terraform has been successfully initialized!

    You may now begin working with Terraform. Try running "terraform plan" to see
    any changes that are required for your infrastructure. All Terraform commands
    should now work.

    If you ever change our working directory or update providers, rerun
    "terraform init" to update your backend configuration.
    ```

    **Example: Ansible Playbook Execution**
    ```bash
    ansible-playbook -i inventory/homelab.ini playbooks/k3s.yml
    ```
    ```
    PLAY [all] *********************************************************************

    TASK [Gathering Facts] *********************************************************
    ok: [k3s-master-1]
    ok: [k3s-worker-1]

    TASK [k3s : Install k3s] *******************************************************
    changed: [k3s-master-1]
    changed: [k3s-worker-1]

    PLAY RECAP *********************************************************************
    k3s-master-1               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
    k3s-worker-1               : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
    ```

2.  **Install ArgoCD**

    Run the bootstrap script to install ArgoCD into your cluster:

    ```bash
    ./scripts/bootstrap-argocd.sh
    ```

    This script will:
    - Create the `argocd` namespace.
    - Install ArgoCD using its official manifest.
    - Wait for ArgoCD pods to be ready.

3.  **Access ArgoCD UI**

    To access the ArgoCD UI, you can port-forward the ArgoCD server service:

    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

    Then, open your browser to `https://localhost:8080`.

4.  **Login to ArgoCD**

    The initial password for the `admin` user is stored in a Kubernetes secret. Retrieve it using:

    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    ```

    Use `admin` as the username and the retrieved password to log in.

5.  **Configure ArgoCD with Git Repository**

    Once logged in, you can add your Git repository to ArgoCD. This allows ArgoCD to synchronize applications defined in your repository with your Kubernetes cluster.

    - Navigate to "Settings" -> "Repositories".
    - Click "Connect Repo".
    - Enter your repository URL (e.g., `https://github.com/fatoh2/argus-infra.git`).
    - Provide appropriate authentication details (e.g., SSH private key or HTTPS credentials).

6.  **Deploy Applications with ArgoCD**

    Define your applications in YAML files within your Git repository. For example, you might have a `k8s/applications/guestbook.yaml` file:

    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: guestbook
      namespace: argocd
    spec:
      destination:
        namespace: default
        server: https://kubernetes.default.svc
      project: default
      source:
        path: k8s/guestbook
        repoURL: https://github.com/fatoh2/argus-infra.git
        targetRevision: HEAD
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    ```

    After committing this file to your repository, create the application in ArgoCD:

    ```bash
    kubectl apply -f k8s/applications/guestbook.yaml
    ```

    ArgoCD will detect the application and begin synchronizing it to your cluster. You can monitor its status in the ArgoCD UI.
