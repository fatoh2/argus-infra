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
