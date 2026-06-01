# ADR 0001: Hetzner Cloud VM provisioning with Terraform

- Status: Accepted
- Date: 2025-05-30
- Issue: #1

## Context
The Argus homelab Kubernetes cluster needs reproducible, version-controlled
infrastructure. We provision Hetzner Cloud VMs (1 control-plane, 2 workers) on a
private network so kubeadm can use stable internal addresses.

## Decision
- Use Terraform with the `hetznercloud/hcloud` provider, pinned to `~> 1.49`.
- Two reusable modules:
  - `modules/hcloud-vm` — a single server, optionally attached to a private network.
  - `modules/hcloud-network` — a private network plus a `cloud` subnet.
- Environment composition lives in `environments/homelab/`, which instantiates the
  network once and the VM module three times (control-plane + 2 workers via `for_each`).
- All resources carry a `project = "argus"` label (enforced in modules; callers cannot override).
- SSH access uses an **existing** Hetzner key referenced by name (`var.ssh_key_name`)
  via a `data "hcloud_ssh_key"` lookup — Terraform does not manage key material.
- Private addressing: network `10.0.0.0/16`, subnet `10.0.1.0/24`,
  control `10.0.1.10`, workers `10.0.1.11` / `10.0.1.12`.

## Consequences
- State is local for now (no remote backend yet); operators must not commit `*.tfstate`.
- `terraform apply` is intentionally NOT run by automation; humans apply after review.
- Server-to-subnet ordering is guaranteed two ways: VM modules `depends_on` the network
  module, and the network module exposes `network_id` from the subnet resource so any
  attachment implicitly waits for the subnet.

## Alternatives considered
- `count` for workers — rejected in favour of `for_each` over a name→IP map for stable addressing.
- Managing the SSH key in Terraform — rejected to avoid key material in state.
