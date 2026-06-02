# Argus Infra — Windows Setup

This guide walks through setting up the argus-infra toolchain on Windows.

## Prerequisites

- **Windows 10 or 11** (64-bit)
- **Administrator access** (for installing tools)
- **Git for Windows** — includes Git Bash, which is required for running shell scripts
  - Download from: https://git-scm.com/download/win
  - During install, select "Git from the command line and also from 3rd-party software"
  - Select "Use Windows' default console window" (for better compatibility)

## Step 0: Install make

The Makefile targets call shell scripts, but `make` itself is not installed by default on Windows.

**Option A (Recommended):** Run the bootstrap script as Administrator:

1. Right-click `BOOTSTRAP_WINDOWS.bat` in the repo root
2. Select **"Run as administrator"**
3. Follow the prompts — this installs Chocolatey and `make`

**Option B (Manual):** Install via Chocolatey manually:

```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install make -y
```

**Option C (WSL2):** Use Windows Subsystem for Linux 2 for full Linux compatibility:

```powershell
# Run PowerShell as Administrator
wsl --install -d Ubuntu
# Then follow the Linux setup guide inside WSL2
```

## Step 1: Install CLI tools

After installing `make`, open **Git Bash** (not Command Prompt, not PowerShell) and run:

```bash
cd /path/to/argus-infra
make install-tools
```

This installs: Terraform, Ansible, kubectl, Helm, k3d, kubeseal, and other dependencies.

> **Note:** If `make install-tools` fails on a specific tool, you can install it manually.
> See [docs/setup.md](docs/setup.md) for manual installation instructions.

## Step 2: Verify installation

```bash
make check-versions
```

All tools should show their installed versions.

## Step 3: Start local cluster

```bash
make local-up
```

This creates a local k3d Kubernetes cluster with ArgoCD and monitoring.

## Troubleshooting

### "make" is not recognized

Run `BOOTSTRAP_WINDOWS.bat` as Administrator first, or install make via Chocolatey manually.

### Shell scripts fail with syntax errors

Always use **Git Bash** (not Command Prompt or PowerShell) to run shell scripts.
Git Bash provides a Unix-like environment that the scripts expect.

### k3d fails to start

- Ensure Docker Desktop is running
- Try: `make local-down && make local-up`
- If issues persist, restart Docker Desktop

### ArgoCD login fails

- Wait 2-3 minutes for ArgoCD to fully initialize
- Run: `kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=180s`
- Then retry: `kubectl port-forward -n argocd svc/argocd-server 8080:80`

### Need help?

Open an issue at: https://github.com/fatoh2/argus-infra/issues
