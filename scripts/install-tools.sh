#!/bin/bash
# Install required CLI tools for Argus Infra
# Requires: bash 4+
# Note: Some tools have limitations on Windows (Ansible, kubeseal)

# Don't exit on first error - we want to try all tools
set +e

TOOLS_INSTALLED=0
TOOLS_SKIPPED=0
TOOLS_FAILED=0
IS_WINDOWS=false

# Detect Windows
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
fi

log() { echo "→ $1"; }
ok() { echo "✓ $1"; TOOLS_INSTALLED=$((TOOLS_INSTALLED+1)); }
skip() { echo "⊘ $1 (skipped)"; TOOLS_SKIPPED=$((TOOLS_SKIPPED+1)); }
fail() { echo "✗ $1"; TOOLS_FAILED=$((TOOLS_FAILED+1)); }

# Ensure build-essential and curl are installed first
log "Installing Argus Infra CLI tools..."
echo ""

# Install dependencies first
log "Checking for dependencies..."
if command -v apt-get &>/dev/null; then
    # Check if we need to install essentials
    if ! command -v unzip &>/dev/null || ! command -v wget &>/dev/null || ! command -v curl &>/dev/null; then
        log "Installing build tools (unzip, wget, curl)..."
        sudo apt-get update >/dev/null 2>&1 || true
        sudo apt-get install -y unzip wget curl >/dev/null 2>&1 || true
    fi
fi
echo ""

# Terraform
if ! command -v terraform &>/dev/null; then
    log "Installing Terraform..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install terraform 2>/dev/null && ok "Terraform" || fail "Terraform"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Get latest version
        TERRAFORM_VERSION=$(curl -s https://api.github.com/repos/hashicorp/terraform/releases/latest 2>/dev/null | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
        if [ -z "$TERRAFORM_VERSION" ]; then
            fail "Terraform (could not determine version)"
        else
            TERRAFORM_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
            # Try to download and install
            if wget -q "$TERRAFORM_URL" -O /tmp/terraform.zip 2>/dev/null; then
                if command -v unzip &>/dev/null; then
                    sudo unzip -o /tmp/terraform.zip -d /usr/local/bin/ >/dev/null 2>&1 && rm /tmp/terraform.zip && ok "Terraform" || fail "Terraform"
                else
                    fail "Terraform (unzip not available; try: sudo apt-get install unzip)"
                fi
            else
                fail "Terraform (download failed)"
            fi
        fi
    elif [ "$IS_WINDOWS" = true ]; then
        skip "Terraform (use chocolatey: choco install terraform)"
    fi
else
    ok "Terraform ($(terraform version -json 2>/dev/null | grep terraform_version | cut -d '"' -f 4 || echo 'installed'))"
fi

# kubectl
if ! command -v kubectl &>/dev/null; then
    log "Installing kubectl..."
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        curl -sL https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname -s | tr '[:upper:]' '[:lower:]')/amd64/kubectl -o /tmp/kubectl
        sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl && ok "kubectl" || fail "kubectl"
    elif [ "$IS_WINDOWS" = true ]; then
        skip "kubectl (use chocolatey: choco install kubernetes-cli)"
    fi
else
    ok "kubectl (installed)"
fi

# Helm
if ! command -v helm &>/dev/null; then
    log "Installing Helm..."
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 2>/dev/null | bash 2>/dev/null && ok "Helm" || fail "Helm"
    elif [ "$IS_WINDOWS" = true ]; then
        skip "Helm (use chocolatey: choco install kubernetes-helm)"
    fi
else
    ok "Helm (installed)"
fi

# k3d
if ! command -v k3d &>/dev/null; then
    log "Installing k3d..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh 2>/dev/null | bash 2>/dev/null && ok "k3d" || fail "k3d"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install k3d 2>/dev/null && ok "k3d" || fail "k3d"
    elif [ "$IS_WINDOWS" = true ]; then
        skip "k3d (use chocolatey: choco install k3d)"
    fi
else
    ok "k3d (installed)"
fi

# Ansible
if [ "$IS_WINDOWS" = true ]; then
    if command -v ansible &>/dev/null 2>&1; then
        ok "Ansible (installed, Windows support limited)"
    else
        skip "Ansible (Windows support is limited; use WSL2 or Linux VM)"
    fi
else
    # Try to use ansible if available, even if it has issues
    if command -v ansible &>/dev/null 2>&1; then
        ok "Ansible (installed)"
    else
        log "Installing Ansible..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ansible 2>/dev/null && ok "Ansible" || fail "Ansible"
        elif command -v pip3 &>/dev/null; then
            # Use pip3 - more reliable than apt on WSL
            pip3 install --user ansible ansible-lint 2>/dev/null && ok "Ansible" || fail "Ansible"
        elif command -v apt-get &>/dev/null; then
            # Fall back to apt
            sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y ansible >/dev/null 2>&1 && ok "Ansible" || fail "Ansible"
        else
            fail "Ansible (no package manager found)"
        fi
    fi
