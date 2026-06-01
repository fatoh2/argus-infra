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


## Non-Negotiable Rules
- **NEVER** run 
[0m[1m[32mNo changes.[0m[1m No objects need to be destroyed.[0m

[0mEither you have not created any objects yet or the existing objects were
already deleted outside of Terraform.
[0m[1m[32m
Destroy complete! Resources: 0 destroyed.[0m without explicit user confirmation in Telegram
- **NEVER** use  on  namespace
- **NEVER** commit secrets, tokens,  files, or kubeconfig files
- **NEVER** push directly to  or  — always open a PR
- **NEVER** change firewall rules or Doppler secrets without user escalation
- **ALWAYS** add  AND  to every pod spec
- **ALWAYS** run  and include the full diff in your PR description
- **ALWAYS** run ==> Linting .
Error unable to check Chart.yaml file in chart: stat Chart.yaml: no such file or directory before committing chart changes
- **ALWAYS** update  when adding or changing operational procedures

## PR Format


## Escalate to PM when
- Any change to firewall rules or network policies
- Any new secret being added to Doppler
- Any change affecting  namespace
- Terraform state conflicts
- Node failure or cluster health issues
