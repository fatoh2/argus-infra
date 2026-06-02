# ADR 0005: GCP GKE Module for Managed Kubernetes Deployments

- **Status:** Accepted
- **Date:** 2025-07-17
- **Issue:** [#68](https://github.com/fatoh2/argus-infra/issues/68)

## Context

Argus Infra initially supported two deployment targets:

1. **Hetzner Cloud k3s cluster** — multi-node Kubernetes on Hetzner VMs (the primary target)
2. **GCP Compute Engine single VM** — lightweight single-VM deployment on GCP

As the project evolved, several needs emerged for a managed Kubernetes option on GCP:

- **Teams already on GCP** — organizations using GCP wanted a native Kubernetes experience
  without managing a separate Hetzner account
- **Reduced operational overhead** — GKE Autopilot manages the control plane, node
  infrastructure, and upgrades automatically
- **Scalability** — GKE can scale from a small cluster to hundreds of nodes without
  re-provisioning
- **GCP-native integrations** — seamless integration with GCP IAM, Cloud Monitoring,
  Cloud Logging, and VPC-native networking

## Decision

We created a new Terraform module `modules/gcp-gke` that provisions a Google Kubernetes
Engine (GKE) cluster on Google Cloud Platform, plus a ready-to-use environment at
`environments/gcp-gke`.

### Module scope

The module provisions:

- **GKE cluster** — with Autopilot mode enabled by default (configurable to Standard mode)
- **kubeconfig** — generated at `~/.kube/config-<cluster-name>` for immediate kubectl access
- **Helm repositories** — pre-configured via local-exec provisioner (argo, traefik,
  prometheus-community, grafana, jetstack, external-secrets)

### Key design decisions

1. **Autopilot by default** — Autopilot mode is enabled by default (`enable_autopilot = true`)
   because it eliminates node management overhead. Standard mode is available for users who
   need fine-grained control over node configuration.

2. **Helm repos via local-exec** — Helm repositories are added using `local-exec`
   provisioners rather than a separate configuration management step. This keeps the
   module self-contained and reduces the number of tools needed after `terraform apply`.

3. **Private cluster support** — The module supports private clusters
   (`enable_private_endpoint`, `enable_private_nodes`) for security-conscious deployments
   where the control plane endpoint should not be publicly accessible.

4. **Release channel selection** — Users can select the GKE release channel
   (`REGULAR`, `RAPID`, `STABLE`) to control how quickly node and control plane
   upgrades are applied.

5. **Deletion protection** — `deletion_protection` is available to prevent accidental
   cluster deletion, which is important for production deployments.

### What the module does NOT do

- Does not deploy applications into the cluster (that's ArgoCD's job)
- Does not configure GCP IAM roles or service accounts beyond the default
- Does not set up VPC peering or multi-cluster networking
- Does not install monitoring or ingress controllers (those are managed via ArgoCD)

## Consequences

### Positive

- GCP-native teams can deploy Argus on GKE without managing a separate cloud provider
- Autopilot mode reduces operational burden for small teams
- Consistent Terraform workflow across all deployment targets (Hetzner, GCP VM, GKE)
- Helm repos are pre-configured, reducing manual setup steps
- Private cluster support enables secure deployments

### Negative

- GKE clusters incur costs even when idle (control plane pricing)
- Autopilot mode limits some node-level configuration options
- The `local-exec` provisioner for Helm repos means `terraform apply` must be run from
  a machine with `helm` installed
- GKE-specific features (e.g., Workload Identity, Config Connector) are not configured
  by default

### Neutral

- Users must have a GCP project with billing enabled
- The `gcloud` CLI is required for authentication (`gcloud auth application-default login`)
- Cluster upgrades are managed by GKE (release channel), not by the module

## Alternatives Considered

1. **Use k3s on GCP Compute Engine VMs** — rejected because it requires managing VMs,
   installing k3s, and handling upgrades manually, negating the benefits of a managed
   Kubernetes service.

2. **Use Google Kubernetes Engine (GKE) Standard mode only** — rejected because Autopilot
   is the recommended mode for most use cases, and Standard mode is available as a
   configuration option.

3. **Use a separate configuration management tool for Helm repos** — rejected because
   keeping Helm repo setup in Terraform via `local-exec` is simpler and keeps the module
   self-contained.

## References

- [GKE Autopilot overview](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [GKE release channels](https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)
- [Terraform Google Provider: google_container_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
