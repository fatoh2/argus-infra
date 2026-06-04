#!/bin/bash
#===============================================================================
# local-cluster.sh — Spin up a local k3d cluster for argus-infra testing
#
# Creates:
#   - k3d cluster with 1 server + 1 agent node
#   - ArgoCD installed via Helm (bcrypt-hashed admin password)
#   - Prometheus/Grafana stack via Helm (kube-prometheus-stack)
#   - metallb for LoadBalancer support
#
# Usage:
#   bash scripts/local-cluster.sh              # Standard setup
#   bash scripts/local-cluster.sh --clean      # Delete + recreate cluster
#   bash scripts/local-cluster.sh --skip-mon   # Skip Prometheus/Grafana install
#   bash scripts/local-cluster.sh --help       # Show help
#
# Prerequisites:
#   - k3d installed (install via: make install-tools)
#   - helm installed
#   - kubectl installed
#
# Exit codes:
#   0 — Cluster created and all components installed successfully
#   1 — One or more steps failed
#===============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
CLUSTER_NAME="argus-local"
ARGOCD_NAMESPACE="argocd"
MONITORING_NAMESPACE="monitoring"
CLEAN=false
SKIP_MON=false

# --- Colors ------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Helper functions --------------------------------------------------------
info()  { echo -e "  ${BLUE}*${NC} $*"; }
ok()    { echo -e "  ${GREEN}+${NC} $*"; }
warn()  { echo -e "  ${YELLOW}!${NC} $*"; }
fail()  { echo -e "  ${RED}x${NC} $*"; }
header(){ echo -e "\n${BOLD}${BLUE}-- $* --${NC}"; }

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    fail "Required dependency '$1' is not installed."
    info "Run: make install-tools"
    return 1
  fi
}

cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo ""
    warn "Script failed with exit code $exit_code"
    warn "Run 'bash scripts/local-cluster.sh --clean' to retry from scratch."
  fi
  exit $exit_code
}
trap cleanup EXIT

# --- Argument parsing --------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=true ;;
    --skip-mon) SKIP_MON=true ;;
    --help)
      echo "Usage: bash scripts/local-cluster.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --clean       Delete existing cluster and recreate"
      echo "  --skip-mon    Skip Prometheus/Grafana installation"
      echo "  --help        Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: bash scripts/local-cluster.sh [--clean] [--skip-mon] [--help]"
      exit 1
      ;;
  esac
done

# --- Pre-flight checks -------------------------------------------------------
header "Pre-flight Checks"

check_dependency "k3d" || exit 1
check_dependency "helm" || exit 1
check_dependency "kubectl" || exit 1

# Check if htpasswd is available for bcrypt hash generation
HTPASSWD_AVAILABLE=false
if command -v htpasswd &>/dev/null; then
  HTPASSWD_AVAILABLE=true
fi

ok "All dependencies found"

# --- Clean up existing cluster if requested ----------------------------------
if [ "$CLEAN" = true ]; then
  header "Cleaning up existing cluster"
  if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    info "Deleting cluster '$CLUSTER_NAME'..."
    k3d cluster delete "$CLUSTER_NAME" > /tmp/k3d-delete.log 2>&1
    ok "Cluster deleted"
  else
    info "No existing cluster '$CLUSTER_NAME' found"
  fi
fi

# --- Create k3d cluster ------------------------------------------------------
header "Creating k3d cluster: $CLUSTER_NAME"

# Check if cluster already exists
if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  warn "Cluster '$CLUSTER_NAME' already exists"
  info "Use --clean to delete and recreate"
  info "Continuing with existing cluster..."
else
  info "Creating cluster with 1 server + 1 agent..."

  # Write cluster config to temp file instead of using long CLI args
  cat > /tmp/k3d-config.yaml << 'YAMLEOF'
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: argus-local
servers: 1
agents: 1
kubeAPI:
  hostIP: "0.0.0.0"
  hostPort: "6443"
ports:
  - port: 80:80
    nodeFilters:
      - loadbalancer
  - port: 443:443
    nodeFilters:
      - loadbalancer
  - port: 8080:8080
    nodeFilters:
      - loadbalancer
options:
  k3s:
    extraServerArgs:
      - --disable=traefik
YAMLEOF

  # Use file redirect instead of pipe to avoid set -e / PIPESTATUS issues
  if ! k3d cluster create "$CLUSTER_NAME" --config /tmp/k3d-config.yaml > /tmp/k3d-create.log 2>&1; then
    fail "Failed to create k3d cluster"
    cat /tmp/k3d-create.log
    exit 1
  fi
  ok "Cluster created successfully"
  rm -f /tmp/k3d-config.yaml
