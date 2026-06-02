#!/bin/bash
set -euo pipefail

CLUSTER_NAME="argus-local"

echo "Deleting k3d cluster: $CLUSTER_NAME"
k3d cluster delete "$CLUSTER_NAME"

echo "Local k3d cluster teardown complete!"
