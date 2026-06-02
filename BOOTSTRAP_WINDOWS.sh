#!/bin/bash
# Bootstrap script for Argus Infra on Windows
# Run this in Git Bash or WSL2 to set up your environment

set -e

echo "╔════════════════════════════════════════════════════════════════════════╗"
echo "║         Argus Infra — Windows Bootstrap                               ║"
echo "╚════════════════════════════════════════════════════════════════════════╝"
echo ""

# Detect environment
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    ENV="Git Bash"
elif grep -qi "microsoft" /proc/version 2>/dev/null; then
    ENV="WSL2"
else
    ENV="Unknown"
fi

echo "Environment: $ENV"
echo ""

# Essential tools check
echo "═══════════════════════════════════════════════════════════════════════"
echo "Checking essential tools..."
echo "═══════════════════════════════════════════════════════════════════════"
echo ""

MISSING=()

# Check docker
if command -v docker &>/dev/null; then
    echo "✓ Docker: $(docker --version | cut -d ' ' -f 3)"
else
    echo "✗ Docker: NOT FOUND"
    MISSING+=("Docker")
fi

# Check kubectl
if command -v kubectl &>/dev/null; then
    echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null | grep -o 'v[0-9.]*' || echo 'installed')"
else
    echo "✗ kubectl: NOT FOUND"
    MISSING+=("kubectl")
fi

# Check k3d
if command -v k3d &>/dev/null; then
    echo "✓ k3d: installed"
else
    echo "✗ k3d: NOT FOUND"
    MISSING+=("k3d")
fi

# Check helm
if command -v helm &>/dev/null; then
    echo "✓ Helm: $(helm version --short 2>/dev/null | grep -o 'v[0-9.]*' || echo 'installed')"
else
    echo "✗ Helm: NOT FOUND"
    MISSING+=("helm")
fi

echo ""

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "═══════════════════════════════════════════════════════════════════════"
    echo "Missing essential tools:"
    echo "═══════════════════════════════════════════════════════════════════════"
    echo ""

    for tool in "${MISSING[@]}"; do
        case $tool in
            Docker)
                echo "• Docker Desktop"
                echo "  Download: https://www.docker.com/products/docker-desktop"
                echo "  ⚠️  IMPORTANT: Enable WSL2 backend during installation"
                ;;
            kubectl)
                echo "• kubectl (Kubernetes CLI)"
                echo "  Option A: Included with Docker Desktop"
                echo "  Option B: choco install kubernetes-cli"
                echo "  Option C: https://kubernetes.io/docs/tasks/tools/"
                ;;
            k3d)
                echo "• k3d (Lightweight Kubernetes)"
                echo "  Option A: choco install k3d"
                echo "  Option B: https://k3d.io/v5.0.0/#releases"
                ;;
            helm)
                echo "• Helm (Kubernetes Package Manager)"
                echo "  Option A: choco install kubernetes-helm"
                echo "  Option B: https://helm.sh/docs/intro/install/"
                ;;
        esac
        echo ""
    done

    echo "After installing missing tools, run this script again."
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════════════"
echo "✅ All essential tools are installed!"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo ""
echo "1. Verify Docker Desktop is running:"
echo "   docker ps"
echo ""
echo "2. Create local k3d cluster:"
echo "   make local-up"
echo ""
echo "3. Access ArgoCD UI (in another terminal):"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   Open: https://localhost:8080"
echo ""
echo "4. Teardown when done:"
echo "   make local-down"
echo ""
