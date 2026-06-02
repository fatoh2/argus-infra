# ADR 0004: GCP Compute Engine Module for Single-VM Deployments

- **Status:** Accepted
- **Date:** 2025-07-17
- **Issue:** [#67](https://github.com/fatoh2/argus-infra/issues/67)

## Context

Argus Infra was originally designed as a Kubernetes homelab platform on Hetzner Cloud,
provisioning a multi-node k3s cluster via Terraform and Ansible. However, several use
cases emerged that didn't warrant a full Kubernetes cluster:

- **Lightweight deployments** — running a single Argus component (e.g., a monitoring agent)
  without the overhead of a cluster
- **Testing and development** — quick provisioning of a VM for integration testing
- **Cost-sensitive environments** — a single VM is cheaper than a multi-node cluster
- **GCP-native teams** — teams already using GCP who want to deploy Argus without
  managing a separate Hetzner account

## Decision

We created a new Terraform module `modules/gcp-compute-engine` that provisions a single
Compute Engine VM on Google Cloud Platform, plus a ready-to-use environment at
`environments/gcp-single-vm`.

### Module scope

The module provisions:

- **Compute Engine VM** — Ubuntu 22.04 LTS with configurable machine type, disk size,
  and disk type
- **Firewall rules** — SSH (22), HTTP (80), HTTPS (443) with configurable source CIDRs
- **External IP** — Optional ephemeral public IP address
- **Startup script** — Installs Docker and Docker Compose on first boot
- **SSH key injection** — Via instance metadata
- **Service account** — Optional attachment with configurable scopes

### What the module does NOT do

- It does **not** install Kubernetes or k3s — this is intentionally a single-VM module
- It does **not** manage DNS records
- It does **not** provision persistent storage beyond the boot disk
- It does **not** set up monitoring or observability

These are left to the user or future modules.

## Rationale

1. **Separation of concerns** — The GCP module is independent of the Hetzner k3s
   infrastructure. Changes to one don't affect the other.
2. **Reusability** — The module can be consumed by any environment configuration,
   not just `gcp-single-vm`.
3. **Minimal dependencies** — Only requires the `hashicorp/google` provider (~> 6.0).
   No Ansible, no k3s, no ArgoCD.
4. **Docker-first** — The startup script installs Docker + Docker Compose, making the
   VM immediately usable for containerized workloads without additional tooling.

## Consequences

### Positive

- Argus Infra now supports two cloud providers (Hetzner and GCP)
- Lower barrier to entry for testing and development
- Teams can choose the deployment model that fits their needs
- The module is self-contained and independently testable

### Negative

- Increased maintenance surface — the GCP provider and module need to be kept up to date
- Documentation complexity — setup guides, runbooks, and architecture docs now cover
  two deployment paths
- No automated CI for the GCP environment (no GCP credentials in CI)

### Mitigations

- The module follows the same patterns as the existing Hetzner modules (consistent
  variable naming, output structure, label conventions)
- The `gcp-single-vm` environment is validated locally with `terraform validate` and
  `terraform plan` (using `-backend=false` in CI)
- Documentation clearly distinguishes between the Hetzner k3s path and the GCP
  single-VM path

## Alternatives Considered

### GKE (Google Kubernetes Engine)

A GKE module would provide a managed Kubernetes cluster on GCP, more closely matching
the Hetzner k3s deployment. This was deferred because:

- GKE adds complexity (node pools, IAM, VPC-native networking)
- The immediate need was for lightweight single-VM deployments
- A GKE module is planned as a future enhancement (see issue #68)

### AWS EC2

An EC2 module was considered but deferred. The GCP module was prioritized because the
immediate use case involved GCP-native teams. An EC2 module is planned as a future
enhancement (see issue #70).

### Ansible-based provisioning (no Terraform)

Using Ansible alone to provision the GCP VM was considered but rejected because:

- Terraform is already the established provisioning tool in this repo
- Terraform handles state management, drift detection, and destruction cleanly
- Ansible would still be needed for post-provisioning configuration, adding complexity
