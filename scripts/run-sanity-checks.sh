#!/bin/bash
#===============================================================================
# run-sanity-checks.sh — Local sanity check suite for argus-infra
#
# Runs all checks that can be performed without a live cluster:
#   - Terraform validate + format check
#   - Ansible syntax check + lint
#   - File structure integrity
#   - ArgoCD manifest validation (kubectl dry-run style)
#
# Usage:
#   ./scripts/run-sanity-checks.sh              # Run all checks
#   ./scripts/run-sanity-checks.sh --verbose    # Detailed output
#   ./scripts/run-sanity-checks.sh --skip-ansible-lint  # Skip slow lint
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed
#===============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
VERBOSE=false
SKIP_ANSIBLE_LINT=false
EXIT_CODE=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    --skip-ansible-lint) SKIP_ANSIBLE_LINT=true ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# --- Helper functions --------------------------------------------------------
pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; EXIT_CODE=1; }
info() { echo "  ℹ️  $1"; }
verbose() { if [ "$VERBOSE" = true ]; then echo "     $1"; fi; }

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    fail "Required dependency '$1' is not installed."
    return 1
  fi
}

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  $1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# --- Pre-flight Checks -------------------------------------------------------
section "Pre-flight Checks"

cd "$REPO_ROOT"

# Check required tools
check_dependency "terraform" || true
check_dependency "ansible-playbook" || true

# Verify repo structure
REQUIRED_DIRS=(
  "terraform/environments/homelab"
  "ansible/playbooks"
  "ansible/roles"
  "ansible/inventory"
  "k8s/argocd"
  "scripts"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ -d "$dir" ]; then
    verbose "Directory exists: $dir"
  else
    fail "Required directory missing: $dir"
  fi
done

# --- Terraform Checks --------------------------------------------------------
section "Terraform: Validate + Format"

if command -v terraform &>/dev/null; then
  TF_DIR="$REPO_ROOT/terraform/environments/homelab"
  
  if [ -d "$TF_DIR" ]; then
    cd "$TF_DIR"
    
    # Terraform init (backend=false for local validation)
    info "Initializing Terraform (backend=false)..."
    if terraform init -backend=false -input=false 2>&1; then
      pass "Terraform initialized successfully"
    else
      fail "Terraform init failed"
      cd "$REPO_ROOT"
      section "Summary"
      echo "  ❌ Some sanity checks failed."
      exit 1
    fi
    
    # Terraform validate
    info "Running terraform validate..."
    if terraform validate 2>&1; then
      pass "Terraform configuration is valid"
    else
      fail "Terraform validation failed"
    fi
    
    # Terraform format check
    info "Running terraform fmt -check..."
    if terraform fmt -check -recursive 2>&1; then
      pass "Terraform formatting is correct"
    else
      fail "Terraform formatting issues found (run 'terraform fmt -recursive' to fix)"
    fi
    
    # Terraform plan (no apply) — uses dummy variables, targets only network module
    info "Running terraform plan (syntax-only, no apply)..."
    PLAN_OUTPUT=$(terraform plan -no-color -input=false \
      -target=module.network \
      -var="hcloud_token=0000000000000000000000000000000000000000000000000000000000000000" \
      -var="ssh_key_name=ci-dummy-key" \
      -var="ssh_key_id=0" \
      -var="location=nbg1" \
      -var="server_type=cx22" \
      -var="image=ubuntu-24.04" \
      2>&1 || true)
    
    if echo "$PLAN_OUTPUT" | grep -q "No changes"; then
      pass "Terraform plan: no changes (expected for CI)"
    elif echo "$PLAN_OUTPUT" | grep -q "Plan:"; then
      pass "Terraform plan generated successfully"
    else
      fail "Terraform plan failed or produced unexpected output"
      verbose "Plan output:"
      verbose "$PLAN_OUTPUT"
    fi
    
    cd "$REPO_ROOT"
  else
    fail "Terraform directory not found: $TF_DIR"
  fi
else
  fail "terraform not found in PATH — skipping Terraform checks"
fi

# --- Ansible Checks ----------------------------------------------------------
section "Ansible: Syntax Check + Lint"

