variable "name" {
  description = "Name of the private network."
  type        = string
}

variable "ip_range" {
  description = "CIDR range for the whole network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ip_range" {
  description = "CIDR range for the cloud subnet (must be within ip_range)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "network_zone" {
  description = "Hetzner network zone for the subnet (e.g. eu-central)."
  type        = string
  default     = "eu-central"
}

variable "labels" {
  description = "Additional labels to attach to the network. The project=argus label is always enforced."
  type        = map(string)
  default     = {}
}
