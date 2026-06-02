variable "project_id" {
  description = "GCP project ID where resources will be created."
  type        = string
}

variable "name" {
  description = "Name of the Compute Engine instance and associated resources."
  type        = string
  default     = "argus-vm"
}

variable "region" {
  description = "GCP region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region. If null, defaults to the first zone in the region (e.g. us-central1-a)."
  type        = string
  default     = null
}

variable "machine_type" {
  description = "GCP Compute Engine machine type."
  type        = string
  default     = "e2-standard-4"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB."
  type        = number
  default     = 100
}

variable "boot_disk_type" {
  description = "Boot disk type (pd-standard, pd-ssd, pd-balanced)."
  type        = string
  default     = "pd-standard"
}

variable "boot_disk_image" {
  description = "Boot disk image to use."
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "enable_public_ip" {
  description = "Whether to assign an external ephemeral IP to the VM."
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Public SSH key content to inject into the VM (e.g. 'ssh-rsa AAA...'). If null, OS Login or metadata SSH keys are used."
  type        = string
  default     = null
}

variable "ssh_user" {
  description = "Username for the SSH key. Defaults to the GCP project default or 'argus'."
  type        = string
  default     = "argus"
}

variable "network" {
  description = "Name of the VPC network to use. If null, the 'default' VPC is used."
  type        = string
  default     = null
}

variable "subnetwork" {
  description = "Name of the subnetwork to use. If null, the default subnetwork for the region is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Network tags to apply to the VM (used for firewall rule targeting)."
  type        = list(string)
  default     = ["argus", "argus-vm"]
}

variable "labels" {
  description = "GCP resource labels to apply to all created resources."
  type        = map(string)
  default = {
    project = "argus"
    managed = "terraform"
  }
}

variable "startup_script" {
  description = "Startup script to run on first boot. If null, a default script that installs Docker is used."
  type        = string
  default     = null
}

variable "create_firewall_rules" {
  description = "Whether to create firewall rules for SSH, HTTP, and HTTPS access."
  type        = bool
  default     = true
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

variable "service_account_email" {
  description = "Email of the service account to attach to the VM. If null, the default compute engine service account is used."
  type        = string
  default     = null
}

variable "scopes" {
  description = "Access scopes for the service account."
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}
