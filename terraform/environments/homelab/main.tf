data "hcloud_ssh_key" "this" {
  count = var.ssh_key_id == null ? 1 : 0
  name  = var.ssh_key_name
}

locals {
  # When ssh_key_id is provided (CI), use the name directly.
  # When not provided, look up the key by name and use its name.
  ssh_key_name = var.ssh_key_id != null ? var.ssh_key_name : data.hcloud_ssh_key.this[0].name

  # Private IP assignments within the cluster subnet (10.0.1.0/24).
  workers = {
    "k8s-worker-1" = "10.0.1.11"
    "k8s-worker-2" = "10.0.1.12"
  }
}

module "network" {
  source = "../../modules/hcloud-network"

  name            = "argus-homelab"
  ip_range        = "10.0.0.0/16"
  subnet_ip_range = "10.0.1.0/24"
  network_zone    = "eu-central"
  labels          = { project = "argus" }
}

module "control_plane" {
  source = "../../modules/hcloud-vm"

  name        = "k8s-control"
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [local.ssh_key_name]
  network_id  = module.network.network_id
  private_ip  = "10.0.1.10"
  labels = {
    project = "argus"
    role    = "control-plane"
  }

  depends_on = [module.network]
}

module "workers" {
  source   = "../../modules/hcloud-vm"
  for_each = local.workers

  name        = each.key
  server_type = var.server_type
  image       = var.image
  location    = var.location
  ssh_keys    = [local.ssh_key_name]
  network_id  = module.network.network_id
  private_ip  = each.value
  labels = {
    project = "argus"
    role    = "worker"
  }

  depends_on = [module.network]
}
