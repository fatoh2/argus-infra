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
    Example: `export KUBECONFIG=/path/to/your/kubeconfig`

## Getting Started

1.  Clone the repository:
    ```bash
    git clone git@github.com:fatoh2/argus-infra.git
    cd argus-infra
    ```

2.  Initialize Terraform:
    ```bash
    cd terraform/environments/homelab
    terraform init
    cd ../../.. # Go back to root
    ```

3.  Apply Terraform configurations (e.g., to provision cloud resources):
    ```bash
    cd terraform/environments/homelab
    terraform apply # You may be prompted to confirm with 'yes'. For non-interactive runs, consider using '-auto-approve'.
    cd ../../.. # Go back to root
    ```

4.  Prepare Ansible inventory:
    ```bash
    cp ansible/inventory/homelab.yml.example ansible/inventory/homelab.yml
    # Edit ansible/inventory/homelab.yml with your host details
    ```

5.  Run Ansible playbooks (e.g., to configure Kubernetes nodes):
    ```bash
    ansible-galaxy install -r ansible/requirements.yml
    ansible-playbook -i ansible/inventory/homelab.yml ansible/playbooks/site.yml
    ```

6.  Install ArgoCD (if not already installed):
    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```

7.  Access ArgoCD UI:
    ```bash
    argocd admin initial-password -n argocd
    # Default username is 'admin'.
    # Port forward the ArgoCD server:
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```
    Then navigate to `https://localhost:8080` in your browser.

8.  Deploy ArgoCD Applications:
    ```bash
    kubectl apply -f k8s/argocd/app-of-apps.yaml
    # Note: The ArgoCD applications are configured with `selfHeal: true`, which means namespaces like `databases` and `ingress` will be automatically created.
    ```

## Development

### Running Sanity Checks

To ensure your changes are valid, run the sanity checks. These are defined in the GitHub Actions workflow `.github/workflows/sanity-checks.yml`.

```bash
# For local testing, you can manually run the commands listed within the workflow file or use a tool like `act`.
# Example using act (requires Docker):
# act -j sanity-checks --container-architecture linux/amd64
```
*Note: This is a GitHub Actions workflow. You would typically push your changes and let GitHub Actions run it. For local testing, you can use `act` or manually run the commands within the workflow file.*

### Contributing

Please follow the [CONTRIBUTING.md](CONTRIBUTING.md) guidelines.
