#!/bin/bash

# Install ArgoCD CLI
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argocd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Create ArgoCD namespace
kubectl create namespace argocd || true

# Install ArgoCD manifests
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Apply the app-of-apps manifest
kubectl apply -f k8s/argocd/app-of-apps.yaml -n argocd

echo "ArgoCD bootstrap complete."
