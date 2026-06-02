#!/bin/bash
#===============================================================================
# local-cluster-down.sh — Tear down the local k3d cluster
#
# Usage:
#   bash scripts/local-cluster-down.sh
#
# Exit codes:
#   0 — Cluster deleted or didn't exist
#===============================================================================

set -euo pipefail

CLUSTER_NAME="argus-local"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "  ${BLUE}*${NC} $*"; }
ok()    { echo -e "  ${GREEN}+${NC} $*"; }
warn()  { echo -e "  ${YELLOW}!${NC} $*"; }

if ! command -v k3d &>/dev/null; then
  warn "k3d not installed — nothing to do"
  exit 0
fi

if k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
  info "Deleting cluster '$CLUSTER_NAME'..."
  k3d cluster delete "$CLUSTER_NAME" > /tmp/k3d-delete.log 2>&1
  ok "Cluster '$CLUSTER_NAME' deleted"
else
  info "No cluster '$CLUSTER_NAME' found — nothing to do"
fi
