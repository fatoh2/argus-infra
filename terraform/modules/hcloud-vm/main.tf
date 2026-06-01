terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

locals {
  # Base project label is applied last so callers cannot override it.
  merged_labels = merge(var.labels, { project = "argus" })
}

resource "hcloud_server" "this" {
  name        = var.name
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = var.ssh_keys
  labels      = local.merged_labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  dynamic "network" {
    for_each = var.network_id != null ? [var.network_id] : []
    content {
      network_id = network.value
      ip         = var.private_ip
    }
  }
}
