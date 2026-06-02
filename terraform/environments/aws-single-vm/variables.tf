variable "name" {
  description = "Name of the EC2 instance and associated resources."
  type        = string
  default     = "argus-vm"
}

variable "region" {
  description = "AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, production)."
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.xlarge"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "Public SSH key content to inject into the instance."
  type        = string
  sensitive   = true
}

variable "ssh_user" {
  description = "Username for the SSH key."
  type        = string
  default     = "ubuntu"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed for SSH access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "CIDR ranges allowed for HTTP access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "CIDR ranges allowed for HTTPS access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "iam_role_name" {
  description = "Name of the IAM role to create for the EC2 instance. Set to null to skip IAM role creation."
  type        = string
  default     = "argus-ec2-role"
}

variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to the IAM role."
  type        = list(string)
  default     = []
}
