output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = module.argus_vm.instance_id
}

output "instance_name" {
  description = "The name of the created EC2 instance."
  value       = module.argus_vm.instance_name
}

output "instance_type" {
  description = "The instance type of the created EC2 instance."
  value       = module.argus_vm.instance_type
}

output "public_ip" {
  description = "The public IP address (Elastic IP) of the instance."
  value       = module.argus_vm.public_ip
}

output "private_ip" {
  description = "The private IP address of the instance."
  value       = module.argus_vm.private_ip
}

output "vpc_id" {
  description = "The ID of the VPC."
  value       = module.argus_vm.vpc_id
}

output "subnet_id" {
  description = "The ID of the public subnet."
  value       = module.argus_vm.subnet_id
}

output "ssh_command" {
  description = "Ready-to-use SSH command for connecting to the instance."
  value       = module.argus_vm.ssh_command
}

output "ami_id" {
  description = "The AMI ID used for the instance."
  value       = module.argus_vm.ami_id
}

output "iam_role_name" {
  description = "The name of the IAM role."
  value       = module.argus_vm.iam_role_name
}

output "iam_role_arn" {
  description = "The ARN of the IAM role."
  value       = module.argus_vm.iam_role_arn
}

output "instance_public_ip" {
  description = "Alias for public_ip — the public IP address of the instance."
  value       = module.argus_vm.instance_public_ip
}
