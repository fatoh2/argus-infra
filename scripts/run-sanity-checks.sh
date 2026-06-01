#!/bin/bash

echo "Running sanity checks..."

# Placeholder for future sanity checks
# For now, just ensure basic commands work and files exist

# Check Terraform directory and files
if [ -d "terraform/environments/homelab" ]; then
    echo "Terraform homelab environment directory exists."
else
    echo "Error: Terraform homelab environment directory does not exist." >&2
    exit 1
fi

if [ -f "terraform/environments/homelab/main.tf" ]; then
    echo "Terraform homelab main.tf exists."
else
    echo "Error: Terraform homelab main.tf does not exist." >&2
    exit 1
fi

# Check Ansible directory and files
if [ -d "ansible" ]; then
    echo "Ansible directory exists."
else
    echo "Error: Ansible directory does not exist." >&2
    exit 1
fi

if [ -f "ansible/playbooks/site.yml" ]; then
    echo "Ansible site.yml exists."
else
    echo "Error: Ansible site.yml does not exist." >&2
    exit 1
fi

if [ -f "ansible/inventory/homelab.yml.example" ]; then
    echo "Ansible homelab.yml.example exists."
else
    echo "Error: Ansible homelab.yml.example does not exist." >&2
    exit 1
fi

# Check ArgoCD app-of-apps.yaml
if [ -f "k8s/argocd/app-of-apps.yaml" ]; then
    echo "ArgoCD app-of-apps.yaml exists."
else
    echo "Error: ArgoCD app-of-apps.yaml does not exist." >&2
    exit 1
fi

echo "Sanity checks passed (placeholder)."
