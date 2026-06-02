#!/bin/bash
set -euo pipefail

CLUSTER_NAME="argus-local"

echo "Creating k3d cluster: $CLUSTER_NAME"
k3d cluster create $CLUSTER_NAME --port 8080:80@loadbalancer --port 8443:443@loadbalancer

echo "Exporting kubeconfig..."
export KUBECONFIG="$(k3d kubeconfig write $CLUSTER_NAME)"
echo "KUBECONFIG for $CLUSTER_NAME is set. You can also run: export KUBECONFIG=\"$(k3d kubeconfig write $CLUSTER_NAME)\""

echo "Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=300s

echo "Installing kube-prometheus-stack..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update
kubectl create namespace monitoring || true
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --wait

echo "Installing Loki..."
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update
kubectl create namespace logging || true
helm install loki grafana/loki -n logging --wait

echo "Local k3d cluster setup complete!"
echo "To access ArgoCD, port-forward the server: kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo "To get the initial ArgoCD password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "To access Grafana (part of kube-prometheus-stack), port-forward: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
echo "To access Loki, port-forward: kubectl port-forward svc/loki -n logging 3100:3100"
