# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = aws_eks_cluster.this.id
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The endpoint URL for the EKS cluster API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "The security group ID attached to the EKS cluster control plane."
  value       = aws_security_group.eks_cluster.id
}

# ---------------------------------------------------------------------------
# OIDC
# ---------------------------------------------------------------------------

output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider for the EKS cluster."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC provider for the EKS cluster."
  value       = aws_iam_openid_connect_provider.this.url
}

# ---------------------------------------------------------------------------
# Node Group
# ---------------------------------------------------------------------------

output "node_group_id" {
  description = "The ID of the EKS node group."
  value       = aws_eks_node_group.this.id
}

output "node_group_arn" {
  description = "The ARN of the EKS node group."
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "The status of the EKS node group."
  value       = aws_eks_node_group.this.status
}

output "node_instance_types" {
  description = "The instance types used for the node group."
  value       = aws_eks_node_group.this.instance_types
}

output "desired_nodes" {
  description = "The desired number of worker nodes."
  value       = aws_eks_node_group.this.scaling_config[0].desired_size
}

# ---------------------------------------------------------------------------
# VPC / Networking
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC created for the EKS cluster."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "node_security_group_id" {
  description = "The security group ID attached to the EKS worker nodes."
  value       = aws_security_group.eks_nodes.id
}

# ---------------------------------------------------------------------------
# IAM
# ---------------------------------------------------------------------------

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster."
  value       = aws_iam_role.eks_cluster.arn
}

output "node_iam_role_arn" {
  description = "The ARN of the IAM role for the EKS node group."
  value       = aws_iam_role.eks_nodes.arn
}

output "node_iam_role_name" {
  description = "The name of the IAM role for the EKS node group."
  value       = aws_iam_role.eks_nodes.name
}

# ---------------------------------------------------------------------------
# kubeconfig
# ---------------------------------------------------------------------------

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = var.generate_kubeconfig ? pathexpand(var.kubeconfig_path) : null
}

output "kubectl_command" {
  description = "Command to verify the cluster is ready."
  value       = "kubectl get nodes --kubeconfig=${pathexpand(var.kubeconfig_path)}"
}
