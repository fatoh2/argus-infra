#!/bin/bash
# Argus Infra — Tool Version Reporter
# Prints versions of all required CLI tools for debugging.
#
# Usage:
#   bash scripts/versions.sh

set -uo pipefail

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Argus Infra — Tool Versions      ║"
echo "╚══════════════════════════════════════╝"
echo ""

print_version() {
  local name="$1"
  local cmd="$2"
  local label="${3:-}"

  printf "  %-12s " "$name"
  if command -v "$(echo "$cmd" | awk '{print $1}')" &>/dev/null; then
    local version
    version=$(eval "$cmd" 2>/dev/null | head -1)
    echo -e "\033[1;32m✓\033[0m ${label}${version}"
  else
    echo -e "\033[1;31m✗\033[0m NOT INSTALLED"
  fi
}

print_version "terraform"   "terraform --version 2>/dev/null | head -1"
print_version "ansible"     "ansible --version 2>/dev/null | head -1"
print_version "ansible-galaxy" "ansible-galaxy --version 2>/dev/null | head -1"
print_version "kubectl"     "kubectl version --client 2>/dev/null | head -1"
print_version "helm"        "helm version --short 2>/dev/null"
print_version "argocd"      "argocd version --client --short 2>/dev/null | head -1"
print_version "k3d"         "k3d --version 2>/dev/null | head -1"
print_version "kubeseal"    "kubeseal --version 2>/dev/null"

echo ""

# Also print Ansible collection versions
if command -v ansible-galaxy &>/dev/null; then
  echo "  ── Ansible Collections ──"
  ansible-galaxy collection list 2>/dev/null | grep -E "(community\.|kubernetes\.|ansible\.)" | while read -r line; do
    echo "    $line"
  done
  echo ""
fi

echo "  ── System Info ──"
echo "    OS:      $(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"' || echo 'unknown')"
echo "    Kernel:  $(uname -r)"
echo "    Arch:    $(uname -m)"
echo ""