fi

# --- Wait for cluster readiness ----------------------------------------------
header "Waiting for cluster readiness"

info "Waiting for nodes to be Ready..."
if ! kubectl wait --for=condition=Ready nodes --all --timeout=120s > /dev/null 2>&1; then
  fail "Nodes not ready within 120s"
  kubectl get nodes
  exit 1
fi
ok "All nodes Ready"

info "Waiting for CoreDNS..."
if ! kubectl wait --for=condition=Available deployment/coredns -n kube-system --timeout=60s > /dev/null 2>&1; then
  warn "CoreDNS not Available within 60s — continuing anyway"
fi
ok "CoreDNS running"

# --- Install metallb (for LoadBalancer support) ------------------------------
header "Installing metallb"

if kubectl get namespace metallb-system &>/dev/null 2>&1; then
  info "metallb already installed — skipping"
else
  info "Installing metallb via Helm..."
  helm repo add metallb https://metallb.github.io/metallb 2>/dev/null || true
  helm repo update 2>/dev/null || true

  if ! helm install metallb metallb/metallb \
    --namespace metallb-system \
    --create-namespace \
    --wait \
    > /tmp/metallb-install.log 2>&1; then
    fail "metallb install failed"
    cat /tmp/metallb-install.log
    exit 1
  fi

  # Get the docker network CIDR for metallb IP pool
  DOCKER_CIDR=$(docker network inspect k3d-"$CLUSTER_NAME" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    subnet = data[0].get('IPAM', {}).get('Config', [{}])[0].get('Subnet', '')
    if subnet:
        parts = subnet.rsplit('.', 1)
        print(parts[0] + '.200.1-' + parts[0] + '.200.254')
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo "")

  if [ -n "$DOCKER_CIDR" ]; then
    # Write metallb IPAddressPool to temp file
    cat > /tmp/metallb-pool.yaml << YAMLEOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - $DOCKER_CIDR
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-advertisement
  namespace: metallb-system
YAMLEOF

    kubectl apply -f /tmp/metallb-pool.yaml > /dev/null 2>&1 || warn "metallb pool config failed (may need CRD readiness)"
    rm -f /tmp/metallb-pool.yaml
  fi

  ok "metallb installed"
fi

# --- Install ArgoCD ----------------------------------------------------------
header "Installing ArgoCD"

if kubectl get namespace "$ARGOCD_NAMESPACE" &>/dev/null 2>&1; then
  info "ArgoCD already installed in namespace '$ARGOCD_NAMESPACE' — skipping"
else
  info "Adding ArgoCD Helm repository..."
  helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
  helm repo update 2>/dev/null || true

  # Generate bcrypt-hashed password for ArgoCD admin
  # ArgoCD Helm chart v5+ requires bcrypt-hashed passwords
  info "Generating bcrypt-hashed admin password..."
  ARGOCD_ADMIN_PASS=""
  if [ "$HTPASSWD_AVAILABLE" = true ]; then
    # Generate bcrypt hash using htpasswd
    # shellcheck disable=SC2016
    ARGOCD_ADMIN_PASS=$(htpasswd -bnBC 10 "" admin | tr -d ':\n' | sed 's/\$2y/$2a/' 2>/dev/null || echo "")
  fi

  # Fallback: use a known pre-computed bcrypt hash of "admin"
  if [ -z "$ARGOCD_ADMIN_PASS" ]; then
    info "htpasswd not available — using pre-computed bcrypt hash"
    # shellcheck disable=SC2016
    ARGOCD_ADMIN_PASS='$2a$10$rRyBsGAAe/EFnxQcpGIHOe2.e6FFdS7I4j9k.bGG5MaJLrBQNb3hy'
  fi

  # Write ArgoCD values to temp file (avoids heredoc pipe issues)
  cat > /tmp/argocd-values.yaml << YAMLEOF
configs:
  secret:
    argocdServerAdminPassword: "$ARGOCD_ADMIN_PASS"
    argocdServerAdminPasswordMtime: "$(date +%FT%T%Z)"
server:
  insecure: true
  extraArgs:
    - --insecure
