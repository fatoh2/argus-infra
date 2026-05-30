#!/bin/bash
# Argus Agent — Hetzner VPS Setup Script
# Run as root on a fresh Ubuntu 24.04 CX22 server
# Usage: curl -fsSL https://raw.githubusercontent.com/fatoh2/argus-infra/main/scripts/setup-agent.sh | bash

set -euo pipefail

ARGUS_USER="argus"
ARGUS_DIR="/opt/argus"
PIP="/opt/argus/venv/bin/pip"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║     Argus Agent Server Setup         ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── System updates ────────────────────────────────────────────────────────────
echo "[1/9] Updating system packages..."
apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git jq unzip build-essential \
  software-properties-common gnupg ca-certificates \
  python3 python3-venv python3-pip \
  sqlite3 libsqlite3-dev

# ── Node.js 20 ────────────────────────────────────────────────────────────────
echo "[2/9] Installing Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
apt-get install -y -qq nodejs

# ── Terraform ────────────────────────────────────────────────────────────────
echo "[3/9] Installing Terraform..."
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
apt-get update -qq && apt-get install -y -qq terraform

# ── kubectl + Helm ────────────────────────────────────────────────────────────
echo "[4/9] Installing kubectl and Helm..."
curl -LsO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1

# ── hcloud CLI ────────────────────────────────────────────────────────────────
echo "[5/9] Installing hcloud CLI..."
HCLOUD_VERSION=$(curl -s https://api.github.com/repos/hetznercloud/cli/releases/latest | jq -r '.tag_name')
curl -LsO "https://github.com/hetznercloud/cli/releases/download/${HCLOUD_VERSION}/hcloud-linux-amd64.tar.gz"
tar xzf hcloud-linux-amd64.tar.gz hcloud
mv hcloud /usr/local/bin/ && rm hcloud-linux-amd64.tar.gz

# ── Ansible ───────────────────────────────────────────────────────────────────
echo "[6/9] Installing Ansible..."
pip3 install -q ansible

# ── argus user + directories ──────────────────────────────────────────────────
echo "[7/9] Creating argus user and directories..."
id -u "$ARGUS_USER" &>/dev/null || useradd -m -s /bin/bash "$ARGUS_USER"
mkdir -p \
  "$ARGUS_DIR/orchestrator" \
  "$ARGUS_DIR/workspaces/argus-infra" \
  "$ARGUS_DIR/workspaces/argus-monitor" \
  "$ARGUS_DIR/workspaces/argus-ai" \
  "$ARGUS_DIR/logs" \
  "$ARGUS_DIR/data"
chown -R "$ARGUS_USER:$ARGUS_USER" "$ARGUS_DIR"

# ── Python venv ───────────────────────────────────────────────────────────────
echo "[8/9] Creating Python virtual environment..."
python3 -m venv "$ARGUS_DIR/venv"
"$PIP" install -q --upgrade pip

# ── Git global config for argus user ─────────────────────────────────────────
echo "[9/9] Configuring git..."
su - "$ARGUS_USER" -c "git config --global user.name 'Argus PM Agent'"
su - "$ARGUS_USER" -c "git config --global user.email 'argus-agent@noreply.github.com'"
su - "$ARGUS_USER" -c "git config --global pull.rebase false"

echo ""
echo "✓ Base server setup complete."
echo ""
echo "Next steps:"
echo "  1. Copy orchestrator files to $ARGUS_DIR/orchestrator/"
echo "  2. Copy .env to $ARGUS_DIR/orchestrator/.env"
echo "  3. Run: $PIP install -r $ARGUS_DIR/orchestrator/requirements.txt"
echo "  4. Run: bash $ARGUS_DIR/orchestrator/scripts/clone-repos.sh"
echo "  5. Run: systemctl enable --now argus-worker"
echo ""
