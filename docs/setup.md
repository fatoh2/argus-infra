# Argus Infrastructure Setup Guide

This guide outlines the steps to provision the Argus infrastructure.

## 1. Provision VMs

(Details on VM provisioning with Terraform/Hetzner Cloud will go here.)

## 2. Run Ansible Playbooks

(Details on Ansible playbooks for k3s installation and basic cluster setup will go here.)

## 3. Bootstrap ArgoCD

Once the Kubernetes cluster is up and running, bootstrap ArgoCD using the provided script:

```bash
./scripts/bootstrap-argocd.sh
```

This script will:
1. Install ArgoCD into the `argocd` namespace.
2. Wait for the ArgoCD server to become available.
3. Apply the `app-of-apps.yaml` manifest, which configures ArgoCD to manage applications defined in `k8s/argocd/apps/`.
4. Print the command to retrieve the initial admin password for ArgoCD.

## 4. Access ArgoCD UI

(Details on how to access the ArgoCD UI, e.g., port-forwarding or Ingress setup, will go here.)

## 5. Deploy Applications

After ArgoCD is bootstrapped, it will automatically sync applications defined in `k8s/argocd/apps/` from the Git repository.

