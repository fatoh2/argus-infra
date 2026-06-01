variable "name" {
  description = "Name of the Hetzner Cloud server."
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type (e.g. cx22)."
  type        = string
  default     = "cx22"
}

variable "image" {
  description = "OS image to boot the server from."
  type        = string
  default     = "ubuntu-24.04"
}

variable "location" {
  description = "Hetzner Cloud location (e.g. nbg1)."
  type        = string
  default     = "nbg1"
}

variable "ssh_keys" {
  description = "List of SSH key names (or fingerprints) to inject into the server."
  type        = list(string)
}

variable "labels" {
  description = "Additional labels to attach to the server. The project=argus label is always enforced."
  type        = map(string)
  default     = {}
}

variable "network_id" {
  description = "ID of a private network to attach the server to. If null, no private network is attached."
  type        = number
  default     = null
}

variable "private_ip" {
  description = "Static private IP to assign within the attached network. If null, Hetzner auto-assigns."
  type        = string
  default     = null
}
