output "instance_name" {
  description = "Name of the created VM."
  value       = module.argus_vm.instance_name
}

output "public_ip" {
  description = "Public IP address of the VM."
  value       = module.argus_vm.nat_ip
}

output "private_ip" {
  description = "Private IP address of the VM."
  value       = module.argus_vm.network_ip
}

output "ssh_command" {
  description = "SSH command to connect to the VM."
  value       = module.argus_vm.ssh_command
}

output "zone" {
  description = "Zone where the VM was created."
  value       = module.argus_vm.zone
}