fi

# ArgoCD CLI
if ! command -v argocd &>/dev/null; then
    if [ "$IS_WINDOWS" = true ]; then
        skip "ArgoCD CLI (use chocolatey: choco install argocd-cli)"
    else
        log "Installing ArgoCD CLI..."
        ARGOCD_URL="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64"
        curl -sSL -o /tmp/argocd "$ARGOCD_URL" 2>/dev/null && \
        sudo install -m 555 /tmp/argocd /usr/local/bin/argocd && rm /tmp/argocd && ok "ArgoCD CLI" || fail "ArgoCD CLI"
    fi
else
    ok "ArgoCD CLI (installed)"
fi

# kubeseal - issues on Windows, skip with instructions
if [ "$IS_WINDOWS" = true ]; then
    if command -v kubeseal &>/dev/null; then
        ok "kubeseal (installed)"
    else
        skip "kubeseal (Windows installation complex; use Docker or Linux VM)"
    fi
else
    if ! command -v kubeseal &>/dev/null; then
        log "Installing kubeseal..."
        KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest 2>/dev/null | grep tag_name | cut -d '"' -f 4)
        if [ -z "$KUBESEAL_VERSION" ]; then
            fail "kubeseal (cannot determine latest version)"
        else
            KUBESEAL_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/${KUBESEAL_VERSION}/kubeseal-$(uname -s | tr '[:upper:]' '[:lower:]')-amd64.tar.gz"
            # Download to temp file first
            if wget -q "$KUBESEAL_URL" -O /tmp/kubeseal.tar.gz 2>/dev/null; then
                if tar xzf /tmp/kubeseal.tar.gz -C /tmp/ 2>/dev/null && [ -f /tmp/kubeseal ]; then
                    sudo install -o root -g root -m 0755 /tmp/kubeseal /usr/local/bin/kubeseal >/dev/null 2>&1 && \
                    rm -f /tmp/kubeseal /tmp/kubeseal.tar.gz && ok "kubeseal" || fail "kubeseal (install failed)"
                else
                    fail "kubeseal (tar extraction failed)"
                fi
            else
                fail "kubeseal (download failed)"
            fi
        fi
    else
        ok "kubeseal (installed)"
    fi
fi

# shellcheck
if ! command -v shellcheck &>/dev/null; then
    if [ "$IS_WINDOWS" = true ]; then
        skip "shellcheck (use chocolatey: choco install shellcheck)"
    else
        log "Installing shellcheck..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install shellcheck 2>/dev/null && ok "shellcheck" || fail "shellcheck"
        elif command -v apt-get &>/dev/null; then
            sudo apt-get update >/dev/null && sudo apt-get install -y shellcheck >/dev/null 2>&1 && ok "shellcheck" || fail "shellcheck"
        else
            fail "shellcheck (unsupported package manager)"
        fi
    fi
else
    ok "shellcheck (installed)"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "Summary: $TOOLS_INSTALLED installed, $TOOLS_SKIPPED skipped, $TOOLS_FAILED failed"

# List essential tools for local k3d development
ESSENTIAL_TOOLS=("kubectl" "helm" "k3d" "docker")
ESSENTIAL_MISSING=0

for tool in "${ESSENTIAL_TOOLS[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
        ESSENTIAL_MISSING=$((ESSENTIAL_MISSING+1))
    fi
done

if [ "$IS_WINDOWS" = true ]; then
    echo ""
    echo "⚠️  Windows detected — some tools require alternative installation:"
    echo ""
    echo "  For best experience on Windows, use one of these approaches:"
    echo ""
    echo "  1. Chocolatey package manager (recommended for Windows):"
    echo "     choco install terraform kubernetes-cli kubernetes-helm k3d"
    echo ""
    echo "  2. WSL2 (Windows Subsystem for Linux):"
    echo "     wsl --install"
    echo "     Then run this script again inside WSL2"
    echo ""
    echo "  3. Docker Desktop with WSL2 backend:"
    echo "     • Includes kubectl, helm, docker-compose"
    echo "     • Run k3d clusters inside WSL2"
    echo ""
fi

if [ $ESSENTIAL_MISSING -gt 0 ]; then
    echo ""
    echo "⚠️  Missing essential tools for local k3d development:"
    for tool in "${ESSENTIAL_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            echo "  • $tool"
        fi
    done
    exit 1
fi

if [ $TOOLS_FAILED -gt 3 ]; then
    # Allow up to 3 failures (optional tools like kubeseal, argocd, terraform)
    echo ""
    echo "⚠️  Some tools failed to install. You can still use the cluster with essential tools."
    echo ""
fi

echo "✅ Installation complete! Essential tools ready for k3d clusters."
exit 0
