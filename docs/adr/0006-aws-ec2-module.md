# ADR 0006: AWS EC2 Module for Single-VM Deployments

- **Status:** Accepted
- **Date:** 2025-07-17
- **Issue:** [#70](https://github.com/fatoh2/argus-infra/issues/70)

## Context

Argus Infra supports two deployment models: a multi-node k3s cluster on Hetzner Cloud
and a single-VM deployment on GCP Compute Engine. A third deployment model was
anticipated for teams using AWS as their primary cloud provider.

The need for an AWS EC2 module mirrors the same use cases that drove the GCP module:

- **Lightweight deployments** — running a single Argus component without cluster overhead
- **Testing and development** — quick provisioning of a VM for integration testing
- **Cost-sensitive environments** — a single VM is cheaper than a multi-node cluster
- **AWS-native teams** — teams already using AWS who want to deploy Argus without
  managing a separate Hetzner or GCP account

## Decision

We created a new Terraform module `modules/aws-ec2` that provisions a single EC2
instance on AWS, plus a ready-to-use environment at `environments/aws-single-vm`.

### Module scope

The module provisions:

- **VPC** — Custom VPC with DNS support and hostnames enabled
- **Internet Gateway** — For public internet access
- **Public Subnet** — In a configurable availability zone
- **Route Table** — Default route to the Internet Gateway
- **Security Group** — SSH (22), HTTP (80), HTTPS (443) with configurable source CIDRs
- **EC2 Instance** — Ubuntu 22.04 LTS with configurable instance type and root volume
- **Elastic IP** — Static public IP address (optional, enabled by default)
- **SSH Key Pair** — Injected from a provided public key
- **IAM Role** — Optional IAM role with configurable policy attachments
- **Startup Script** — Installs Docker and Docker Compose on first boot

### What the module does NOT do

- It does **not** install Kubernetes or k3s — this is intentionally a single-VM module
- It does **not** manage DNS records (Route53)
- It does **not** provision additional EBS volumes beyond the root volume
- It does **not** set up monitoring or observability
- It does **not** create a VPC with private subnets or NAT gateways (single public subnet only)

These are left to the user or future enhancements.

## Rationale

1. **Consistency with GCP module** — The AWS module follows the same patterns,
   variable naming conventions, and output structure as the existing GCP module.
2. **Separation of concerns** — The AWS module is independent of the Hetzner and GCP
   infrastructure. Changes to one don't affect the others.
3. **Reusability** — The module can be consumed by any environment configuration,
   not just `aws-single-vm`.
4. **Minimal dependencies** — Only requires the `hashicorp/aws` provider (~> 5.0).
   No Ansible, no k3s, no ArgoCD.
5. **Docker-first** — The startup script installs Docker + Docker Compose, making the
   VM immediately usable for containerized workloads without additional tooling.

## Consequences

### Positive

- Argus Infra now supports three cloud providers (Hetzner, GCP, and AWS)
- AWS-native teams can deploy Argus without managing accounts on other clouds
- The module is self-contained and independently testable
- Consistent interface across cloud providers simplifies multi-cloud deployments

### Negative

- Increased maintenance surface — the AWS provider and module need to be kept up to date
- Documentation complexity — setup guides, runbooks, and architecture docs now cover
  three deployment paths
- No automated CI for the AWS environment (no AWS credentials in CI)

### Mitigations

- The module follows the same patterns as the existing GCP and Hetzner modules
  (consistent variable naming, output structure, tag conventions)
- The `aws-single-vm` environment is validated locally with `terraform validate` and
  `terraform plan` (using `-backend=false` in CI)
- Documentation clearly distinguishes between the three deployment paths

## Alternatives Considered

### ECS (Elastic Container Service)

An ECS module would provide a managed container orchestration service on AWS, more
closely matching the Kubernetes-based Hetzner deployment. This was deferred because:

- ECS adds complexity (task definitions, cluster configuration, IAM)
- The immediate need was for lightweight single-VM deployments
- ECS/Fargate support could be added as a future enhancement

### Elastic Beanstalk

Elastic Beanstalk was considered but rejected because:

- It abstracts too much infrastructure, making it harder to customize
- It doesn't align with the Terraform-first approach used elsewhere in the repo
- It's less portable across cloud providers

### Ansible-based provisioning (no Terraform)

Using Ansible alone to provision the AWS VM was considered but rejected for the same
reasons as in ADR 0004 — Terraform handles state management, drift detection, and
destruction cleanly, while Ansible is better suited for post-provisioning configuration.
