module "argus_gke" {
  source = "../../modules/gcp-gke"

  project_id = var.project_id
  region     = var.region

  cluster_name       = var.cluster_name
  num_nodes          = var.num_nodes
  node_machine_type  = var.node_machine_type
  enable_autopilot   = var.enable_autopilot
  release_channel    = var.release_channel

  network    = var.network
  subnetwork = var.subnetwork

  enable_private_endpoint = var.enable_private_endpoint
  enable_private_nodes    = var.enable_private_nodes
  master_ipv4_cidr_block  = var.master_ipv4_cidr_block

  deletion_protection = var.deletion_protection

  labels = var.labels

  service_account_email = var.service_account_email
}
