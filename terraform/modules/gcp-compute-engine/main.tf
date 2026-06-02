terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  # Resolve zone: default to <region>-a if not specified
  zone = var.zone != null ? var.zone : "${var.region}-a"

  # Default startup script installs Docker on Ubuntu
  startup_script = var.startup_script != null ? var.startup_script : templatefile(
    "${path.module}/scripts/install-docker.sh.tftpl",
    {}
  )

  # Firewall rule names derived from the VM name to avoid collisions
  fw_ssh   = "${var.name}-allow-ssh"
  fw_http  = "${var.name}-allow-http"
  fw_https = "${var.name}-allow-https"

  # Network name: default VPC if not specified
  network_name = var.network != null ? var.network : "default"

  # SSH key metadata entry (only if ssh_public_key is provided)
  ssh_key_metadata = var.ssh_public_key != null ? {
    "ssh-keys" = "${var.ssh_user}:${var.ssh_public_key}"
  } : {}
}

# ---------------------------------------------------------------------------
# Compute Engine VM
# ---------------------------------------------------------------------------
resource "google_compute_instance" "this" {
  name         = var.name
  machine_type = var.machine_type
  zone         = local.zone
  project      = var.project_id

  tags   = var.tags
  labels = merge(var.labels, {
    project = "argus"
  })

  # Boot disk
  boot_disk {
    auto_delete = true
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  # Network interface
  network_interface {
    network    = local.network_name
    subnetwork = var.subnetwork

    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        # Ephemeral external IP
      }
    }
  }

  # Metadata: SSH key (merged with any additional metadata)
  metadata = merge(
    local.ssh_key_metadata,
    {
      startup-script = local.startup_script
    }
  )

  # Service account
  dynamic "service_account" {
    for_each = var.service_account_email != null ? [1] : []
    content {
      email  = var.service_account_email
      scopes = var.scopes
    }
  }

  # Allow stopping for updates
  allow_stopping_for_update = true
}

# ---------------------------------------------------------------------------
# Firewall Rules
# ---------------------------------------------------------------------------
resource "google_compute_firewall" "ssh" {
  count   = var.create_firewall_rules ? 1 : 0
  name    = local.fw_ssh
  network = local.network_name
  project = var.project_id

  description = "Allow SSH access to Argus VM (${var.name})"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidrs
  target_tags   = var.tags
}

resource "google_compute_firewall" "http" {
  count   = var.create_firewall_rules ? 1 : 0
  name    = local.fw_http
  network = local.network_name
  project = var.project_id

  description = "Allow HTTP access to Argus VM (${var.name})"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = var.tags
}

resource "google_compute_firewall" "https" {
  count   = var.create_firewall_rules ? 1 : 0
  name    = local.fw_https
  network = local.network_name
  project = var.project_id

  description = "Allow HTTPS access to Argus VM (${var.name})"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_https_cidrs
  target_tags   = var.tags
}
