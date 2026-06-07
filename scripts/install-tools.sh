#!/bin/bash
# Argus Infra — Tool Installer
# Installs all CLI tools required to work with the argus-infra repo.
# Targets: Ubuntu/Debian (22.04+), macOS, Windows (Git Bash / WSL2)
#
# Usage:
#   bash scripts/install-tools.sh          # interactive
#   bash scripts/install-tools.sh --quiet  # minimal output
#
# Each tool checks if already installed (skips if present).
# Errors are handled gracefully — one tool failure doesn't block others.

set -uo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
TERRAFORM_VERSION="1.7.5"  # pinned fallback — update as needed
QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

# ── OS Detection ──────────────────────────────────────────────────────────────
# Multi-signal detection for Windows, WSL2, macOS, Linux
detect_os() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "${OS:-}" == "Windows_NT" ]]; then
    echo "windows"
  elif grep -qi "microsoft" /proc/version 2>/dev/null; then
    echo "wsl2"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "linux"
  fi
}
OS_TYPE=$(detect_os)

# ── Helpers ───────────────────────────────────────────────────────────────────

info()  { echo -e "  \033[1;34m•\033[0m $*"; }
ok()    { echo -e "  \033[1;32m✓\033[0m $*"; }
warn()  { echo -e "  \033[1;33m⚠\033[0m $*"; }
fail()  { echo -e "  \033[1;31m✗\033[0m $*"; }
header(){ echo -e "\n\033[1;36m── $* ──\033[0m"; }

quiet() {
  if $QUIET; then "$@" > /dev/null 2>&1; else "$@"; fi
}

# Install a binary to /usr/local/bin with proper permissions.
# Uses sudo if available, falls back to direct install.
# Uses sudo mv (not sudo install) for macOS compatibility.
install_binary() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    if sudo mv "$src" "$dest" 2>/dev/null; then
      sudo chmod +x "$dest" 2>/dev/null
    elif mv "$src" "$dest" 2>/dev/null; then
      chmod +x "$dest"
    else
      fail "Cannot install to $dest (permission denied)"
      return 1
    fi
  else
    fail "Source file $src not found"
    return 1
  fi
}

# ── Pre-flight ────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Argus Infra — Tool Installer     ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Detected OS: ${OS_TYPE}"
echo ""

if [[ $EUID -eq 0 ]]; then
  warn "Running as root — this is fine but not required."
  echo ""
fi

# ── System dependencies ───────────────────────────────────────────────────────

if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "wsl2" ]]; then
  header "System dependencies"

  # Ensure we're on a Debian-based system
  if ! command -v apt-get &>/dev/null; then
    fail "This script requires apt-get (Debian/Ubuntu)."
    warn "On other Linux distros, install the following manually:"
    warn "  curl wget git jq unzip build-essential python3 python3-pip"
    exit 1
  fi

  # Explicit error check for apt-get update (Bug 5 fix)
  if ! quiet sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq; then
    warn "apt-get update failed — installs may fail. Try: sudo apt-get update manually"
  fi

  quiet sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl wget git jq unzip build-essential \
    software-properties-common gnupg ca-certificates \
    python3 python3-venv python3-pip \
    apt-transport-https lsb-release 2>/dev/null
  ok "System dependencies installed"
elif [[ "$OS_TYPE" == "macos" ]]; then
  header "System dependencies"
  if ! command -v brew &>/dev/null; then
    info "Homebrew not found — installing..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1; then
      ok "Homebrew installed"
    else
      fail "Homebrew install failed. Install manually: https://brew.sh"
    fi
  else
    ok "Homebrew already installed"
  fi
  info "Installing dependencies via Homebrew..."
  brew install curl wget git jq unzip python3 2>/dev/null || true
  ok "System dependencies installed"
elif [[ "$OS_TYPE" == "windows" ]]; then
  header "System dependencies"
  warn "On Windows (Git Bash), install the following manually:"
  warn "  - Git for Windows (includes Git Bash)"
  warn "  - Python 3 from https://python.org"
  warn "  - Terraform, kubectl, helm via Chocolatey or manual download"
  warn "  - Or use WSL2 for full Linux compatibility"
  echo ""
fi

# ── Terraform ─────────────────────────────────────────────────────────────────

header "Terraform ${TERRAFORM_VERSION}"

install_terraform() {
  local arch="amd64"
  local url
  if [[ "$OS_TYPE" == "macos" ]]; then
    arch="amd64"
    [[ "$(uname -m)" == "arm64" ]] && arch="arm64"
    url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_darwin_${arch}.zip"
  else
    url="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${arch}.zip"
  fi
  local tmpdir
  tmpdir=$(mktemp -d)

  if ! quiet curl -fsSL "$url" -o "$tmpdir/terraform.zip"; then
    fail "Failed to download Terraform ${TERRAFORM_VERSION}"
    rm -rf "$tmpdir"
    return 1
  fi

  if ! quiet unzip -q "$tmpdir/terraform.zip" -d "$tmpdir"; then
    fail "Failed to unzip Terraform"
    rm -rf "$tmpdir"
    return 1
  fi

  install_binary "$tmpdir/terraform" "/usr/local/bin/terraform"
  local rc=$?
  rm -rf "$tmpdir"
  return $rc
}

