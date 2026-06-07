variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "argus-cluster"
}

variable "num_nodes" {
  description = "Number of nodes (Standard mode only; Autopilot ignores this)."
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine type for nodes (Standard mode only; Autopilot ignores this)."
  type        = string
  default     = "e2-standard-4"
}

variable "enable_autopilot" {
  description = "Whether to enable Autopilot mode."
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel (UNSPECIFIED, RAPID, REGULAR, STABLE)."
  type        = string
  default     = "REGULAR"
}

variable "network" {
  description = "VPC network name. Defaults to 'default' if null."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Subnetwork name. Defaults to the region's default if null."
  type        = string
  default     = null
}

variable "enable_private_endpoint" {
  description = "Whether the master's internal IP is used as the cluster endpoint."
  type        = bool
  default     = false
}

variable "enable_private_nodes" {
  description = "Whether nodes have internal IPs only."
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the control plane (must be /28)."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Enable deletion protection on the cluster."
  type        = bool
  default     = false
}

variable "labels" {
  description = "GCP resource labels."
  type        = map(string)
  default = {
    project = "argus"
    managed = "terraform"
  }
}

variable "service_account_email" {
  description = "Email of the service account to attach to nodes."
  type        = string
  default     = null
}
