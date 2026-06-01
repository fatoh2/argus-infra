#!/bin/bash
#===============================================================================
# cluster-sanity.sh — Cluster-level sanity checks for argus-infra
#
# Requires:
#   - kubectl configured with cluster access (KUBECONFIG env or default context)
#   - argocd CLI installed (for ArgoCD health checks)
#   - curl (for ingress reachability tests)
#
# Usage:
#   ./scripts/cluster-sanity.sh                    # Run all checks
#   ./scripts/cluster-sanity.sh --skip-argocd      # Skip ArgoCD checks
#   ./scripts/cluster-sanity.sh --skip-ingress     # Skip ingress checks
#   ./scripts/cluster-sanity.sh --verbose          # Detailed output
#
# Exit codes:
#   0 — All checks passed
#   1 — One or more checks failed
#===============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
VERBOSE=false
SKIP_ARGOCD=false
SKIP_INGRESS=false
EXIT_CODE=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=true ;;
    --skip-argocd) SKIP_ARGOCD=true ;;
    --skip-ingress) SKIP_INGRESS=true ;;
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

# --- Pre-flight checks -------------------------------------------------------
section "Pre-flight Checks"

# Check kubectl
if ! check_dependency "kubectl"; then
  fail "kubectl is required for cluster sanity checks."
  echo ""
  echo "Install: https://kubernetes.io/docs/tasks/tools/"
  exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info --request-timeout=5s &>/dev/null; then
  fail "Cannot connect to Kubernetes cluster. Check KUBECONFIG or kubectl context."
  echo ""
  echo "  Current context: $(kubectl config current-context 2>/dev/null || echo 'none')"
  exit 1
fi
pass "Connected to Kubernetes cluster: $(kubectl config current-context)"

# --- Cluster Sanity: Node Status ---------------------------------------------
section "Cluster Sanity: Node Status"

NODES=$(kubectl get nodes --no-headers 2>/dev/null || true)
if [ -z "$NODES" ]; then
  fail "No nodes found in cluster."
else
  NODE_COUNT=$(echo "$NODES" | wc -l)
  info "Found $NODE_COUNT node(s)"
  
  while IFS= read -r node; do
    NAME=$(echo "$node" | awk '{print $1}')
    STATUS=$(echo "$node" | awk '{print $2}')
    if [ "$STATUS" = "Ready" ]; then
      pass "Node '$NAME' is Ready"
    else
      fail "Node '$NAME' is $STATUS"
    fi
  done <<< "$NODES"
fi

# --- Cluster Sanity: All Pods Running ----------------------------------------
section "Cluster Sanity: Pod Status"

# Check pods across all namespaces
NAMESPACES=$(kubectl get namespaces -o name | cut -d/ -f2 2>/dev/null || true)
if [ -z "$NAMESPACES" ]; then
  fail "Cannot list namespaces."
else
  ALL_PODS_RUNNING=true
  POD_FAILURES=""
  
  while IFS= read -r ns; do
    PODS=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null || true)
    if [ -z "$PODS" ]; then
      continue
    fi
    
    while IFS= read -r pod; do
      NAME=$(echo "$pod" | awk '{print $1}')
      STATUS=$(echo "$pod" | awk '{print $3}')
      READY=$(echo "$pod" | awk '{print $2}')
      RESTARTS=$(echo "$pod" | awk '{print $4}')
      
      # Check if pod is not Running or Completed
      if [ "$STATUS" != "Running" ] && [ "$STATUS" != "Completed" ]; then
        ALL_PODS_RUNNING=false
        POD_FAILURES="${POD_FAILURES}  ❌ $ns/$NAME — Status: $STATUS (Ready: $READY, Restarts: $RESTARTS)\n"
      fi
      
      # Check if pod has excessive restarts (>5)
      if [ "$STATUS" = "Running" ] && [ "$RESTARTS" -gt 5 ] 2>/dev/null; then
        verbose "⚠️  Pod '$ns/$NAME' has $RESTARTS restarts"
      fi
    done <<< "$PODS"
  done <<< "$NAMESPACES"
  
  if [ "$ALL_PODS_RUNNING" = true ]; then
    pass "All pods are Running or Completed"
  else
    fail "Some pods are not healthy:"
    echo -e "$POD_FAILURES"
  fi
fi