if command -v terraform &>/dev/null; then
  current=$(terraform --version | head -1 | grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
  if [[ "$current" == "$TERRAFORM_VERSION" ]]; then
    ok "Terraform ${TERRAFORM_VERSION} already installed"
  else
    warn "Terraform ${current} found — upgrading to ${TERRAFORM_VERSION}"
    if install_terraform; then
      ok "Terraform ${TERRAFORM_VERSION} installed"
    else
      fail "Terraform install failed"
    fi
  fi
else
  info "Installing Terraform ${TERRAFORM_VERSION}..."
  if install_terraform; then
    ok "Terraform ${TERRAFORM_VERSION} installed"
  else
    fail "Terraform install failed"
  fi
fi

# ── Ansible + collections ─────────────────────────────────────────────────────

header "Ansible"

if command -v ansible &>/dev/null; then
  ok "Ansible $(ansible --version | head -1 | grep -oP '\d+\.\d+\.\d+') already installed"
else
  if [[ "$OS_TYPE" == "linux" || "$OS_TYPE" == "wsl2" ]]; then
    info "Installing Ansible via apt..."
    if quiet sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ansible-core; then
      ok "Ansible installed"
    else
      # Fallback to pip3 if apt fails (Bug 4 fix)
      warn "apt install failed — trying pip3..."
      quiet pip3 install --user ansible-core 2>/dev/null
      # Add ~/.local/bin to PATH for this session (Bug 4 fix)
      export PATH="$HOME/.local/bin:$PATH"
      if command -v ansible &>/dev/null; then
        ok "Ansible installed (pip3, ~/.local/bin)"
      else
        fail "Ansible install failed"
      fi
    fi
  elif [[ "$OS_TYPE" == "macos" ]]; then
    info "Installing Ansible via pip3..."
    quiet pip3 install --user ansible-core 2>/dev/null
    export PATH="$HOME/.local/bin:$PATH"
    if command -v ansible &>/dev/null; then
      ok "Ansible installed (pip3)"
    else
      fail "Ansible install failed"
    fi
  else
    warn "Ansible not available on this OS — skipping"
  fi
fi

# Install required Galaxy collections
header "Ansible Galaxy collections"
if command -v ansible-galaxy &>/dev/null; then
  if [[ -f ansible/requirements.yml ]]; then
    info "Installing collections from ansible/requirements.yml..."
    if quiet ansible-galaxy collection install -r ansible/requirements.yml; then
      ok "Ansible collections installed"
    else
      fail "Failed to install Ansible collections"
    fi
  else
    warn "ansible/requirements.yml not found — skipping collection install"
  fi

  # Also install kubernetes.core collection (needed for K8s modules)
  if ! ansible-galaxy collection list kubernetes.core &>/dev/null 2>&1; then
    info "Installing kubernetes.core collection..."
    if quiet ansible-galaxy collection install kubernetes.core; then
      ok "kubernetes.core installed"
    else
      fail "kubernetes.core install failed"
    fi
  else
    ok "kubernetes.core already installed"
  fi
else
  warn "ansible-galaxy not available — skipping collection install"
fi

# ── kubectl (latest stable) ───────────────────────────────────────────────────

header "kubectl"

install_kubectl() {
  local version
  version=$(quiet curl -fsSL https://dl.k8s.io/release/stable.txt) || {
    fail "Failed to determine latest kubectl version"
    return 1
  }

  local url
  if [[ "$OS_TYPE" == "macos" ]]; then
    local arch="amd64"
    [[ "$(uname -m)" == "arm64" ]] && arch="arm64"
    url="https://dl.k8s.io/release/${version}/bin/darwin/${arch}/kubectl"
  else
    url="https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"
  fi

  if ! quiet curl -fsSL "$url" -o /tmp/kubectl; then
    fail "Failed to download kubectl"
    return 1
  fi

  install_binary "/tmp/kubectl" "/usr/local/bin/kubectl"
}

if command -v kubectl &>/dev/null; then
  ok "kubectl $(kubectl version --client 2>/dev/null | head -1 | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown') already installed"
else
  info "Installing kubectl..."
  if install_kubectl; then
    ok "kubectl installed"
  else
    fail "kubectl install failed"
  fi
fi

# ── Helm 3 ────────────────────────────────────────────────────────────────────

header "Helm 3"

install_helm() {
  local url
  if [[ "$OS_TYPE" == "macos" ]]; then
    local arch="amd64"
    [[ "$(uname -m)" == "arm64" ]] && arch="arm64"
    url="https://get.helm.sh/helm-v3.17.2-darwin-${arch}.tar.gz"
  else
    url="https://get.helm.sh/helm-v3.17.2-linux-amd64.tar.gz"
  fi

  if ! quiet curl -fsSL "$url" -o /tmp/helm.tar.gz; then
    fail "Failed to download Helm"
    return 1
  fi

  quiet tar xzf /tmp/helm.tar.gz -C /tmp/
  if [[ "$OS_TYPE" == "macos" ]]; then
    local arch="amd64"
    [[ "$(uname -m)" == "arm64" ]] && arch="arm64"
    install_binary "/tmp/darwin-${arch}/helm" "/usr/local/bin/helm"
  else
    install_binary "/tmp/linux-amd64/helm" "/usr/local/bin/helm"
  fi
  local rc=$?
  rm -rf /tmp/helm.tar.gz /tmp/linux-amd64 /tmp/darwin-amd64 /tmp/darwin-arm64 2>/dev/null || true
  return $rc
}

if command -v helm &>/dev/null; then
  ok "Helm $(helm version --short 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown') already installed"
else
  info "Installing Helm..."
  if install_helm; then
    ok "Helm installed"
  else
    fail "Helm install failed"
  fi
fi

# ── ArgoCD CLI (latest) ───────────────────────────────────────────────────────

header "ArgoCD CLI"

install_argocd() {
  local url
  if [[ "$OS_TYPE" == "macos" ]]; then
    url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64"
  else
    url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
  fi

  if ! quiet curl -fsSL "$url" -o /tmp/argocd; then
    fail "Failed to download ArgoCD CLI"
    return 1
  fi

  install_binary "/tmp/argocd" "/usr/local/bin/argocd"
}

if command -v argocd &>/dev/null; then
  ok "ArgoCD CLI $(argocd version --client --short 2>/dev/null | head -1 || echo 'unknown') already installed"
else
  info "Installing ArgoCD CLI..."
  if install_argocd; then
    ok "ArgoCD CLI installed"
  else
    fail "ArgoCD CLI install failed"
  fi
fi

# ── k3d (for local K8s cluster) ───────────────────────────────────────────────

header "k3d"

install_k3d() {
  if ! quiet curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; then
    fail "k3d install script failed"
    return 1
  fi
}

if command -v k3d &>/dev/null; then
  ok "k3d $(k3d --version 2>/dev/null | head -1 | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown') already installed"
else
  info "Installing k3d..."
  if install_k3d; then
    ok "k3d installed"
  else
    fail "k3d install failed"
  fi
fi

# ── kubeseal (for SealedSecrets) ──────────────────────────────────────────────

header "kubeseal"

install_kubeseal() {
  # Get latest version from GitHub API with fallback (Bug 3 fix)
  local version
  version=$(quiet curl -fsSL https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest \
    | grep '"tag_name":' | sed 's/.*"tag_name": "\(.*\)",.*/\1/') \
    || version="v0.27.1"  # fallback if API rate-limited

  if [[ -z "$version" ]]; then
    version="v0.27.1"  # hardcoded fallback
    warn "GitHub API rate-limited — using kubeseal ${version} as fallback"
  fi

  info "Latest kubeseal version: ${version}"

  local url
  if [[ "$OS_TYPE" == "macos" ]]; then
    local arch="amd64"
    [[ "$(uname -m)" == "arm64" ]] && arch="arm64"
    url="https://github.com/bitnami-labs/sealed-secrets/releases/download/${version}/kubeseal-${version#v}-darwin-${arch}.tar.gz"
  else
    url="https://github.com/bitnami-labs/sealed-secrets/releases/download/${version}/kubeseal-${version#v}-linux-amd64.tar.gz"
  fi

  if ! quiet curl -fsSL "$url" -o /tmp/kubeseal.tar.gz; then
    fail "Failed to download kubeseal from $url"
    return 1
  fi

  quiet tar xzf /tmp/kubeseal.tar.gz -C /tmp/
  install_binary "/tmp/kubeseal" "/usr/local/bin/kubeseal"
  local rc=$?
  rm -rf /tmp/kubeseal.tar.gz /tmp/kubeseal
  return $rc
}

if command -v kubeseal &>/dev/null; then
  ok "kubeseal $(kubeseal --version 2>/dev/null | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'unknown') already installed"
else
  info "Installing kubeseal..."
  if install_kubeseal; then
    ok "kubeseal installed"
  else
    fail "kubeseal install failed"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════╗"
echo "║         Installation Summary         ║"
echo "╚══════════════════════════════════════╝"
echo ""

all_ok=true
for tool in terraform ansible kubectl helm argocd k3d kubeseal; do
  if command -v "$tool" &>/dev/null; then
    ok "$tool — $(command -v "$tool")"
  else
    fail "$tool — NOT INSTALLED"
    all_ok=false
  fi
done

echo ""
if $all_ok; then
  ok "All tools installed successfully!"
else
  warn "Some tools failed to install. Check errors above."
fi
echo ""
echo "Run 'bash scripts/versions.sh' for detailed version info."
echo ""
