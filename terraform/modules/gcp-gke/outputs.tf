output "cluster_id" {
  description = "The ID of the created GKE cluster."
  value       = google_container_cluster.this.id
}

output "cluster_name" {
  description = "The name of the created GKE cluster."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "The location (region or zone) of the GKE cluster."
  value       = google_container_cluster.this.location
}

output "cluster_endpoint" {
  description = "The IP address (or DNS name) of the cluster's Kubernetes endpoint."
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "The base64-encoded CA certificate for the cluster."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_kubernetes_version" {
  description = "The Kubernetes version running on the cluster."
  value       = google_container_cluster.this.master_version
}

output "cluster_autopilot_enabled" {
  description = "Whether Autopilot mode is enabled on the cluster."
  value       = google_container_cluster.this.enable_autopilot
}

output "cluster_release_channel" {
  description = "The release channel of the cluster."
  value       = google_container_cluster.this.release_channel[0].channel
}

output "kubeconfig_path" {
  description = "Path to the generated kubeconfig file (if generate_kubeconfig is enabled)."
  value       = var.generate_kubeconfig ? try(local_file.kubeconfig[0].filename, null) : null
}

output "kubeconfig_generated" {
  description = "Whether a kubeconfig file was generated."
  value       = var.generate_kubeconfig
}

output "kubectl_configure_command" {
  description = "Command to configure kubectl for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${var.region} --project ${var.project_id}"
}

output "network" {
  description = "The VPC network used by the cluster."
  value       = google_container_cluster.this.network
}

output "subnetwork" {
  description = "The subnetwork used by the cluster."
  value       = google_container_cluster.this.subnetwork
}

output "cluster_self_link" {
  description = "The self-link (URI) of the GKE cluster."
  value       = google_container_cluster.this.self_link
}

# Standard-mode only outputs (null when Autopilot is enabled)
output "node_pool_name" {
  description = "The name of the primary node pool (Standard mode only)."
  value       = var.enable_autopilot ? null : try(google_container_node_pool.primary[0].name, null)
}

output "node_pool_node_count" {
  description = "The current node count of the primary node pool (Standard mode only)."
  value       = var.enable_autopilot ? null : try(google_container_node_pool.primary[0].node_count, null)
}
