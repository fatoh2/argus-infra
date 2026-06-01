# Argus Infra Setup

This document outlines the steps to set up the Argus Infrastructure repository.

## Prerequisites

Before you begin, ensure you have the following installed:

*   Git
*   Terraform
*   Ansible
*   kubectl
*   ArgoCD CLI

You will also need:

*   A Kubernetes cluster (e.g., k3s, minikube, EKS, GKE)
*   KUBECONFIG environment variable set if your kubeconfig is not at ~/.kube/config.

## Getting Started

1.  Clone the repository:
    ```bash
    git clone https://github.com/fatoh2/argus-infra.git
    cd argus-infra
    ```

2.  Initialize Terraform:
    ```bash
    terraform init
    ```

3.  Apply Terraform configurations (e.g., to provision cloud resources):
    ```bash
    terraform apply
    ```

4.  Run Ansible playbooks (e.g., to configure Kubernetes nodes):
    ```bash
    ansible-playbook -i inventory/hosts.ini playbooks/site.yml
    ```

5.  Install ArgoCD (if not already installed):
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

6.  Access ArgoCD UI:
    ```bash
    argocd admin initial-password -n argocd
    argocd port-forward
    ```
    Then navigate to `localhost:8080` in your browser.

7.  Deploy ArgoCD Applications:
    ```bash
    kubectl apply -f k8s/argocd/apps/argocd-apps.yaml
    ```

## Development

### Running Sanity Checks

To ensure your changes are valid, run the sanity checks:

```bash
./scripts/run-sanity-checks.sh
```

### Contributing

Please follow the [CONTRIBUTING.md](CONTRIBUTING.md) guidelines.
