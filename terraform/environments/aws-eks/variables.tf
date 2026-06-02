# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "argus-cluster"
}

variable "region" {
  description = "AWS region to deploy the EKS cluster in."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, production)."
  type        = string
  default     = "production"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.31"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to deploy subnets in."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private subnets."
  type        = bool
  default     = true
}

variable "endpoint_private_access" {
  description = "Whether the EKS cluster API server endpoint is accessible from within the VPC."
  type        = bool
  default     = false
}

variable "endpoint_public_access" {
  description = "Whether the EKS cluster API server endpoint is accessible from the internet."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks that can access the EKS cluster API server endpoint publicly."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Node Group
# ---------------------------------------------------------------------------

variable "num_nodes" {
  description = "Desired number of worker nodes in the node group."
  type        = number
  default     = 3
}

variable "min_nodes" {
  description = "Minimum number of worker nodes (for autoscaling)."
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of worker nodes (for autoscaling)."
  type        = number
  default     = 10
}

variable "node_instance_types" {
  description = "List of EC2 instance types for the node group."
  type        = list(string)
  default     = ["t3.xlarge"]
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes."
  type        = number
  default     = 100
}

variable "node_ssh_key_name" {
  description = "Name of an existing EC2 key pair to enable SSH access to worker nodes."
  type        = string
  default     = null
}

variable "enable_node_ssh" {
  description = "Whether to allow SSH access to worker nodes."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidrs" {
  description = "CIDR ranges allowed for SSH access to worker nodes."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

variable "enabled_cluster_log_types" {
  description = "List of EKS control plane log types to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

# ---------------------------------------------------------------------------
# kubeconfig
# ---------------------------------------------------------------------------

variable "generate_kubeconfig" {
  description = "Whether to generate a kubeconfig file locally."
  type        = bool
  default     = true
}

variable "kubeconfig_path" {
  description = "Path where the kubeconfig file will be written."
  type        = string
  default     = "~/.kube/config-argus-cluster"
}
