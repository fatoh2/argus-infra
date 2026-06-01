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
  merged_labels = merge(var.labels, { project = "argus" })
}

resource "hcloud_network" "this" {
  name     = var.name
  ip_range = var.ip_range
  labels   = local.merged_labels
}

resource "hcloud_network_subnet" "this" {
  network_id   = hcloud_network.this.id
  type         = "cloud"
  network_zone = var.network_zone
  ip_range     = var.subnet_ip_range
}
