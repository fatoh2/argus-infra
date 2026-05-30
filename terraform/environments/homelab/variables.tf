variable "hcloud_token" {
  description = "Hetzner Cloud API token."
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of an existing SSH key in the Hetzner Cloud project."
  type        = string
}

variable "location" {
  description = "Hetzner Cloud location for all VMs."
  type        = string
  default     = "nbg1"
}

variable "server_type" {
  description = "Hetzner Cloud server type for all VMs."
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image for all VMs."
  type        = string
  default     = "ubuntu-24.04"
}
