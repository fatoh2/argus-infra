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
  description = "The IP address of the GKE cluster endpoint."
  value       = google_container_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "The base64-encoded CA certificate for the cluster."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
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
  description = "Path to the generated kubeconfig file for this cluster."
  value       = pathexpand("~/.kube/config-${var.cluster_name}")
}

output "kubectl_configure_command" {
  description = "Command to configure kubectl for this cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.this.name} --region ${var.region} --project ${var.project_id}"
}

output "helm_repos_added" {
  description = "List of Helm repository names that were added."
  value       = keys(var.helm_repos)
}