if command -v ansible-playbook &>/dev/null; then
  # Check inventory file exists
  CI_INVENTORY="$REPO_ROOT/ansible/inventory/homelab.ci.yml"
  if [ ! -f "$CI_INVENTORY" ]; then
    fail "CI inventory file not found: $CI_INVENTORY"
  else
    verbose "Using CI inventory: $CI_INVENTORY"
  fi
  
  # Ansible syntax check
  info "Running ansible-playbook --syntax-check..."
  if ansible-playbook --syntax-check \
    -i "$REPO_ROOT/ansible/inventory/homelab.ci.yml" \
    "$REPO_ROOT/ansible/playbooks/site.yml" \
    2>&1; then
    pass "Ansible playbook syntax is valid"
  else
    fail "Ansible syntax check failed"
  fi
  
  # Ansible lint (optional, can be slow)
  if [ "$SKIP_ANSIBLE_LINT" = false ]; then
    if command -v ansible-lint &>/dev/null; then
      info "Running ansible-lint..."
      if ansible-lint "$REPO_ROOT/ansible/playbooks/" "$REPO_ROOT/ansible/roles/" \
        -c "$REPO_ROOT/.ansible-lint" \
        2>&1; then
        pass "Ansible lint passed"
      else
        fail "Ansible lint found issues"
      fi
    else
      info "ansible-lint not installed — skipping lint (install with: pip install ansible-lint)"
    fi
  else
    info "Ansible lint skipped (--skip-ansible-lint)"
  fi
else
  fail "ansible-playbook not found in PATH — skipping Ansible checks"
fi

# --- File Structure Integrity ------------------------------------------------
section "File Structure: Integrity Checks"

MISSING_FILES=0

# Critical files that must exist
CRITICAL_FILES=(
  "terraform/environments/homelab/main.tf"
  "terraform/environments/homelab/variables.tf"
  "terraform/environments/homelab/outputs.tf"
  "ansible/playbooks/site.yml"
  "ansible/inventory/homelab.ci.yml"
  "ansible/inventory/homelab.yml.example"
  "ansible/requirements.yml"
  "k8s/argocd/app-of-apps.yaml"
  "k8s/argocd/install.yaml"
  "scripts/cluster-sanity.sh"
  "scripts/bootstrap-argocd.sh"
  "CLAUDE.md"
  "README.md"
)

for file in "${CRITICAL_FILES[@]}"; do
  if [ -f "$REPO_ROOT/$file" ]; then
    verbose "File exists: $file"
  else
    fail "Critical file missing: $file"
    MISSING_FILES=$((MISSING_FILES + 1))
  fi
done

if [ "$MISSING_FILES" -eq 0 ]; then
  pass "All critical files present"
fi

# --- ArgoCD Manifest Validation (kubectl dry-run) ----------------------------
section "ArgoCD: Manifest Validation"

if command -v kubectl &>/dev/null; then
  info "Validating ArgoCD manifests with kubectl dry-run..."
  
  # Check if we have a cluster connection
  if kubectl cluster-info --request-timeout=3s &>/dev/null; then
    # We have a cluster — do a real dry-run validation
    ARGOCD_DIRS=(
      "$REPO_ROOT/k8s/argocd"
      "$REPO_ROOT/k8s/grafana"
      "$REPO_ROOT/k8s/cluster-issuer"
    )
    
    for dir in "${ARGOCD_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        for file in "$dir"/*.yaml; do
          if [ -f "$file" ]; then
            if kubectl apply --dry-run=client -f "$file" &>/dev/null; then
              verbose "Valid manifest: $file"
            else
              fail "Invalid manifest: $file"
            fi
          fi
        done
      fi
    done
    pass "ArgoCD manifests validated against cluster"
  else
    info "No cluster connection — skipping kubectl dry-run validation"
    info "Manifest syntax will be validated by ArgoCD on deploy"
  fi
else
  info "kubectl not found — skipping ArgoCD manifest validation"
fi

# --- Summary -----------------------------------------------------------------
section "Summary"

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  ✅ All sanity checks passed!"
else
  echo "  ❌ Some sanity checks failed."
fi

exit "$EXIT_CODE"