# --- ArgoCD App Health Check -------------------------------------------------
if [ "$SKIP_ARGOCD" = false ]; then
  section "ArgoCD: Application Health"
  
  if ! check_dependency "argocd"; then
    info "argocd CLI not found — checking ArgoCD apps via kubectl instead."
  fi
  
  # Try argocd CLI first, fall back to kubectl
  if command -v argocd &>/dev/null; then
    # Check if logged in
    if argocd account list --grpc-web &>/dev/null; then
      APPS=$(argocd app list --grpc-web -o name 2>/dev/null || true)
      if [ -z "$APPS" ]; then
        info "No ArgoCD applications found."
      else
        ALL_HEALTHY=true
        APP_FAILURES=""
        
        while IFS= read -r app; do
          APP_NAME=$(basename "$app")
          STATUS=$(argocd app get "$APP_NAME" --grpc-web -o json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    sync = data.get('status', {}).get('sync', {}).get('status', 'Unknown')
    health = data.get('status', {}).get('health', {}).get('status', 'Unknown')
    print(f'{sync} {health}')
except:
    print('Unknown Unknown')
" 2>/dev/null || echo "Unknown Unknown")
          
          SYNC_STATUS=$(echo "$STATUS" | awk '{print $1}')
          HEALTH_STATUS=$(echo "$STATUS" | awk '{print $2}')
          
          if [ "$SYNC_STATUS" = "Synced" ] && [ "$HEALTH_STATUS" = "Healthy" ]; then
            pass "App '$APP_NAME' — Synced + Healthy"
          else
            ALL_HEALTHY=false
            APP_FAILURES="${APP_FAILURES}  ❌ App '$APP_NAME' — Sync: $SYNC_STATUS, Health: $HEALTH_STATUS\n"
          fi
        done <<< "$APPS"
        
        if [ "$ALL_HEALTHY" = true ]; then
          pass "All ArgoCD applications are Synced and Healthy"
        else
          fail "Some ArgoCD applications are not healthy:"
          echo -e "$APP_FAILURES"
        fi
      fi
    else
      info "Not logged into ArgoCD — checking via kubectl."
      # Fall through to kubectl method
    fi
  fi
  
  # Fallback: check ArgoCD Application CRDs via kubectl
  if ! command -v argocd &>/dev/null || ! argocd account list --grpc-web &>/dev/null; then
    if kubectl get crd applications.argoproj.io &>/dev/null 2>&1; then
      APPS=$(kubectl get applications -n argocd -o json 2>/dev/null || true)
      if [ -z "$APPS" ] || [ "$APPS" = "{}" ]; then
        info "No ArgoCD Application CRDs found."
      else
        ALL_HEALTHY=true
        APP_FAILURES=""
        
        echo "$APPS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', [])
    if not items:
        print('NO_APPS')
    for app in items:
        name = app.get('metadata', {}).get('name', 'unknown')
        sync = app.get('status', {}).get('sync', {}).get('status', 'Unknown')
        health = app.get('status', {}).get('health', {}).get('status', 'Unknown')
        print(f'{name}|{sync}|{health}')
except Exception as e:
    print(f'ERROR|{e}')
" 2>/dev/null | while IFS='|' read -r name sync health; do
          if [ "$name" = "NO_APPS" ]; then
            info "No ArgoCD Application CRDs found."
          elif [ "$name" = "ERROR" ]; then
            fail "Failed to parse ArgoCD applications: $sync"
          else
            if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
              pass "App '$name' — Synced + Healthy"
            else
              fail "App '$name' — Sync: $sync, Health: $health"
            fi
          fi
        done
      fi
    else
      info "ArgoCD CRD not found — ArgoCD may not be installed."
    fi
  fi
else
  info "ArgoCD checks skipped (--skip-argocd)"
fi

# --- Ingress Reachability Test ------------------------------------------------
if [ "$SKIP_INGRESS" = false ]; then
  section "Ingress: Reachability Tests"
  
  if ! check_dependency "curl"; then
    fail "curl is required for ingress reachability tests."
  else
    # Get ingress URLs from Kubernetes
    INGRESSES=$(kubectl get ingress -A -o json 2>/dev/null || true)
    
    if [ -z "$INGRESSES" ] || [ "$INGRESSES" = "{}" ]; then
      info "No Ingress resources found — checking Services with LoadBalancer type."
      
      # Fallback: check LoadBalancer services
      LBS=$(kubectl get svc -A -o json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for svc in data.get('items', []):
        if svc.get('spec', {}).get('type') == 'LoadBalancer':
            name = svc.get('metadata', {}).get('name', 'unknown')
            ns = svc.get('metadata', {}).get('namespace', 'unknown')
            ingress = svc.get('status', {}).get('loadBalancer', {}).get('ingress', [])
            if ingress:
                host = ingress[0].get('hostname') or ingress[0].get('ip', '')
                ports = svc.get('spec', {}).get('ports', [])
                port = ports[0].get('port', 443) if ports else 443
                print(f'{ns}/{name}|{host}|{port}')
except:
    pass
" 2>/dev/null || true)
      
      if [ -n "$LBS" ]; then
        while IFS='|' read -r svc_name host port; do
          if [ -n "$host" ]; then
            if curl -sfk --max-time 5 "https://$host:$port" &>/dev/null; then
              pass "LoadBalancer '$svc_name' reachable at https://$host:$port"
            else
              fail "LoadBalancer '$svc_name' NOT reachable at https://$host:$port"
            fi
          fi
        done <<< "$LBS"
      else
        info "No LoadBalancer services with external IPs found."
      fi
    else
      # Test each ingress endpoint
      echo "$INGRESSES" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    items = data.get('items', [])
    for ing in items:
        name = ing.get('metadata', {}).get('name', 'unknown')
        ns = ing.get('metadata', {}).get('namespace', 'unknown')
        rules = ing.get('spec', {}).get('rules', [])
        tls = ing.get('spec', {}).get('tls', [])
        tls_hosts = set()
        for t in tls:
            for h in t.get('hosts', []):
                tls_hosts.add(h)
        for rule in rules:
            host = rule.get('host', '')
            protocol = 'https' if host in tls_hosts else 'http'
            print(f'{ns}/{name}|{protocol}|{host}')
except:
    pass
" 2>/dev/null | while IFS='|' read -r ing_name protocol host; do
        if [ -n "$host" ]; then
          if curl -sfk --max-time 5 "${protocol}://${host}" &>/dev/null; then
            pass "Ingress '$ing_name' reachable at ${protocol}://${host}"
          else
            fail "Ingress '$ing_name' NOT reachable at ${protocol}://${host}"
          fi
        fi
      done
    fi
  fi
else
  info "Ingress checks skipped (--skip-ingress)"
fi

# --- Summary -----------------------------------------------------------------
section "Summary"

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  ✅ All cluster sanity checks passed!"
else
  echo "  ❌ Some cluster sanity checks failed."
fi

exit "$EXIT_CODE"
