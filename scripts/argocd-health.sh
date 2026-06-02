#!/bin/bash
#===============================================================================
# argocd-health.sh — ArgoCD application health check for argus-infra
#
# Verifies all ArgoCD applications are Synced and Healthy.
# Can run via argocd CLI or kubectl (fallback).
#
# Usage:
#   ./scripts/argocd-health.sh                  # Check all apps
#   ./scripts/argocd-health.sh --verbose         # Detailed output
#   ./scripts/argocd-health.sh --app my-app      # Check specific app
#
# Exit codes:
#   0 — All apps are Synced + Healthy
#   1 — One or more apps are degraded
#===============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
VERBOSE=false
SPECIFIC_APP=""
EXIT_CODE=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    --app=*) SPECIFIC_APP="${arg#*=}" ;;
    --app) echo "Use --app=APPNAME syntax"; exit 1 ;;
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
    echo "  ❌ Required dependency '$1' is not installed."
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

# Check kubectl (required for fallback)
if ! check_dependency "kubectl"; then
  echo ""
  echo "kubectl is required. Install: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
  echo "  ❌ Cannot connect to Kubernetes cluster."
  echo "     Check KUBECONFIG or kubectl context."
  echo "     Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
  exit 1
fi
pass "Connected to cluster: $(kubectl config current-context)"

# Check if ArgoCD namespace exists
if ! kubectl get namespace argocd &>/dev/null 2>&1; then
  info "ArgoCD namespace 'argocd' not found — ArgoCD may not be installed."
  info "Run: kubectl create namespace argocd"
  info "Then: kubectl apply -n argocd -f k8s/argocd/install.yaml"
  exit 1
fi

# --- Check ArgoCD Applications -----------------------------------------------
section "ArgoCD: Application Health"

# Try argocd CLI first
if command -v argocd &>/dev/null; then
  verbose "argocd CLI found — attempting API check..."
  
  if argocd account list --grpc-web &>/dev/null 2>&1; then
    # We're logged in — use argocd CLI
    if [ -n "$SPECIFIC_APP" ]; then
      APPS="$SPECIFIC_APP"
    else
      APPS=$(argocd app list --grpc-web -o name 2>/dev/null || true)
    fi
    
    if [ -z "$APPS" ]; then
      info "No ArgoCD applications found."
      exit 0
    fi
    
    ALL_HEALTHY=true
    while IFS= read -r app; do
      APP_NAME=$(basename "$app")
      
      # Get app status via argocd CLI
      STATUS_JSON=$(argocd app get "$APP_NAME" --grpc-web -o json 2>/dev/null || echo "{}")
      
      SYNC_STATUS=$(echo "$STATUS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('status', {}).get('sync', {}).get('status', 'Unknown'))
except:
    print('Unknown')
" 2>/dev/null || echo "Unknown")
      
      HEALTH_STATUS=$(echo "$STATUS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('status', {}).get('health', {}).get('status', 'Unknown'))
except:
    print('Unknown')
" 2>/dev/null || echo "Unknown")
      
      if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
        pass "App '$APP_NAME' — Synced + Healthy"
      else
        ALL_HEALTHY=false
        fail "App '$APP_NAME' — Sync: $SYNC_STATUS, Health: $HEALTH_STATUS"
        
        # Get more details on failures
        if [ "$VERBOSE" = true ]; then
          CONDITIONS=$(echo "$STATUS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for cond in data.get('status', {}).get('conditions', []):
        print(f\"  {cond.get('type', 'Unknown')}: {cond.get('message', 'No message')}\")
except:
    pass
" 2>/dev/null || true)
          if [ -n "$CONDITIONS" ]; then
            echo "     Conditions:"
            echo "$CONDITIONS"
          fi
        fi
      fi
    done <<< "$APPS"
    
    if [ "$ALL_HEALTHY" = true ]; then
      pass "All ArgoCD applications are Synced + Healthy"
    fi
  else
    info "Not logged into ArgoCD API — falling back to kubectl"
    info "To log in: argocd login <ARGOCD_SERVER> --grpc-web"
    FALLBACK=true
  fi
else
  info "argocd CLI not found — using kubectl fallback"
  FALLBACK=true
fi

# Fallback: check ArgoCD Application CRDs via kubectl
if [ "${FALLBACK:-false}" = true ]; then
  # Check if ArgoCD CRDs exist
  if ! kubectl get crd applications.argoproj.io &>/dev/null 2>&1; then
    info "ArgoCD CRD 'applications.argoproj.io' not found — ArgoCD may not be fully installed."
    info "Check: kubectl get pods -n argocd"
    exit 1
  fi
  
  if [ -n "$SPECIFIC_APP" ]; then
    APPS_JSON=$(kubectl get application -n argocd "$SPECIFIC_APP" -o json 2>/dev/null || echo "{}")
  else
    APPS_JSON=$(kubectl get applications -n argocd -o json 2>/dev/null || echo '{"items":[]}')
  fi
  
  APP_COUNT=$(echo "$APPS_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', [data] if data.get('apiVersion') else [])
    print(len(items))
except:
    print(0)
" 2>/dev/null || echo "0")
  
  if [ "$APP_COUNT" -eq 0 ]; then
    info "No ArgoCD Application resources found in namespace 'argocd'."
    exit 0
  fi
  
  info "Found $APP_COUNT ArgoCD application(s)"
  ALL_HEALTHY=true
  
  echo "$APPS_JSON" | python3 -c "
import json, sys

try:
    data = json.load(sys.stdin)
    items = data.get('items', [data] if data.get('apiVersion') else [])
    
    all_healthy = True
    for app in items:
        name = app.get('metadata', {}).get('name', 'unknown')
        status = app.get('status', {})
        sync = status.get('sync', {}).get('status', 'Unknown')
        health = status.get('health', {}).get('status', 'Unknown')
        
        icon = '✅' if sync == 'Synced' and health == 'Healthy' else '❌'
        print(f\"  {icon} App '{name}' — Sync: {sync}, Health: {health}\")
        
        if sync != 'Synced' or health != 'Healthy':
            all_healthy = False
            for cond in status.get('conditions', []):
                print(f\"     {cond.get('type', '')}: {cond.get('message', '')}\")
    
    if all_healthy:
        print()
        print('  ✅ All ArgoCD applications are Synced + Healthy')
    else:
        sys.exit(1)
" 2>/dev/null || EXIT_CODE=1
fi

# --- Summary -----------------------------------------------------------------
section "Summary"

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  ✅ ArgoCD health check passed!"
else
  echo "  ❌ Some ArgoCD applications have issues."
fi

exit "$EXIT_CODE"
