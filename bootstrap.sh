#!/bin/bash
# bootstrap.sh — zero-dependency entry point for fresh machines
# Installs `make` if missing, then runs make install-tools + make local-up
# Usage: bash bootstrap.sh
set -e

echo "=== Argus Infra Bootstrap ==="

# Install make if missing (the only true prerequisite)
if ! command -v make &>/dev/null; then
    echo "→ Installing make..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq make
    elif command -v brew &>/dev/null; then
        brew install make
    elif command -v yum &>/dev/null; then
        sudo yum install -y make
    else
        echo "✗ Cannot install make — no supported package manager found."
        echo "  Install make manually then re-run: make install-tools"
        exit 1
    fi
    echo "✓ make installed"
fi

make install-tools
echo ""
echo "✅ All tools installed. Run 'make local-up' to start the cluster."
