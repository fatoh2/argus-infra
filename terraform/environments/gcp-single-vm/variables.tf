variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone (optional, defaults to <region>-a)."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-standard-4"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB."
  type        = number
  default     = 100
}

variable "ssh_public_key" {
  description = "Public SSH key content to inject into the VM."
  type        = string
  sensitive   = false
}

variable "ssh_user" {
  description = "SSH username."
  type        = string
  default     = "argus"
}
