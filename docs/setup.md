# Argus Infrastructure Setup Guide

This document outlines the process for setting up the Argus infrastructure, including VM provisioning, Ansible configuration, ArgoCD bootstrapping, and application deployment.

## 1. VM Provisioning (Terraform/OpenTofu)

Refer to the `terraform/` directory for provisioning virtual machines on Hetzner Cloud.

## 2. Ansible Configuration

Refer to the `ansible/` directory for configuring nodes, installing k3s, and hardening the system.

## 3. ArgoCD Bootstrapping

Use the `scripts/bootstrap-argocd.sh` script to install ArgoCD and deploy the initial "app-of-apps" manifest.

**Important Considerations for ArgoCD:**

*   **Security Configuration:** ArgoCD's security settings, including RBAC and authentication methods, are configured via `k8s/argocd/config/argocd-rbac-cm.yaml` and `k8s/argocd/config/argocd-cm.yaml`. Ensure these are reviewed and configured appropriately for your environment, including disabling anonymous access and securing the initial admin password retrieval.
*   **Git Repository Validation:** Implement pre-commit hooks or CI checks to validate the structure and content of ArgoCD application manifests in the Git repository before merging. This helps prevent sync errors due to malformed configurations.
*   **Race Conditions with Self-Healing:** Be aware that `syncPolicy.automated.selfHeal: true` and `prune: true` can lead to race conditions if manual changes are made directly to the cluster and the Git repository is updated simultaneously. Clearly define operational procedures for when direct cluster modifications are allowed and how they should be reconciled with GitOps. Educate users on the implications of these settings.

## 4. Application Deployment

ArgoCD will manage the deployment of applications defined in `k8s/argocd/apps/`.

**Best Practices for Kubernetes Manifests:**

*   **Modularity:** Break down large Kubernetes manifests into smaller, modular files. This improves readability, maintainability, and can prevent performance issues with ArgoCD sync times. Consider using Helm charts or Kustomize overlays for managing complexity.

## 5. Secrets Management

Secrets are managed using External Secrets Operator and Doppler. Ensure all secret management configurations are thoroughly reviewed for proper encryption, access control, and rotation policies. Avoid exposing secrets in plain text.

## 6. Ingress and TLS

NGINX is used for ingress, with `cert-manager` handling TLS certificates from Let's Encrypt. Ensure TLS is correctly configured and certificates are properly rotated to prevent security vulnerabilities. This includes configuring `cert-manager` issuers and certificate resources, and ensuring TLS secrets are correctly referenced by ingress resources.

### Security Considerations

*   **ArgoCD RBAC:** The default  provides a broad admin role. For production environments, it is crucial to implement stricter RBAC policies and leverage ArgoCD Projects to restrict application deployments to specific namespaces and control user permissions.
*   **Secrets Management:** This setup integrates with External Secrets Operator and Doppler. Ensure that all secret management configurations are thoroughly reviewed for proper encryption, access control, and rotation policies. Never commit sensitive information directly to Git.
*   **TLS Configuration:** For production, ensure that Ingress controllers (e.g., NGINX) are configured with TLS using  for automatic certificate provisioning and renewal. Verify that certificates are correctly managed and rotated to prevent man-in-the-middle attacks.

### Operational Best Practices

*   **Git Repository Validation:** Implement pre-commit hooks or CI checks to validate the structure and content of ArgoCD application manifests in the Git repository. This helps prevent malformed configurations from reaching the cluster.
*   **Self-Healing and Pruning:** Be aware that  and  can lead to race conditions if manual changes are made directly to the cluster. Clearly define operational procedures for when direct cluster modifications are allowed and how they should be reconciled with GitOps.
*   **Modular Manifests:** Break down large Kubernetes manifests into smaller, modular files. This improves readability, maintainability, and can prevent performance issues with ArgoCD sync operations.

### Security Considerations

*   **ArgoCD RBAC:** The default `argocd-rbac-cm.yaml` provides a broad admin role. For production environments, it is crucial to implement stricter RBAC policies and leverage ArgoCD Projects to restrict application deployments to specific namespaces and control user permissions.
*   **Secrets Management:** This setup integrates with External Secrets Operator and Doppler. Ensure that all secret management configurations are thoroughly reviewed for proper encryption, access control, and rotation policies. Never commit sensitive information directly to Git.
*   **TLS Configuration:** For production, ensure that Ingress controllers (e.g., NGINX) are configured with TLS using `cert-manager` for automatic certificate provisioning and renewal. Verify that certificates are correctly managed and rotated to prevent man-in-the-middle attacks.

### Operational Best Practices

*   **Git Repository Validation:** Implement pre-commit hooks or CI checks to validate the structure and content of ArgoCD application manifests in the Git repository. This helps prevent malformed configurations from reaching the cluster.
*   **Self-Healing and Pruning:** Be aware that `syncPolicy.automated.selfHeal: true` and `prune: true` can lead to race conditions if manual changes are made directly to the cluster. Clearly define operational procedures for when direct cluster modifications are allowed and how they should be reconciled with GitOps.
*   **Modular Manifests:** Break down large Kubernetes manifests into smaller, modular files. This improves readability, maintainability, and can prevent performance issues with ArgoCD sync operations.
