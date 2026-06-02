output "instance_id" {
  description = "The ID of the created Compute Engine instance."
  value       = google_compute_instance.this.id
}

output "instance_name" {
  description = "The name of the created Compute Engine instance."
  value       = google_compute_instance.this.name
}

output "instance_self_link" {
  description = "The self-link (URI) of the created Compute Engine instance."
  value       = google_compute_instance.this.self_link
}

output "zone" {
  description = "The GCP zone where the instance was created."
  value       = google_compute_instance.this.zone
}

output "machine_type" {
  description = "The machine type of the created instance."
  value       = google_compute_instance.this.machine_type
}

output "network_interface" {
  description = "The network interface details of the instance."
  value       = google_compute_instance.this.network_interface
}

output "network_ip" {
  description = "The internal (private) IP address of the instance."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "nat_ip" {
  description = "The external (public) IP address of the instance, if enabled."
  value = var.enable_public_ip ? try(
    google_compute_instance.this.network_interface[0].access_config[0].nat_ip,
    null
  ) : null
}

output "nat_ips" {
  description = "List of external IPs assigned to the instance."
  value = var.enable_public_ip ? [
    for nic in google_compute_instance.this.network_interface :
    try(nic.access_config[0].nat_ip, null)
  ] : []
}

output "ssh_command" {
  description = "Ready-to-use SSH command for connecting to the instance."
  value       = var.enable_public_ip ? "ssh ${var.ssh_user}@${try(google_compute_instance.this.network_interface[0].access_config[0].nat_ip, "unknown")}" : "Instance has no public IP. Use gcloud compute ssh ${var.name} --zone=${local.zone} --project=${var.project_id}"
}

output "firewall_rule_names" {
  description = "List of firewall rule names created for this instance."
  value = var.create_firewall_rules ? [
    local.fw_ssh,
    local.fw_http,
    local.fw_https,
  ] : []
}
