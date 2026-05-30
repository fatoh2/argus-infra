output "network_id" {
  description = "ID of the created private network. Sourced from the subnet so consumers that attach servers implicitly wait for the subnet to exist."
  value       = hcloud_network_subnet.this.network_id
}

output "network_name" {
  description = "Name of the created private network."
  value       = hcloud_network.this.name
}

output "subnet_ip_range" {
  description = "CIDR range of the created subnet."
  value       = hcloud_network_subnet.this.ip_range
}
