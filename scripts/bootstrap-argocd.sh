#!/bin/bash

set -euo pipefail

echo "Applying ArgoCD install manifest..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f k8s/argocd/install.yaml

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "Applying app-of-apps manifest..."
kubectl apply -n argocd -f k8s/argocd/app-of-apps.yaml

echo "ArgoCD setup complete. To retrieve the admin password, run:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d"
