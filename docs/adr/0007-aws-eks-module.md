# ADR 0007: AWS EKS Module for Managed Kubernetes Deployments

- **Status:** Accepted
- **Date:** 2025-07-17
- **Issue:** [#70](https://github.com/fatoh2/argus-infra/issues/70)

## Context

Argus Infra initially supported three deployment targets:

1. **Hetzner Cloud k3s cluster** — multi-node Kubernetes on Hetzner VMs (the primary target)
2. **GCP Compute Engine single VM** — lightweight single-VM deployment on GCP
3. **GCP GKE cluster** — managed Kubernetes on Google Cloud Platform
4. **AWS EC2 single VM** — lightweight single-VM deployment on AWS

As the project evolved, a need emerged for a managed Kubernetes option on AWS:

- **AWS-native teams** — organizations already on AWS wanted a native Kubernetes experience
  without managing a separate cloud provider
- **Reduced operational overhead** — EKS manages the control plane, node health, and
  upgrades automatically
- **Scalability** — EKS can scale from a small cluster to hundreds of nodes with managed
  node groups and Cluster Autoscaler
- **AWS-native integrations** — seamless integration with IAM, VPC, CloudWatch, and
  IRSA (IAM Roles for Service Accounts)

## Decision

We created a new Terraform module `modules/aws-eks` that provisions an Amazon EKS
cluster on AWS, plus a ready-to-use environment at `environments/aws-eks`.

### Module scope

The module provisions:

- **VPC** — Custom VPC (10.0.0.0/16) with public and private subnets across multiple
  availability zones
- **Internet Gateway** — For public internet access
- **NAT Gateways** — One per AZ (configurable) for private subnet outbound connectivity
- **EKS Cluster** — Managed Kubernetes control plane with configurable version
- **Managed Node Group** — Auto-scaling worker nodes with configurable instance types,
  disk size, and count
- **Security Groups** — Cluster and node security groups with least-privilege rules
- **IAM Roles** — Cluster and node IAM roles with least-privilege policies
- **OIDC Provider** — IAM OIDC identity provider for IRSA
- **kubeconfig** — Generated locally for immediate kubectl access
- **CloudWatch Logging** — Optional control plane log shipping

### Key design decisions

1. **Managed node groups** — Uses EKS managed node groups rather than self-managed
   instances. This offloads node health monitoring, patching, and scaling to AWS,
   reducing operational burden.

2. **Public + private subnet topology** — Worker nodes run in private subnets for
   security. Public subnets host load balancers and NAT Gateways. This follows AWS
   best practices for production EKS clusters.

3. **NAT Gateways by default** — One NAT Gateway per AZ enables private subnet
   outbound connectivity (pulling container images, reaching external APIs).
   Configurable via `enable_nat_gateway` for cost-sensitive deployments.

4. **IRSA support** — The module creates an IAM OIDC provider, enabling IAM Roles
   for Service Accounts (IRSA) for fine-grained pod-level AWS permissions without
   needing to store long-lived credentials in the cluster.

5. **kubeconfig generation** — A kubeconfig file is generated locally at
   `~/.kube/config-argus-cluster` for immediate cluster access after `terraform apply`,
   reducing the number of post-provisioning steps.

6. **Consistency with GKE module** — The AWS EKS module follows the same patterns,
   variable naming conventions, and output structure as the existing GCP GKE module.

### What the module does NOT do

- Does not deploy applications into the cluster (that's ArgoCD's job)
- Does not configure EKS add-ons (VPC CNI, CoreDNS, kube-proxy) beyond defaults
- Does not set up IAM roles for specific workloads (use IRSA via the OIDC provider)
- Does not install monitoring or ingress controllers (those are managed via ArgoCD)
- Does not configure EBS CSI driver or other storage add-ons

## Consequences

### Positive

- AWS-native teams can deploy Argus on EKS without managing a separate cloud provider
- Managed node groups reduce operational overhead for cluster maintenance
- Consistent Terraform workflow across all deployment targets (Hetzner, GCP VM, GKE,
  AWS EC2, EKS)
- IRSA support enables secure pod-level AWS permissions
- Private subnet topology follows AWS security best practices

### Negative

- EKS clusters incur costs even when idle (control plane pricing ~$0.10/hour)
- NAT Gateways add cost (~$0.045/hour per AZ + data processing fees)
- The module does not configure EKS add-ons, requiring manual setup or future
  enhancement
- Documentation complexity — setup guides, runbooks, and architecture docs now cover
  five deployment paths

### Neutral

- Users must have an AWS account with billing enabled
- The `aws` CLI is required for authentication and kubeconfig setup
- Cluster upgrades are managed by EKS (version bumps require terraform apply)

## Alternatives Considered

### EKS with Fargate profiles

Fargate profiles would allow running pods without managing worker nodes. This was
deferred because:

- Fargate has limitations (daemonsets not supported, limited instance types)
- Fargate is more expensive for steady-state workloads
- Managed node groups provide more flexibility for the Argus stack (Prometheus
  daemonsets, Traefik, etc.)

### Self-managed node groups

Self-managed node groups (using Auto Scaling Groups) were considered but rejected
because:

- They require more operational overhead (AMI management, patching)
- Managed node groups provide automatic health replacement
- The operational savings outweigh the slight reduction in control

### k3s on AWS EC2 (multi-node)

Running k3s on multiple EC2 instances was considered but rejected because:

- It duplicates the Hetzner approach without leveraging AWS-managed services
- EKS provides a more native AWS experience with IAM, VPC, and CloudWatch integration
- The existing `aws-single-vm` module already covers single-VM deployments

## References

- [Amazon EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/)
- [EKS managed node groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [Terraform AWS Provider: aws_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)
