output "instance_id" {
  description = "The ID of the created EC2 instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "The ARN of the created EC2 instance."
  value       = aws_instance.this.arn
}

output "instance_name" {
  description = "The name tag of the created EC2 instance."
  value       = var.name
}

output "instance_type" {
  description = "The instance type of the created EC2 instance."
  value       = aws_instance.this.instance_type
}

output "availability_zone" {
  description = "The availability zone where the instance was launched."
  value       = aws_instance.this.availability_zone
}

output "vpc_id" {
  description = "The ID of the VPC created for the instance."
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "The ID of the public subnet."
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "The ID of the security group (if created)."
  value       = var.create_security_group ? aws_security_group.this[0].id : null
}

output "private_ip" {
  description = "The private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "The public IP address of the instance (Elastic IP if enabled, otherwise ephemeral)."
  value = var.associate_elastic_ip ? aws_eip.this[0].public_ip : (
    var.enable_public_ip ? aws_instance.this.public_ip : null
  )
}

output "elastic_ip" {
  description = "The Elastic IP address associated with the instance (if enabled)."
  value       = var.associate_elastic_ip ? aws_eip.this[0].public_ip : null
}

output "elastic_ip_allocation_id" {
  description = "The allocation ID of the Elastic IP (if enabled)."
  value       = var.associate_elastic_ip ? aws_eip.this[0].id : null
}

output "ssh_command" {
  description = "Ready-to-use SSH command for connecting to the instance."
  value = var.associate_elastic_ip ? (
    "ssh -i <key-path> ${var.ssh_user}@${aws_eip.this[0].public_ip}"
    ) : (
    var.enable_public_ip ? (
      "ssh -i <key-path> ${var.ssh_user}@${aws_instance.this.public_ip}"
      ) : (
      "Instance has no public IP. Use AWS Systems Manager Session Manager or an SSH bastion."
    )
  )
}

output "ami_id" {
  description = "The AMI ID used for the instance."
  value       = data.aws_ami.ubuntu.id
}

output "iam_role_name" {
  description = "The name of the IAM role (if created)."
  value       = var.iam_role_name != null ? aws_iam_role.this[0].name : null
}

output "iam_role_arn" {
  description = "The ARN of the IAM role (if created)."
  value       = var.iam_role_name != null ? aws_iam_role.this[0].arn : null
}

# ---------------------------------------------------------------------------
# Standardized outputs (as requested by argus-infra issue #72)
# ---------------------------------------------------------------------------
output "instance_public_ip" {
  description = "Alias for public_ip — the public IP address of the instance (Elastic IP if enabled, otherwise ephemeral)."
  value = var.associate_elastic_ip ? aws_eip.this[0].public_ip : (
    var.enable_public_ip ? aws_instance.this.public_ip : null
  )
}
