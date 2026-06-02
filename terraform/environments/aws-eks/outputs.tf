output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = module.argus_eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.argus_eks.cluster_name
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = module.argus_eks.cluster_arn
}

output "cluster_endpoint" {
  description = "The endpoint URL for the EKS cluster API server."
  value       = module.argus_eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the EKS cluster."
  value       = module.argus_eks.cluster_version
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC provider for the EKS cluster."
  value       = module.argus_eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC provider for the EKS cluster."
  value       = module.argus_eks.oidc_provider_url
}

output "node_group_id" {
  description = "The ID of the EKS node group."
  value       = module.argus_eks.node_group_id
}

output "node_group_status" {
  description = "The status of the EKS node group."
  value       = module.argus_eks.node_group_status
}

output "desired_nodes" {
  description = "The desired number of worker nodes."
  value       = module.argus_eks.desired_nodes
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.argus_eks.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets."
  value       = module.argus_eks.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets."
  value       = module.argus_eks.private_subnet_ids
}

output "cluster_security_group_id" {
  description = "The security group ID for the EKS cluster control plane."
  value       = module.argus_eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "The security group ID for the EKS worker nodes."
  value       = module.argus_eks.node_security_group_id
}

output "cluster_iam_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster."
  value       = module.argus_eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "The ARN of the IAM role for the EKS node group."
  value       = module.argus_eks.node_iam_role_arn
}

output "node_iam_role_name" {
  description = "The name of the IAM role for the EKS node group."
  value       = module.argus_eks.node_iam_role_name
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = module.argus_eks.kubeconfig_path
}

output "kubectl_command" {
  description = "Command to verify the cluster is ready."
  value       = module.argus_eks.kubectl_command
}
