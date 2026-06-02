output "cluster_id" {
  description = "The ID of the created GKE cluster."
  value       = module.argus_gke.cluster_id
}

output "cluster_name" {
  description = "The name of the created GKE cluster."
  value       = module.argus_gke.cluster_name
}

output "cluster_endpoint" {
  description = "The IP address of the GKE cluster endpoint."
  value       = module.argus_gke.cluster_endpoint
}

output "kubectl_configure_command" {
  description = "Command to configure kubectl for this cluster."
  value       = module.argus_gke.kubectl_configure_command
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file."
  value       = module.argus_gke.kubeconfig_path
}

output "helm_repos_added" {
  description = "List of Helm repository names that were added."
  value       = module.argus_gke.helm_repos_added
}
