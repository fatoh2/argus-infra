.PHONY: help install-tools local-up local-down lint validate plan sanity check-versions setup-windows

help:
	@echo "Argus Infra — Makefile Targets"
	@echo ""
	@echo "Development (local k3d):"
	@echo "  make install-tools   - Install required CLI tools (Terraform, Ansible, kubectl, k3d, etc.)"
	@echo "  make local-up        - Spin up local k3d cluster with ArgoCD, Prometheus, Loki"
	@echo "  make local-down      - Tear down local k3d cluster"
	@echo "  make sanity          - Run full local sanity check suite"
	@echo ""
	@echo "Windows-specific:"
	@echo "  make setup-windows   - Show Windows setup guide and Docker Desktop instructions"
	@echo ""
	@echo "Production (Hetzner):"
	@echo "  make plan            - Terraform plan for Hetzner infrastructure"
	@echo ""
	@echo "Validation:"
	@echo "  make lint            - Run Terraform fmt -check, ansible-lint, shellcheck"
	@echo "  make validate        - Terraform validate (no backend)"
	@echo "  make check-versions  - Print installed tool versions"
	@echo ""

install-tools:
	@echo "Installing required CLI tools..."
	./scripts/install-tools.sh

local-up:
	@echo "Spinning up local k3d cluster..."
	./scripts/local-cluster.sh

local-down:
	@echo "Tearing down local k3d cluster..."
	./scripts/local-cluster-down.sh

lint:
	@echo "Running linters..."
	@echo "→ Terraform fmt -check"
	cd terraform && terraform fmt -check -recursive . || exit 1
	@echo "→ ansible-lint"
	ansible-lint ansible/ || exit 1
	@echo "→ shellcheck"
	find scripts -name "*.sh" -exec shellcheck {} + || exit 1
	@echo "✓ All linters passed"

validate:
	@echo "Validating Terraform..."
	cd terraform && terraform init -backend=false && terraform validate

plan:
	@echo "Running Terraform plan..."
	@if [ -z "$$HCLOUD_TOKEN" ]; then \
		echo "Error: HCLOUD_TOKEN environment variable not set"; \
		exit 1; \
	fi
	cd terraform/environments/homelab && terraform init && terraform plan -target=module.network

sanity: lint validate
	@echo "Running full sanity check suite..."
	./scripts/run-sanity-checks.sh

check-versions:
	@echo "Installed tool versions:"
	@./scripts/versions.sh

bootstrap:
	@bash ./BOOTSTRAP_WINDOWS.sh

setup-windows:
	@echo "╔════════════════════════════════════════════════════════════════════════╗"
	@echo "║         Argus Infra on Windows — Setup Guide                          ║"
	@echo "╚════════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Windows requires Docker Desktop with WSL2 backend for k3d clusters."
	@echo ""
	@echo "📋 PREREQUISITE CHECKLIST:"
	@echo ""
	@echo "  [ ] Docker Desktop installed?"
	@echo "      Download: https://www.docker.com/products/docker-desktop"
	@echo "      ⚠️  IMPORTANT: Enable WSL2 backend during installation"
	@echo ""
	@echo "  [ ] Docker Desktop running?"
	@echo "      Check system tray for Docker icon"
	@echo ""
	@echo "  [ ] Docker verified?"
	@echo "      Run: docker --version"
	@echo ""
	@echo "📦 QUICK START:"
	@echo ""
	@echo "  1. Install tools:"
	@echo "     make install-tools"
	@echo ""
	@echo "  2. Verify installation:"
	@echo "     make check-versions"
	@echo ""
	@echo "  3. Create local cluster:"
	@echo "     make local-up"
	@echo ""
	@echo "  4. Access services (in separate terminal):"
	@echo "     kubectl port-forward -n argocd svc/argocd-server 8080:443"
	@echo "     # Open: https://localhost:8080"
	@echo ""
	@echo "  5. Teardown when done:"
	@echo "     make local-down"
	@echo ""
	@echo "📚 For detailed instructions:"
	@echo "   See SETUP_WINDOWS.md in this directory"
	@echo ""
	@echo "🔧 INSTALLATION OPTIONS:"
	@echo ""
	@echo "   Option A: Chocolatey (recommended for Windows)"
	@echo "     choco install terraform kubernetes-cli kubernetes-helm k3d"
	@echo ""
	@echo "   Option B: WSL2 (most Unix-like experience)"
	@echo "     wsl --install"
	@echo "     Then run this script inside WSL2"
	@echo ""
	@echo "   Option C: Docker Desktop tools"
	@echo "     Includes kubectl, docker-compose out of the box"
	@echo ""
	@echo "❓ ISSUES?"
	@echo "   • Docker not found? Ensure Docker Desktop is RUNNING (check system tray)"
	@echo "   • Port conflicts? Use different ports: kubectl port-forward ... :8888:443"
	@echo "   • WSL2 issues? Run: wsl --update"
	@echo ""

.DEFAULT_GOAL := help
