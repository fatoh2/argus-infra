output "id" {
  description = "ID of the created server."
  value       = hcloud_server.this.id
}

output "name" {
  description = "Name of the created server."
  value       = hcloud_server.this.name
}

output "ipv4_address" {
  description = "Public IPv4 address of the server."
  value       = hcloud_server.this.ipv4_address
}

output "private_ip" {
  description = "Private IP within the attached network, or null if not attached."
  value       = var.network_id != null ? one(hcloud_server.this.network[*].ip) : null
}
