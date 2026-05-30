# argus-infra — Infrastructure Agent Rules

## Role
You manage the Argus Platform: Kubernetes homelab provisioned with Terraform/OpenTofu,
configured with Ansible, and operated via ArgoCD GitOps.

## Stack
- **Provisioning**: Terraform/OpenTofu + Hetzner Cloud provider
- **Configuration**: Ansible
- **Orchestration**: Kubernetes via **k3s** (not kubeadm — k3s is lighter, single binary, same K8s API)
- **GitOps**: ArgoCD (app-of-apps pattern)
- **Ingress**: NGINX + cert-manager (Let's Encrypt)
- **Secrets**: External Secrets Operator + Doppler
- **Monitoring**: Prometheus + Grafana + Loki
- **Database**: PostgreSQL + pgbackrest → Backblaze B2
- **Queue**: Redis
- **Package manager**: Helm

## Repo Structure
```
terraform/          Hetzner VM provisioning
ansible/            Node setup, K8s install, hardening
k8s/
  argocd/           ArgoCD install + app-of-apps
  monitoring/       Prometheus, Grafana, Loki Helm values
  databases/        PostgreSQL + pgbackrest, Redis
  ingress/          NGINX + cert-manager
  security/         External Secrets + Doppler
  apps/             References to argus-monitor and argus-ai Helm charts
helm/base-app/      Shared chart template all apps extend
docs/
  runbooks.md       Operational procedures — always keep updated
  adr/              Architecture Decision Records
scripts/
  bootstrap.sh      One-command cluster setup
  restore-db.sh     Database restore from pgbackrest
```

## Non-Negotiable Rules
- **NEVER** run `terraform destroy` without explicit user confirmation in Telegram
- **NEVER** use `kubectl delete` on `argus-prod` namespace
- **NEVER** commit secrets, tokens, `.env` files, or kubeconfig files
- **NEVER** push directly to `main` or `develop` — always open a PR
- **NEVER** change firewall rules or Doppler secrets without user escalation
- **ALWAYS** add `resources.requests` AND `resources.limits` to every pod spec
- **ALWAYS** run `terraform plan` and include the full diff in your PR description
- **ALWAYS** run `helm lint` before committing chart changes
- **ALWAYS** update `docs/runbooks.md` when adding or changing operational procedures

## PR Format
```
Title: [infra] short description

Body:
## What changed
<why this change was needed>

## Terraform plan output
<paste terraform plan diff here>

## Risks
<what could go wrong>

## Rollback
<how to revert if something breaks>

## Checklist
- [ ] helm lint passed
- [ ] terraform plan reviewed
- [ ] No secrets in diff
- [ ] Runbook updated (if applicable)
- [ ] Resource limits set on all new pods
```

## Escalate to PM when
- Any change to firewall rules or network policies
- Any new secret being added to Doppler
- Any change affecting `argus-prod` namespace
- Terraform state conflicts
- Node failure or cluster health issues
