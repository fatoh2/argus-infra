#!/bin/bash
# Spin up local k3d cluster with ArgoCD, Prometheus, Loki for testing
# Note: Requires Docker and k3d. On Windows, run inside WSL2 or use Docker Desktop.

set -e

CLUSTER_NAME="argus-local"
# Use latest k3s version (don't pin to specific version to avoid image not found errors)
K3S_VERSION="latest"

log() { echo "→ $1"; }
ok() { echo "✓ $1"; }
warn() { echo "⚠️  $1"; }
err() { echo "✗ $1"; }

# Check prerequisites
if ! command -v k3d &>/dev/null; then
    echo "✗ k3d is not installed"
    echo "  Run: make install-tools"
    exit 1
fi

if ! command -v kubectl &>/dev/null; then
    warn "kubectl is not installed — some features may not work"
fi

if ! command -v helm &>/dev/null; then
    warn "helm is not installed — cluster monitoring will not be installed"
fi

if ! command -v docker &>/dev/null; then
    echo "✗ Docker is not installed or not running"
    echo "  Install Docker Desktop or Docker Engine and ensure it's running"
    exit 1
fi

log "Creating k3d cluster: $CLUSTER_NAME..."
echo "  (This may take 2-3 minutes)"

# Create cluster with proper port mappings and registry
# Use --image with latest tag to avoid "not found" errors
k3d cluster create "$CLUSTER_NAME" \
  --servers=1 \
  --agents=2 \
  --port 80:80@loadbalancer \
  --port 443:443@loadbalancer \
  --wait \
  --timeout=300s \
  --registry-create=argus-local \
  2>&1 | tee /tmp/k3d-create.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    err "Failed to create cluster"
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Ensure Docker Desktop is running"
    echo "  2. Check available disk space (need ~5GB)"
    echo "  3. Check Docker logs: docker logs"
    echo "  4. Try deleting the cluster: k3d cluster delete $CLUSTER_NAME"
    echo "  5. Try again: make local-up"
    echo ""
    echo "Last 20 lines of k3d output:"
    tail -20 /tmp/k3d-create.log
    exit 1
fi

ok "k3d cluster created"

# Get kubeconfig
log "Setting up kubeconfig..."
k3d kubeconfig get "$CLUSTER_NAME" > ~/.kube/config-"$CLUSTER_NAME"
export KUBECONFIG=~/.kube/config-"$CLUSTER_NAME"
ok "Kubeconfig ready at ~/.kube/config-$CLUSTER_NAME"

# Wait for cluster ready
log "Waiting for cluster to be ready..."
kubectl rollout status deployment/coredns -n kube-system --timeout=300s

ok "Cluster is ready"

# Install ArgoCD via Helm
log "Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update >/dev/null 2>&1 || true

# ArgoCD v2.8+ requires password to be bcrypt-hashed — plain text does not work
# Generate bcrypt hash of "admin" using python3 (available on Ubuntu/macOS by default)
ARGOCD_ADMIN_PASS="admin"
ARGOCD_ADMIN_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'${ARGOCD_ADMIN_PASS}', bcrypt.gensalt(10)).decode())" 2>/dev/null)
if [ -z "$ARGOCD_ADMIN_HASH" ]; then
    # bcrypt not available — install it then retry
    pip3 install bcrypt --quiet 2>/dev/null || true
    ARGOCD_ADMIN_HASH=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'${ARGOCD_ADMIN_PASS}', bcrypt.gensalt(10)).decode())" 2>/dev/null)
fi
if [ -z "$ARGOCD_ADMIN_HASH" ]; then
    # Last resort: use a pre-computed bcrypt hash for "admin" (cost 10)
    ARGOCD_ADMIN_HASH='$2a$10$rRyBsGAAe/EFnxQcpGIHOe2.e6FFdS7I4j9k.bGG5MaJLrBQNb3hy'
fi

# Write Helm values to a temp file (avoids heredoc issues in different shells)
cat > /tmp/argocd-values.yaml <<YAML
configs:
  secret:
    argocdServerAdminPassword: "${ARGOCD_ADMIN_HASH}"
    argocdServerAdminPasswordMtime: "$(date +%FT%T%Z)"
server:
  insecure: true
YAML

if helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values /tmp/argocd-values.yaml \
  >/dev/null 2>&1; then
    log "Waiting for ArgoCD to be ready (this may take a minute)..."
    kubectl wait -n argocd --for=condition=available --timeout=300s deployment/argocd-server >/dev/null 2>&1 || true
    rm -f /tmp/argocd-values.yaml
    ok "ArgoCD installed (admin / ${ARGOCD_ADMIN_PASS})"
else
    rm -f /tmp/argocd-values.yaml
    warn "ArgoCD installation failed (Helm install issue - this is optional)"
fi

# Install Prometheus (optional - cluster works without it)
if command -v helm &>/dev/null; then
    log "Installing Prometheus..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update 2>/dev/null || true

    # Write to temp file — avoids heredoc-to-stdin issues in Git Bash / non-bash shells
    cat > /tmp/prometheus-values.yaml <<'YAML'
prometheus:
  prometheusSpec:
    retention: 24h
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
grafana:
  adminPassword: admin
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 50m
      memory: 256Mi
YAML

    if helm install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --values /tmp/prometheus-values.yaml \
      >/dev/null 2>&1; then
        ok "Prometheus installed"
    else
        warn "Prometheus installation skipped (optional)"
    fi
    rm -f /tmp/prometheus-values.yaml

    # Install Loki (optional)
    log "Installing Loki..."
    helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
    helm repo update 2>/dev/null || true

    cat > /tmp/loki-values.yaml <<'YAML'
loki:
  persistence:
    enabled: false
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
promtail:
  enabled: true
YAML

    if helm install loki grafana/loki-stack \
      --namespace logging \
      --create-namespace \
      --values /tmp/loki-values.yaml \
      >/dev/null 2>&1; then
        ok "Loki installed"
    else
        warn "Loki installation skipped (optional)"
    fi
    rm -f /tmp/loki-values.yaml
else
    warn "Helm not found - skipping Prometheus and Loki installation"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "✅ Local cluster '$CLUSTER_NAME' is ready!"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""
echo "📋 Set kubeconfig:"
echo "  export KUBECONFIG=~/.kube/config-$CLUSTER_NAME"
echo ""
echo "🔍 Check cluster status:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "🔐 Access ArgoCD (in another terminal):"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  open https://localhost:8080  # macOS"
echo "  start https://localhost:8080 # Windows"
echo "  User: admin | Password: admin"
echo ""
echo "📊 Grafana/Prometheus (if installed):"
echo "  kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  open http://localhost:3000"
echo "  User: admin | Password: admin"
echo ""
echo "🧹 Tear down when done:"
echo "  make local-down"
echo ""
echo "═══════════════════════════════════════════════════════════════════════"
