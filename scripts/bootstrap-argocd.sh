#!/bin/bash
set -euo pipefail
# This script includes basic error handling with set -euo pipefail and error_exit function.

log() {
  echo "--- $(date '+%Y-%m-%d %H:%M:%S') --- $1"
}

error_exit() {
  log "Last command: ${last_command}"
  local last_command="${BASH_COMMAND}"
  log "ERROR: $1" >&2
  exit 1
}

log "Installing ArgoCD CLI"
ARGOCD_VERSION=$(curl --silent "https://api.github.com/repos/argoproj/argocd/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') || error_exit "Failed to get latest ArgoCD version"
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argocd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64 || error_exit "Failed to download ArgoCD CLI"
chmod +x /usr/local/bin/argocd || error_exit "Failed to make ArgoCD CLI executable"
log "ArgoCD CLI v${ARGOCD_VERSION} installed."

log "Installing ArgoCD into Kubernetes"
kubectl create namespace argocd || log "Namespace argocd already exists, continuing."
kubectl apply -n argocd -f k8s/argocd/install.yaml || error_exit "Failed to apply ArgoCD install manifests"
log "Applying ArgoCD configuration"
kubectl apply -n argocd -f k8s/argocd/config/argocd-cmd-params-cm.yaml || error_exit "Failed to apply ArgoCD command parameters config"
kubectl apply -n argocd -f k8s/argocd/config/argocd-rbac-cm.yaml || error_exit "Failed to apply ArgoCD RBAC config"
kubectl apply -n argocd -f k8s/argocd/config/argocd-cm.yaml || error_exit "Failed to apply ArgoCD general config"

log "Waiting for ArgoCD server to be ready"
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s || error_exit "ArgoCD server did not become ready within timeout"

log "Applying ArgoCD App of Apps"
kubectl apply -n argocd -f k8s/argocd/app-of-apps.yaml || error_exit "Failed to apply ArgoCD App of Apps manifest"

log "Retrieving initial ArgoCD admin password"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) || error_exit "Failed to retrieve ArgoCD admin password"
log "ArgoCD admin password: ${ARGOCD_PASSWORD}"
log "You can log in with username 'admin' and the password above."
log "Port forward to access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
