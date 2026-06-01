#!/bin/bash

set -euo pipefail

KUBECONFIG_PATH="~/.kube/config"

# 1. Create argocd namespace if it doesn't exist
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - --kubeconfig=""

# 2. Apply ArgoCD install.yaml
echo "Applying ArgoCD install manifests..."
kubectl apply -f k8s/argocd/install.yaml -n argocd --kubeconfig=""

# 3. Wait for ArgoCD to be ready
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s --kubeconfig=""

echo "Waiting for ArgoCD applicationset-controller to be ready..."
kubectl wait --for=condition=available deployment/argocd-applicationset-controller -n argocd --timeout=300s --kubeconfig=""

# 4. Apply app-of-apps.yaml
echo "Applying ArgoCD app-of-apps manifest..."
kubectl apply -f k8s/argocd/app-of-apps.yaml -n argocd --kubeconfig=""

# 5. Print admin password retrieval command
echo "\nArgoCD setup complete. To get the initial admin password, run:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

echo "\nTo access the ArgoCD UI, port-forward the server:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443 --kubeconfig=\"\""
