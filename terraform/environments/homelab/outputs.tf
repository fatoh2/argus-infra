output "control_plane_ip" {
  description = "Public IPv4 address of the control-plane node."
  value       = module.control_plane.ipv4_address
}

output "worker_ips" {
  description = "Map of worker node name to public IPv4 address."
  value       = { for name, mod in module.workers : name => mod.ipv4_address }
}

output "ssh_commands" {
  description = "Map of node name to ready-to-use SSH command."
  value = merge(
    { (module.control_plane.name) = "ssh root@${module.control_plane.ipv4_address}" },
    { for name, mod in module.workers : name => "ssh root@${mod.ipv4_address}" }
  )
}
