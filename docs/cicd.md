# CI/CD Pipeline

Argus Infra uses a three-stage CI/CD pipeline:

1. **Lint** — runs on every PR and merge to `main`
2. **Build** — runs on every PR and merge to `main`
3. **Deploy** — runs on every merge to `main` (triggers ArgoCD sync)
3. **Deploy** — runs on every merge to `main` (triggers ArgoCD sync)

## Stage 1: Lint
## Stage 2: Build

**File:** `.github/workflows/cd-deploy.yml`

Triggered on every PR and merge to `main`. Runs:

| Step | What it checks |
|------|----------------|
| Terraform Validate | `terraform validate` on the homelab environment |
| Terraform Plan | `terraform plan` dry-run to catch config errors |
| Ansible Syntax | `ansible-playbook --syntax-check` validates playbook structure |
| Critical Files | Checks for existence of essential project files |

**Required to pass** before a PR can be merged to `develop` or before deployment to `main`.

## Stage 2: Build

**File:** `.github/workflows/cd-deploy.yml`

Triggered on every PR and merge to `main`. Runs:

| Step | What it checks |
|------|----------------|
| Terraform Plan | `terraform plan` dry-run to catch config errors |
| Critical Files | Checks for existence of essential project files |

**Required to pass** before a PR can be merged to `develop` or before deployment to `main`.


**File:** `.github/workflows/sanity-checks.yml`

Triggered on every PR and merge to `main`. Runs:

| Step | What it checks |
|------|----------------|
| Terraform Format | `terraform fmt -check -recursive` ensures consistent formatting |
| ShellCheck | `shellcheck` validates shell script syntax |
| Terraform Format | `terraform fmt -check -recursive` ensures consistent formatting |
| Ansible Lint | `ansible-lint` enforces best practices across all playbooks and roles |
| ShellCheck | `shellcheck` validates shell script syntax |

**Required to pass** before a PR can be merged to `develop`.

## Stage 3: Deploy

**File:** `.github/workflows/cd-deploy.yml`

Triggered on every push to `main` after the Build stage passes. Runs:

| Step | What it does |
|------|--------------|
| ArgoCD Sync | Triggers ArgoCD to sync the cluster state to match `main` |

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
│  branch      │     │  Lint  │     │  (preview)  │
└─────────────┘     │  checks      │     └─────────────┘
                    └──────┬───────┘
                           │
                           ▼
                    ┌──────────────┐     ┌─────────────┐
                    │  PR merged   │     │  ArgoCD     │
                    │  to main     │────▶│  syncs to   │
                    │              │     │  cluster    │
                    │  Build│     │             │
                    │  + Deploy    │     │  production │
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
