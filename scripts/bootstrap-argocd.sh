#!/bin/bash

# Apply ArgoCD install.yaml
kubectl apply -f k8s/argocd/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available -n argocd deployment/argocd-server --timeout=300s

# Apply app-of-apps.yaml
kubectl apply -f k8s/argocd/app-of-apps.yaml

# Print admin password retrieval command
echo "ArgoCD admin password command:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{\".data.password\"}\" | base64 -d; echo"
