#!/bin/bash
# Print versions of installed tools

echo "Argus Infra — CLI Tool Versions"
echo "═══════════════════════════════════════════════════════════════════════"

print_version() {
    local tool=$1
    local cmd=$2

    if command -v "$tool" &>/dev/null; then
        printf "%-20s " "$tool:"
        eval "$cmd" 2>/dev/null || echo "unknown"
    else
        printf "%-20s %s\n" "$tool:" "⚠️  NOT INSTALLED"
    fi
}

# Print versions
print_version "terraform" "terraform -v 2>/dev/null | head -1 | cut -d ' ' -f 1-2"
print_version "kubectl" "kubectl version --client --short 2>/dev/null | grep -o 'v[0-9.]*'"
print_version "helm" "helm version --short 2>/dev/null | cut -d ':' -f 2 | tr -d ' '"
print_version "k3d" "k3d version 2>/dev/null | grep -o 'v[0-9.]*' | head -1"
print_version "ansible" "ansible --version 2>/dev/null | head -1 | grep -o 'core [0-9.]*'"
print_version "argocd" "argocd version --short 2>/dev/null | head -1"
print_version "kubeseal" "kubeseal --version 2>/dev/null | grep -o 'v[0-9.]*'"
print_version "shellcheck" "shellcheck --version 2>/dev/null | head -1 | grep -o 'v[0-9.]*'"
print_version "git" "git --version 2>/dev/null | grep -o '[0-9.]*' | head -1"
print_version "docker" "docker --version 2>/dev/null | grep -o '[0-9.]*' | head -1"

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
