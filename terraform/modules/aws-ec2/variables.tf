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

variable "root_volume_type" {
  description = "Root EBS volume type (gp3, gp2, io1, etc.)."
  type        = string
  default     = "gp3"
}

variable "ami_owner" {
  description = "Owner of the AMI to use. '099720109477' is Canonical (Ubuntu)."
  type        = string
  default     = "099720109477"
}

variable "ami_name_filter" {
  description = "Name filter for the AMI to use."
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-22.04-*-server-*"
}

variable "ssh_public_key" {
  description = "Public SSH key content to inject into the instance (e.g. 'ssh-rsa AAA...'). If null, no key is injected."
  type        = string
  default     = null
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

variable "availability_zone" {
  description = "Availability zone for the subnet and instance. If null, uses the first AZ in the region."
  type        = string
  default     = null
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP (Elastic IP) to the instance."
  type        = bool
  default     = true
}

variable "create_security_group" {
  description = "Whether to create a security group for SSH, HTTP, and HTTPS access."
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed for SSH access (port 22)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "CIDR ranges allowed for HTTP access (port 80)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "CIDR ranges allowed for HTTPS access (port 443)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to all created resources."
  type        = map(string)
  default = {
    project = "argus"
    managed = "terraform"
  }
}

variable "iam_role_name" {
  description = "Name of the IAM role to create for the EC2 instance. If null, no IAM role is created."
  type        = string
  default     = null
}

variable "iam_policy_arns" {
  description = "List of IAM policy ARNs to attach to the IAM role."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "User data script to run on first boot. If null, a default script that installs Docker is used."
  type        = string
  default     = null
}

variable "associate_elastic_ip" {
  description = "Whether to associate an Elastic IP (static public IP) to the instance."
  type        = bool
  default     = true
}
