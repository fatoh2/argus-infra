#!/bin/bash
set -euo pipefail

CLUSTER_NAME="argus-local"

# Prerequisite checks
command -v k3d >/dev/null 2>&1 || { echo "Error: k3d not found. Install from https://k3d.io"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found. Install from https://kubernetes.io/docs/tasks/tools/"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Error: helm not found. Install from https://helm.sh/docs/intro/install/"; exit 1; }

echo "Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create "$CLUSTER_NAME" --port 8080:80@loadbalancer --port 8443:443@loadbalancer

echo "Exporting kubeconfig..."
KUBECONFIG=$(k3d kubeconfig write "$CLUSTER_NAME")
export KUBECONFIG
echo "KUBECONFIG for $CLUSTER_NAME is set. You can also run: export KUBECONFIG=\"$(k3d kubeconfig write $CLUSTER_NAME)\""

echo "Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo "Installing kube-prometheus-stack..."
helm repo list | grep -q prometheus-community || helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --wait

echo "Installing Loki..."
helm repo list | grep -q grafana || helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
helm install loki grafana/loki -n logging --wait

echo ""
echo "=== Local k3d cluster setup complete! ==="
echo ""
echo "To access ArgoCD:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "  Initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
echo "To access Grafana (kube-prometheus-stack):"
echo "  kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo ""
echo "To access Loki:"
echo "  kubectl port-forward svc/loki -n logging 3100:3100"
echo ""
echo "To tear down:"
echo "  bash scripts/local-cluster-down.sh"
