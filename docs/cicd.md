# CI/CD Pipeline

Argus Infra uses a two-tier CI/CD approach:

1. **CI (Continuous Integration)** — runs on every PR to `develop`
2. **CD (Continuous Deployment)** — runs on every merge to `main`

## CI: Pull Request Validation

**File:** `.github/workflows/sanity-checks.yml`

Triggered on every PR opened against `develop`. Runs:

| Step | What it checks |
|------|----------------|
| Terraform Validate | `terraform validate` on the homelab environment |
| Terraform Format | `terraform fmt -check` ensures consistent formatting |
| Terraform Plan | Dry-run plan (targeting network module only) to catch config errors |
| Ansible Syntax | `ansible-playbook --syntax-check` validates playbook structure |
| Ansible Lint | `ansible-lint` enforces best practices across all playbooks and roles |

**Required to pass** before a PR can be merged to `develop`.

## CD: Continuous Deployment

**File:** `.github/workflows/cd-deploy.yml`

Triggered on every push to `main`. Runs:

| Step | What it does |
|------|--------------|
| Validate | Same sanity checks as CI (belt-and-suspenders) |
| ArgoCD Sync | Notifies that a merge occurred; optionally triggers ArgoCD sync via API |

### How ArgoCD GitOps Works

ArgoCD is configured to watch the `main` branch of this repository. When a PR merges to `main`:

1. GitHub Actions runs the CD workflow (validation + optional API sync)
2. ArgoCD detects the change in Git (either via webhook or its 3-minute polling interval)
3. ArgoCD syncs the cluster state to match the manifests in `main`
4. ArgoCD reports sync status (Synced/OutOfSync/Error) in the ArgoCD UI

### ArgoCD Webhook (Recommended)

For faster syncs, configure a GitHub webhook in this repository:

1. In ArgoCD, go to **Settings > Repositories > Connect Repo using HTTPS**
2. Under **Webhook**, copy the webhook URL and secret
3. In GitHub, go to **Settings > Webhooks > Add webhook**
4. Paste the ArgoCD webhook URL and secret
5. Set content type to `application/json`
6. Select **Let me select individual events** and check **Pull requests** and **Pushes**

Once configured, ArgoCD syncs within seconds of a merge instead of waiting for the polling interval.

### ArgoCD API Sync (Alternative)

If a webhook is not configured, the CD workflow can optionally trigger an ArgoCD sync via the REST API:

1. Set a repository variable `ARGOCD_SERVER` (e.g., `argocd.argus.local`)
2. Set a repository secret `ARGOCD_TOKEN` (an ArgoCD API token)
3. On merge, the workflow calls the ArgoCD sync API on the `argocd-root` application

This is optional — ArgoCD will auto-sync within its default 3-minute polling interval even without it.

## Pipeline Diagram

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Developer   │     │  GitHub PR   │     │  ArgoCD     │
│  pushes to   │────▶│  to develop  │────▶│  watches    │
│  feature/    │     │              │     │  develop    │
│  branch      │     │  CI: sanity  │     │  (preview)  │
└─────────────┘     │  checks      │     └─────────────┘
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐     ┌─────────────┐
                    │  PR merged   │     │  ArgoCD     │
                    │  to main     │────▶│  syncs to   │
                    │              │     │  cluster    │
                    │  CD: validate│     │             │
                    │  + sync      │     │  production │
                    └──────────────┘     └─────────────┘
```

## Adding a New Service

To add a new service to the GitOps pipeline:

1. Create Kubernetes manifests in `k8s/<service>/`
2. Add an ArgoCD Application manifest in `k8s/argocd/apps/`
3. Open a PR to `develop` — CI validates
4. Merge to `main` — CD deploys via ArgoCD

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| CI fails on Terraform validate | Invalid HCL syntax | Run `terraform validate` locally |
| CI fails on Ansible lint | Ansible best practice violation | Run `ansible-lint` locally and fix warnings |
| ArgoCD shows OutOfSync | Cluster state drifted from Git | Click "Sync" in ArgoCD UI or run `argocd app sync argocd-root` |
| ArgoCD shows Error | Invalid manifest or missing resource | Check ArgoCD UI logs, fix manifest, push fix to `main` |
| CD workflow skips ArgoCD sync | No webhook or API token configured | This is normal — ArgoCD will auto-sync within polling interval |
