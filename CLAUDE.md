# argus-infra — Infrastructure Agent Rules

## Role
You manage the Argus Platform: Kubernetes homelab provisioned with Terraform/OpenTofu,
configured with Ansible, and operated via ArgoCD GitOps.

## Stack
- **Provisioning**: Terraform/OpenTofu + Hetzner Cloud provider
- **Configuration**: Ansible
- **Orchestration**: Kubernetes via **k3s** (not kubeadm — k3s is lighter, single binary, same K8s API)
- **GitOps**: ArgoCD (argocd-root app-of-apps pattern)
- **Ingress**: NGINX + cert-manager (Let's Encrypt)
- **Secrets**: External Secrets Operator + Doppler
- **Monitoring**: Prometheus + Grafana + Loki
- **Database**: PostgreSQL + pgbackrest → Backblaze B2
- **Queue**: Redis
- **Package manager**: Helm

## Repo Structure
- `terraform/`: Terraform/OpenTofu configurations for provisioning infrastructure.
- `ansible/`: Ansible playbooks and roles for configuring Kubernetes and other services.
- `kubernetes/`: Kubernetes manifests and Helm charts for deploying applications via ArgoCD.
- `docs/`: Documentation for setup, operations, and architecture.

## Non-Negotiable Rules
- **NEVER** run `terraform destroy` without explicit user confirmation in Telegram.
- **NEVER** use `kubectl delete` on `argus-prod` namespace without explicit user confirmation.
- **NEVER** commit secrets, tokens, `.env` files, or kubeconfig files.
- **NEVER** push directly to `main` or `develop` — always open a PR.
- **NEVER** change firewall rules or Doppler secrets without user escalation.
- **ALWAYS** add `resources.requests` AND `resources.limits` to every pod spec.
- **ALWAYS** run `terraform plan` and include the full diff in your PR description.
- **ALWAYS** run `helm lint` before committing chart changes.
- **ALWAYS** update `docs/setup.md` when adding or changing operational procedures.

## PR Format
Every PR you open must include:
- What changed and why (link to issue)
- How to test
- Any risks or migration steps
- Checklist: tests passing, CLAUDE.md rules followed, no secrets committed

## Escalate to PM when
- Any change to firewall rules or network policies
- Any new secret being added to Doppler
- Any change affecting `argus-prod` namespace
- Terraform state conflicts
- Node failure or cluster health issues

For detailed setup instructions, refer to `docs/setup.md`.
