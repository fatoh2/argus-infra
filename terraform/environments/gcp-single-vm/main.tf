module "argus_vm" {
  source = "../../modules/gcp-compute-engine"

  project_id      = var.project_id
  name            = "argus-vm"
  region          = var.region
  zone            = var.zone
  machine_type    = var.machine_type
  boot_disk_size  = var.boot_disk_size
  enable_public_ip = true

  ssh_public_key = var.ssh_public_key
  ssh_user       = var.ssh_user

  tags = ["argus", "argus-vm", "http-server", "https-server"]

  labels = {
    project = "argus"
    env     = "production"
  }

  create_firewall_rules = true
}
