# =============================================================================
# argus-infra — Makefile
#
# Common infra operations for the Argus Platform.
# See docs/setup.md for prerequisites and docs/runbooks.md for procedures.
#
# Usage:
#   make lint           # Terraform fmt + ansible-lint + shellcheck
#   make validate       # Terraform init (no backend) + validate
#   make plan           # Terraform plan (requires HCLOUD_TOKEN)
#   make install-tools  # Install CLI tools (Terraform, Ansible, kubectl, etc.)
#   make local-up       # Spin up local k3d cluster
#   make local-down     # Tear down local k3d cluster
#   make check-versions # Print installed tool versions
#   make sanity         # Run full local sanity check suite
# =============================================================================

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# --- Paths -------------------------------------------------------------------
TERRAFORM_DIR    := terraform/environments/homelab
ANSIBLE_DIR      := ansible
SCRIPTS_DIR      := scripts
ANSIBLE_CONFIG   := $(ANSIBLE_DIR)/ansible.cfg

# --- Colors ------------------------------------------------------------------
BLUE  := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED   := \033[31m
RESET := \033[0m

.PHONY: help lint validate plan install-tools local-up local-down check-versions sanity

help:
	@echo -e "$(BLUE)argus-infra — Makefile$(RESET)"
	@echo ""
	@echo -e "  $(GREEN)make lint$(RESET)           Terraform fmt -check + ansible-lint + shellcheck"
	@echo -e "  $(GREEN)make validate$(RESET)       Terraform init (no backend) + validate"
	@echo -e "  $(GREEN)make plan$(RESET)           Terraform plan (requires HCLOUD_TOKEN env var)"
	@echo -e "  $(GREEN)make install-tools$(RESET)  Install CLI tools (Terraform, Ansible, kubectl, etc.)"
	@echo -e "  $(GREEN)make local-up$(RESET)       Spin up local k3d cluster for testing"
	@echo -e "  $(GREEN)make local-down$(RESET)     Tear down local k3d cluster"
	@echo -e "  $(GREEN)make check-versions$(RESET) Print installed tool versions"
	@echo -e "  $(GREEN)make sanity$(RESET)         Run full local sanity check suite"
	@echo ""

# === Lint ====================================================================
# Runs: terraform fmt -check, ansible-lint, shellcheck on scripts/
lint: lint-terraform lint-ansible lint-shellcheck
	@echo -e "$(GREEN)✔ All lint checks passed$(RESET)"

lint-terraform:
	@echo -e "$(BLUE)── Terraform format check ──$(RESET)"
	@if command -v terraform &>/dev/null; then \
		cd $(TERRAFORM_DIR) && terraform fmt -check -recursive; \
		echo -e "$(GREEN)  ✔ Terraform formatting OK$(RESET)"; \
	else \
		echo -e "$(YELLOW)  ⚠ terraform not found — skipping$(RESET)"; \
	fi

lint-ansible:
	@echo -e "$(BLUE)── Ansible lint ──$(RESET)"
	@if command -v ansible-lint &>/dev/null; then \
		ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-lint $(ANSIBLE_DIR)/playbooks/ $(ANSIBLE_DIR)/roles/; \
		echo -e "$(GREEN)  ✔ Ansible lint OK$(RESET)"; \
	else \
		echo -e "$(YELLOW)  ⚠ ansible-lint not found — skipping$(RESET)"; \
	fi

lint-shellcheck:
	@echo -e "$(BLUE)── ShellCheck ──$(RESET)"
	@if command -v shellcheck &>/dev/null; then \
		shellcheck $(SCRIPTS_DIR)/*.sh; \
		echo -e "$(GREEN)  ✔ ShellCheck OK$(RESET)"; \
	else \
		echo -e "$(YELLOW)  ⚠ shellcheck not found — skipping$(RESET)"; \
	fi

# === Validate ================================================================
# Terraform init (no backend) + validate — no cloud credentials needed.
validate:
	@echo -e "$(BLUE)── Terraform validate ──$(RESET)"
	@if command -v terraform &>/dev/null; then \
		cd $(TERRAFORM_DIR) && terraform init -backend=false -input=false && terraform validate; \
		echo -e "$(GREEN)  ✔ Terraform validation OK$(RESET)"; \
	else \
		echo -e "$(YELLOW)  ⚠ terraform not found — skipping$(RESET)"; \
	fi

# === Plan ====================================================================
# Requires HCLOUD_TOKEN env var. Runs terraform plan targeting module.network
# to avoid provider crashes with computed values (see CI workflow notes).
plan:
	@echo -e "$(BLUE)── Terraform plan ──$(RESET)"
	@if command -v terraform &>/dev/null; then \
		if [ -z "$${HCLOUD_TOKEN:-}" ]; then \
			echo -e "$(RED)✖ HCLOUD_TOKEN is not set$(RESET)"; \
			echo "  Set it with: export HCLOUD_TOKEN=your_token"; \
			exit 1; \
		fi; \
		cd $(TERRAFORM_DIR) && \
		terraform init -input=false && \
		terraform plan -no-color -input=false -target=module.network; \
		echo -e "$(GREEN)  ✔ Terraform plan completed$(RESET)"; \
	else \
		echo -e "$(YELLOW)  ⚠ terraform not found — skipping$(RESET)"; \
	fi

# === Script wrappers =========================================================
# These targets delegate to scripts/ for their implementation.
# If a script doesn't exist yet, print a helpful message.

install-tools:
	@if [ -f "$(SCRIPTS_DIR)/install-tools.sh" ]; then \
		bash $(SCRIPTS_DIR)/install-tools.sh; \
	else \
		echo -e "$(YELLOW)⚠ $(SCRIPTS_DIR)/install-tools.sh not found$(RESET)"; \
		echo "  See docs/setup.md for manual installation instructions."; \
	fi

local-up:
	@if [ -f "$(SCRIPTS_DIR)/local-cluster.sh" ]; then \
		bash $(SCRIPTS_DIR)/local-cluster.sh; \
	else \
		echo -e "$(YELLOW)⚠ $(SCRIPTS_DIR)/local-cluster.sh not found$(RESET)"; \
		echo "  This script will be added in a future PR."; \
	fi

local-down:
	@if [ -f "$(SCRIPTS_DIR)/local-cluster-down.sh" ]; then \
		bash $(SCRIPTS_DIR)/local-cluster-down.sh; \
	else \
		echo -e "$(YELLOW)⚠ $(SCRIPTS_DIR)/local-cluster-down.sh not found$(RESET)"; \
		echo "  This script will be added in a future PR."; \
	fi

check-versions:
	@if [ -f "$(SCRIPTS_DIR)/versions.sh" ]; then \
		bash $(SCRIPTS_DIR)/versions.sh; \
	else \
		echo -e "$(YELLOW)⚠ $(SCRIPTS_DIR)/versions.sh not found$(RESET)"; \
		echo "  This script will be added in a future PR."; \
		echo ""; \
		echo "Installed tools:"; \
		for tool in terraform ansible ansible-lint kubectl helm argocd k3d shellcheck; do \
			if command -v $$tool &>/dev/null; then \
				echo "  ✔ $$tool: $$($$tool version 2>&1 | head -1)"; \
			else \
				echo "  ✖ $$tool: not installed"; \
			fi; \
		done; \
	fi

# === Sanity ==================================================================
# Run the full local sanity check suite (same checks as CI).
sanity:
	@if [ -f "$(SCRIPTS_DIR)/run-sanity-checks.sh" ]; then \
		bash $(SCRIPTS_DIR)/run-sanity-checks.sh; \
	else \
		echo -e "$(YELLOW)⚠ $(SCRIPTS_DIR)/run-sanity-checks.sh not found$(RESET)"; \
		echo "  Falling back to individual make targets..."; \
		$(MAKE) lint validate; \
	fi