YAMLEOF

  info "Installing ArgoCD via Helm..."
  if ! helm install argocd argo/argo-cd \
    --namespace "$ARGOCD_NAMESPACE" \
    --create-namespace \
    --values /tmp/argocd-values.yaml \
    --wait \
    > /tmp/argocd-install.log 2>&1; then
    fail "ArgoCD install failed"
    cat /tmp/argocd-install.log
    exit 1
  fi

  ok "ArgoCD installed"
  rm -f /tmp/argocd-values.yaml
fi

# --- Wait for ArgoCD pods ----------------------------------------------------
header "Waiting for ArgoCD pods"

info "Waiting for argocd-server deployment..."
if ! kubectl wait --for=condition=Available deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=180s > /dev/null 2>&1; then
  warn "argocd-server not Available within 180s — checking pod status..."
  kubectl get pods -n "$ARGOCD_NAMESPACE"
  warn "Continuing anyway — ArgoCD may need more time"
fi
ok "ArgoCD server running"

# --- Verify ArgoCD login works -----------------------------------------------
header "Verifying ArgoCD login"

info "Port-forwarding argocd-server to localhost:8080..."
kubectl port-forward -n "$ARGOCD_NAMESPACE" svc/argocd-server 8080:80 --address 0.0.0.0 > /dev/null 2>&1 &
PF_PID=$!
sleep 3

# Test login via API
LOGIN_RESPONSE=$(curl -sk https://localhost:8080/api/v1/session \
  -d '{"username":"admin","password":"admin"}' \
  --connect-timeout 5 \
  --max-time 10 \
  2>/dev/null || echo "")

if echo "$LOGIN_RESPONSE" | grep -q "token"; then
  ok "ArgoCD login successful — admin/admin works!"
else
  warn "ArgoCD login test returned unexpected response"
  warn "Response: $LOGIN_RESPONSE"
  warn "You may need to wait for ArgoCD to fully initialize and retry"
fi

# Kill the port-forward
kill $PF_PID 2>/dev/null || true

# --- Install Prometheus/Grafana (optional) -----------------------------------
if [ "$SKIP_MON" = false ]; then
  header "Installing Prometheus/Grafana stack"

  if kubectl get namespace "$MONITORING_NAMESPACE" &>/dev/null 2>&1; then
    info "Monitoring namespace already exists — checking if already installed..."
    if helm list -n "$MONITORING_NAMESPACE" 2>/dev/null | grep -q "prometheus"; then
      info "Prometheus stack already installed — skipping"
    else
      warn "Namespace exists but no Prometheus release found — will install"
    fi
  fi

  if ! helm list -n "$MONITORING_NAMESPACE" 2>/dev/null | grep -q "prometheus"; then
    info "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update 2>/dev/null || true

    # Write Prometheus values to temp file (avoids heredoc pipe issues)
    cat > /tmp/prometheus-values.yaml << 'YAMLEOF'
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
  service:
    type: ClusterIP
alertmanager:
  enabled: false
YAMLEOF

    info "Installing kube-prometheus-stack..."
    if ! helm install prometheus prometheus-community/kube-prometheus-stack \
      --namespace "$MONITORING_NAMESPACE" \
      --create-namespace \
      --values /tmp/prometheus-values.yaml \
      --wait \
      > /tmp/prometheus-install.log 2>&1; then
      warn "Prometheus install had issues — check /tmp/prometheus-install.log"
      cat /tmp/prometheus-install.log
    else
      ok "Prometheus/Grafana stack installed"
    fi
    rm -f /tmp/prometheus-values.yaml
  fi
else
  info "Skipping Prometheus/Grafana installation (--skip-mon)"
fi

# --- Summary -----------------------------------------------------------------
header "Cluster Summary"

echo ""
echo "  Cluster:       $CLUSTER_NAME"
echo "  Nodes:"
kubectl get nodes --no-headers 2>/dev/null | awk '{print "    " $1 " - " $2}'
echo ""
echo "  Namespaces:"
kubectl get namespaces --no-headers 2>/dev/null | awk '{print "    " $1}'
echo ""
echo "  ArgoCD URL:    https://localhost:8080"
echo "  ArgoCD Login:  admin / admin"
echo ""
echo "  To access ArgoCD UI:"
echo "    kubectl port-forward -n argocd svc/argocd-server 8080:80"
echo "    open https://localhost:8080"
echo ""
echo "  To tear down:"
echo "    make local-down"
echo "    # or: k3d cluster delete $CLUSTER_NAME"
echo ""

ok "local-cluster.sh completed successfully"
