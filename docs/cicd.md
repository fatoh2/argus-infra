# CI/CD Pipeline

Argus Infra uses a three-stage CI/CD pipeline:

1. **Lint** — code quality checks (terraform fmt, ansible-lint, shellcheck, critical file checks)
2. **Build** — infrastructure compilation checks (terraform validate + plan, guarded to skip gracefully when directories or secrets are absent)
3. **Deploy** — ArgoCD GitOps sync (path-filtered; docs-only pushes are skipped automatically)

## CI: Pull Request Validation

**File:** `.github/workflows/sanity-checks.yml`

Triggered on every PR opened against `develop` and every push to `develop`/`main`. Runs:

| Step | What it checks |
|------|----------------|
| Terraform Validate | `terraform validate` on the homelab environment |
| Terraform Format | `terraform fmt -check` ensures consistent formatting |
| Terraform Plan | Dry-run plan (targeting network module only) to catch config errors |
| Ansible Syntax | `ansible-playbook --syntax-check` validates playbook structure |
| Ansible Lint | `ansible-lint` enforces best practices across all playbooks and roles |
| ShellCheck | Static analysis for shell scripts in `scripts/` |
| Critical Files | Ensures all required files exist (manifests, configs, docs) |

**Required to pass** before a PR can be merged to `develop`.

## CD: Continuous Deployment

**File:** `.github/workflows/cd-deploy.yml`

Triggered on every push to `main` — but only when the push touches infrastructure-relevant paths:

- `terraform/**`
- `ansible/**`
- `k8s/**`
- `scripts/**`
- `.github/workflows/cd-deploy.yml`

Docs-only changes (e.g., `README.md`, `docs/*.md`) **do not** trigger the CD workflow.

Runs three sequential stages:

### Stage 1: Lint

| Step | What it does | Graceful skip |
|------|--------------|---------------|
| Check Critical Files | Ensures all required files exist (`main.tf`, `site.yml`, `install.yaml`, `cluster-sanity.sh`, `CLAUDE.md`, `README.md`) | Fails if any critical file is missing |
| Terraform Format | `terraform fmt -check -recursive` ensures consistent formatting | Skips if `terraform/environments/homelab` directory doesn't exist |
| Ansible Lint | `ansible-lint` enforces best practices | Skips if no Ansible playbooks or roles exist |
| ShellCheck | Static analysis for shell scripts in `scripts/` | Always runs if `scripts/` exists |

### Stage 2: Build (Validate + Plan)

| Step | What it does | Graceful skip |
|------|--------------|---------------|
| Terraform Validate | `terraform validate` confirms HCL syntax is correct | Skips if `terraform/environments/homelab` directory doesn't exist |
| Terraform Plan | Dry-run plan to verify configuration compiles end-to-end | Skips if `terraform/environments/homelab` doesn't exist; also skips gracefully if `HCLOUD_TOKEN` secret is not configured (prints a message and exits 0) |

> **Note:** The Terraform plan step no longer requires `HCLOUD_TOKEN` to be set. If the token is absent, it prints a warning and exits successfully. This allows the workflow to pass even when cloud credentials aren't configured yet (e.g., during initial repo setup).

### Stage 3: Deploy

| Step | What it does | Graceful skip |
|------|--------------|---------------|
| Deploy | Placeholder step that prints deployment instructions | Skips gracefully until `KUBECONFIG`, `ARGOCD_SERVER`, and `ARGOCD_TOKEN` are configured |

> **Note:** The deploy stage is currently a placeholder. Once cluster secrets are configured, this stage will trigger ArgoCD sync automatically. Until then, it prints instructions and exits successfully.

### How ArgoCD GitOps Works

ArgoCD is configured to watch the `main` branch of this repository. When a PR merges to `main`:

1. GitHub Actions runs the CD workflow (lint → build → deploy) — only if the push touches infrastructure paths
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
                    ┌──────────────────────────────────────────┐
                    │  PR merged to main                       │
                    │                                          │
                    │  CD Pipeline (path-filtered):            │
                    │   1. Lint (fmt, ansible-lint, sh, crit)  │
                    │   2. Build (validate, plan — guarded)    │
                    │   3. Deploy (placeholder until secrets)  │
                    │                                          │
                    │  Docs-only pushes are skipped entirely   │
                    └──────────────────┬───────────────────────┘
                                       │
                                       ▼
                               ┌─────────────┐
                               │  ArgoCD     │
                               │  syncs to   │
                               │  cluster    │
                               │             │
                               │  production │
                               └─────────────┘
```

## Adding a New Service

To add a new service to the GitOps pipeline:

1. Create Kubernetes manifests in `k8s/<service>/`
2. Add an ArgoCD Application manifest in `k8s/argocd/apps/`
3. Open a PR to `develop` — CI validates
4. Merge to `main` — CD deploys via ArgoCD

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|------|
| CI fails on Terraform validate | Invalid HCL syntax | Run `terraform validate` locally |
| CI fails on Terraform format | Inconsistent formatting | Run `terraform fmt -recursive` locally |
| CI fails on Ansible lint | Ansible best practice violation | Run `ansible-lint` locally and fix warnings |
| CI fails on ShellCheck | Shell script issue | Run `shellcheck scripts/*.sh` locally |
| CD fails on Terraform plan | Config compiles but plan fails | Check terraform plan output in CI logs |
| CD workflow doesn't run on push | Push was docs-only | Check if changed files match path filter (`terraform/**`, `ansible/**`, `k8s/**`, `scripts/**`, `.github/workflows/cd-deploy.yml`) |
| CD workflow passes but nothing deploys | Cluster secrets not configured | Set `KUBECONFIG`, `ARGOCD_SERVER`, and `ARGOCD_TOKEN` as repository secrets |
| ArgoCD shows OutOfSync | Cluster state drifted from Git | Click "Sync" in ArgoCD UI or run `argocd app sync argocd-root` |
| ArgoCD shows Error | Invalid manifest or missing resource | Check ArgoCD UI for detailed error message |
