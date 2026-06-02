# Argus Infra — Setup on Windows

## Overview

Running Argus Infra on Windows requires Docker Desktop with WSL2, and several CLI tools. This guide provides Windows-specific setup instructions.

## Prerequisites

### Option A: Docker Desktop (Recommended)

1. **Install Docker Desktop for Windows**
   - Download: https://www.docker.com/products/docker-desktop
   - During installation, enable **WSL2 backend**
   - This includes: Docker, kubectl, docker-compose
   - **Best option** for local k3d cluster development

### Option B: WSL2 + Native Tools

1. **Install WSL2**
   ```powershell
   wsl --install
   # Then restart and launch Ubuntu from Windows Terminal
   ```

2. Run the install script inside WSL2:
   ```bash
   cd /mnt/c/Workstation/argus-infra
   bash scripts/install-tools.sh
   ```

### Option C: Chocolatey (All-in-one)

Install [Chocolatey](https://chocolatey.org/install), then:

```powershell
choco install terraform kubernetes-cli kubernetes-helm k3d git
```

## Quick Start on Windows

### Step 1: Verify Prerequisites

```powershell
# Check what's installed
make check-versions
```

You should see:
- ✓ docker
- ✓ k3d
- ✓ kubectl
- ✓ helm

### Step 2: Create Local k3d Cluster

```powershell
# Spin up cluster with monitoring
make local-up
```

This creates:
- k3d cluster named `argus-local`
- ArgoCD (GitOps)
- Prometheus + Grafana (metrics)
- Loki (logs)

### Step 3: Access Services

**ArgoCD UI:**
```powershell
kubectl port-forward -n argocd svc/argocd-server 8080:443
```
Then open: https://localhost:8080

Default credentials:
- Username: `admin`
- Password: Get from secret:
  ```powershell
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  ```

**Grafana (Monitoring):**
```powershell
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```
Then open: http://localhost:3000
- Username: `admin`
- Password: `prom-operator`

### Step 4: Teardown

```powershell
make local-down
```

## Tool Installation Details

### Docker Desktop (Recommended)

1. Download from https://www.docker.com/products/docker-desktop
2. Run installer (docker-desktop-installer.exe)
3. **Important**: During setup, check "Use WSL 2 based engine"
4. Restart Windows
5. Open PowerShell and verify:
   ```powershell
   docker --version
   kubectl version --client
   ```

### Terraform

**Chocolatey:**
```powershell
choco install terraform
```

**Manual:**
1. Download: https://releases.hashicorp.com/terraform/
2. Extract to: `C:\Program Files\Terraform`
3. Add to PATH (System Environment Variables)

### kubectl

Included with Docker Desktop. If not:
```powershell
choco install kubernetes-cli
```

### Helm

**Chocolatey:**
```powershell
choco install kubernetes-helm
```

**Manual:**
1. Download: https://github.com/helm/helm/releases
2. Extract to: `C:\Program Files\Helm`
3. Add to PATH

### k3d

**Chocolatey:**
```powershell
choco install k3d
```

**Manual:**
```powershell
choco install k3d --pre
```

### Ansible

⚠️ **Note:** Ansible on Windows is limited. For best results:
- Use WSL2 (recommended)
- Or use Docker container:
  ```powershell
  docker run -v C:\Workstation\argus-infra:/workspace -w /workspace ansible/ansible:latest ansible-playbook -i inventory playbooks/site.yml
  ```

## Troubleshooting

### "docker: command not found"
- Ensure Docker Desktop is **running** (check system tray)
- Add Docker to PATH: Settings → System → Environment Variables
- Restart PowerShell

### "k3d: command not found"
```powershell
choco install k3d
# Or install manually from: https://k3d.io/
```

### "kubectl: command not found"
Docker Desktop includes kubectl. If missing:
```powershell
choco install kubernetes-cli
```

### WSL2 Issues
```powershell
# Update WSL
wsl --update

# Check WSL version
wsl --list --verbose

# Switch to WSL2
wsl --set-default-version 2
```

### Port Conflicts (8080, 3000, 443)
If ports are in use:
```powershell
# Find what's using port 8080
netstat -ano | findstr :8080

# Kill process (replace PID)
taskkill /PID <PID> /F
```

Or use different ports:
```powershell
kubectl port-forward -n argocd svc/argocd-server 8888:443
# Open https://localhost:8888
```

## Environment Variables

Optional, but useful:

**PowerShell Profile** (`$PROFILE`)
```powershell
# Add to C:\Users\<YourUser>\Documents\PowerShell\profile.ps1

# Kubernetes
$env:KUBECONFIG = "~/.kube/config"

# Disable Ansible warnings on Windows
$env:ANSIBLE_COMMAND_WARNINGS = $false
```

## Next Steps

- Review infrastructure docs: `docs/setup.md`
- Check architecture: `docs/architecture.md`
- See Terraform examples: `terraform/environments/homelab`
- Run validation: `make sanity`

## Windows-Specific Notes

- **Path style**: Use `/` in bash scripts (even on Windows), use `\` in PowerShell
- **Line endings**: Git will convert CRLF ↔ LF automatically
- **Symlinks**: k3d handles these internally; no admin elevation needed
- **Firewall**: k3d may prompt to allow Docker access
- **WSL2 memory**: By default uses ~50% of RAM; configure in `%UserProfile%\.wslconfig`:
  ```ini
  [wsl2]
  memory=8GB
  processors=4
  ```

## Support

For issues:
1. Check Docker Desktop is running
2. Restart Docker Desktop if needed
3. Verify WSL2 is installed: `wsl --list --verbose`
4. Review Docker logs: Docker Desktop → Settings → Troubleshoot → Logs
5. Run `make check-versions` to verify all tools

