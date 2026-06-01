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
    

2.  Initialize Terraform:
    [0m[1mTerraform initialized in an empty directory![0m

The directory has no Terraform configuration files. You may begin working
with Terraform immediately by creating Terraform configuration files.[0m

3.  Apply Terraform configurations (e.g., to provision cloud resources):
    

4.  Prepare Ansible inventory:
    

5.  Run Ansible playbooks (e.g., to configure Kubernetes nodes):
    

6.  Install ArgoCD (if not already installed):
    

7.  Access ArgoCD UI:
    
    Then navigate to  in your browser.

8.  Deploy ArgoCD Applications:
    
    *Note: The ArgoCD applications are configured with , which means namespaces like  and  will be automatically created.*

## Development

### Running Sanity Checks

To ensure your changes are valid, run the sanity checks:



### Contributing

Please follow the [CONTRIBUTING.md](CONTRIBUTING.md) guidelines.
