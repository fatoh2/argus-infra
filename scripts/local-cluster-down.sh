#!/bin/bash
# Tear down local k3d cluster

set -e

CLUSTER_NAME="argus-local"

log() { echo "→ $1"; }
ok() { echo "✓ $1"; }

log "Tearing down k3d cluster: $CLUSTER_NAME..."

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    k3d cluster delete "$CLUSTER_NAME" || {
        echo "✗ Failed to delete cluster"
        exit 1
    }
    ok "Cluster deleted"
else
    echo "⚠️  Cluster '$CLUSTER_NAME' not found"
    exit 0
fi

# Remove kubeconfig
if [ -f ~/.kube/config-"$CLUSTER_NAME" ]; then
    rm ~/.kube/config-"$CLUSTER_NAME"
    ok "Kubeconfig removed"
fi

# Remove registry
if k3d registry list | grep -q "^argus-local$"; then
    k3d registry delete argus-local 2>/dev/null || true
fi

echo ""
echo "✅ Local cluster '$CLUSTER_NAME' has been torn down"
