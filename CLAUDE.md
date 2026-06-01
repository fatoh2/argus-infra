# Argus Infra - CLAUDE.md

This document outlines the architectural principles, repository structure, and non-negotiable rules for the `argus-infra` repository.

## Architectural Principles

- **Infrastructure as Code (IaC):** All infrastructure is defined and managed through code (Terraform, Ansible).
- **GitOps:** Kubernetes cluster state is managed declaratively through Git (ArgoCD).
- **Observability:** Comprehensive monitoring and logging are built-in (Prometheus, Grafana, Loki).
- **Security First:** Secure defaults and practices are enforced.
- **Modularity:** Components are designed to be independent and reusable.

## Repo Structure

- `terraform/`: Terraform configurations for provisioning infrastructure (e.g., Hetzner VMs).
- `ansible/`: Ansible playbooks and roles for configuring VMs and installing k3s.
- `kubernetes/`: Git submodule for `argus-infra-kubernetes` containing ArgoCD applications, Kubernetes manifests, and Helm charts. This directory now houses the content previously found in `argocd/` and `monitoring/` within the submodule.
- `docs/`: Project documentation, including setup guides and architectural decisions.

## Non-Negotiable Rules

- **ALWAYS use Terraform for infrastructure provisioning.** No manual changes to cloud resources.
- **ALWAYS use Ansible for VM configuration and k3s installation.**
- **ALWAYS use ArgoCD for deploying applications to Kubernetes.** Direct `kubectl apply` is forbidden for production deployments.
- **ALWAYS update `docs/setup.md`** when operational procedures or setup instructions change.
- **NEVER commit secrets to Git.** Use a secrets management solution (e.g., SOPS, Vault).
- **ALL changes must go through a Pull Request (PR) review process.**
- **Tests must pass before merging to `develop`.**
- **Follow conventional commit messages.**
