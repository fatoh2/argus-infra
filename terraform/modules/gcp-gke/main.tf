# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  # Default location: use zone if provided, otherwise use region
  location = var.zone != null ? var.zone : var.region

  # Master authorized networks: default to empty if not specified
  master_authorized_networks = var.master_authorized_cidrs != null ? [
    for cidr in var.master_authorized_cidrs : {
      cidr_block   = cidr
      display_name = "allow-${replace(cidr, "/", "-")}"
    }
  ] : []
}

# ---------------------------------------------------------------------------
# GKE Cluster (Regional / Zonal)
# ---------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  name     = var.name
  location = local.location
  project  = var.project_id

  # We're creating a node pool separately, so remove the default one
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Master auth: allow public access with authorized networks
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = local.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # IP allocation policy for VPC-native cluster
  dynamic "ip_allocation_policy" {
    for_each = var.enable_vpc_native ? [1] : []
    content {
      cluster_secondary_range_name  = var.cluster_secondary_range_name
      services_secondary_range_name = var.services_secondary_range_name
    }
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.maintenance_window_start
    }
  }

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = !var.enable_http_load_balancing
    }
    horizontal_pod_autoscaling {
      disabled = !var.enable_horizontal_pod_autoscaling
    }
    network_policy_config {
      disabled = !var.enable_network_policy
    }
  }

  # Network policy
  dynamic "network_policy" {
    for_each = var.enable_network_policy ? [1] : []
    content {
      enabled  = true
      provider = "CALICO"
    }
  }

  # Cluster resource labels
  resource_labels = merge(var.labels, {
    project = "argus"
  })

  # Allow GKE to manage the cluster
  deletion_protection = var.deletion_protection

  # Workload identity
  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # Vertical pod autoscaling
  vertical_pod_autoscaling {
    enabled = var.enable_vpa
  }

  # Cluster tier
  cluster_autoscaling {
    enabled = var.enable_cluster_autoscaling
  }
}

# ---------------------------------------------------------------------------
# Node Pool
# ---------------------------------------------------------------------------
resource "google_container_node_pool" "primary" {
  name     = "${var.name}-primary-pool"
  location = local.location
  project  = var.project_id
  cluster  = google_container_cluster.this.name

  initial_node_count = var.initial_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type
    image_type   = var.image_type

    oauth_scopes = var.oauth_scopes

    labels = merge(var.node_labels, {
      project = "argus"
      pool    = "primary"
    })

    tags = var.node_tags

    # Service account
    service_account = var.node_service_account_email

    # Shielded instance config
    shielded_instance_config {
      enable_secure_boot          = var.enable_secure_boot
      enable_integrity_monitoring = true
    }

    # Workload metadata config
    workload_metadata_config {
      mode = var.enable_workload_identity ? "GKE_METADATA" : "GCE_METADATA"
    }
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }
}

# ---------------------------------------------------------------------------
# Kubeconfig generation (local file)
# ---------------------------------------------------------------------------
resource "local_file" "kubeconfig" {
  count = var.generate_kubeconfig ? 1 : 0

  filename = var.kubeconfig_path != null ? var.kubeconfig_path : pathexpand("~/.kube/${var.name}-config")
  content = templatefile("${path.module}/templates/kubeconfig.tftpl", {
    cluster_name     = google_container_cluster.this.name
    cluster_endpoint = google_container_cluster.this.endpoint
    cluster_ca_cert  = google_container_cluster.this.master_auth[0].cluster_ca_certificate
    location         = local.location
    project_id       = var.project_id
  })

  file_permission = "0600"
}
