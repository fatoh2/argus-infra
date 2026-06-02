terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  network_name = var.network != null ? var.network : "default"
}

# ---------------------------------------------------------------------------
# GKE Cluster (Autopilot by default)
# ---------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Autopilot mode
  enable_autopilot = var.enable_autopilot

  # Network configuration
  network    = local.network_name
  subnetwork = var.subnetwork

  # Release channel
  release_channel {
    channel = var.release_channel
  }

  # Private cluster configuration
  dynamic "private_cluster_config" {
    for_each = var.enable_private_nodes || var.enable_private_endpoint ? [1] : []
    content {
      enable_private_endpoint = var.enable_private_endpoint
      enable_private_nodes    = var.enable_private_nodes
      master_ipv4_cidr_block  = var.master_ipv4_cidr_block
    }
  }

  # Deletion protection
  deletion_protection = var.deletion_protection

  # Labels
  labels = merge(var.labels, {
    cluster_name = var.cluster_name
  })

  # Node pool configuration for Standard mode (ignored by Autopilot)
  dynamic "node_pool" {
    for_each = var.enable_autopilot ? [] : [1]
    content {
      name = "default-node-pool"

      initial_node_count = var.num_nodes

      node_config {
        machine_type = var.node_machine_type
        disk_size_gb = 100
        disk_type    = "pd-standard"

        labels = {
          project = "argus"
        }

        service_account = var.service_account_email != null ? var.service_account_email : null

        oauth_scopes = [
          "https://www.googleapis.com/auth/cloud-platform",
        ]
      }

      management {
        auto_repair  = true
        auto_upgrade = true
      }
    }
  }
}

# ---------------------------------------------------------------------------
# kubeconfig (for kubectl usage)
# ---------------------------------------------------------------------------
resource "local_file" "kubeconfig" {
  content = templatefile("${path.module}/templates/kubeconfig.tftpl", {
    cluster_name     = google_container_cluster.this.name
    cluster_endpoint = google_container_cluster.this.endpoint
    cluster_ca       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
    project_id       = var.project_id
    region           = var.region
  })
  filename = pathexpand("~/.kube/config-${var.cluster_name}")

  file_permission = "0600"
}

# ---------------------------------------------------------------------------
# Helm Repository Setup (via local-exec after cluster is ready)
# ---------------------------------------------------------------------------
resource "null_resource" "helm_repos" {
  depends_on = [google_container_cluster.this]

  # Trigger re-run if cluster endpoint changes or helm_repos changes
  triggers = {
    cluster_endpoint = google_container_cluster.this.endpoint
    helm_repos_hash  = md5(jsonencode(var.helm_repos))
  }

  # Configure kubectl first, then add Helm repos
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Configuring kubectl for ${var.cluster_name} ==="
      gcloud container clusters get-credentials ${var.cluster_name} \
        --region ${var.region} \
        --project ${var.project_id} 2>/dev/null || \
        echo "WARNING: gcloud not available. Use the kubeconfig at ~/.kube/config-${var.cluster_name}"

      echo "=== Adding Helm repositories ==="
      ${indent(6, join("\n", [for name, url in var.helm_repos : "helm repo add ${name} ${url} 2>/dev/null || echo 'Repo ${name} already exists'"]))}

      helm repo update 2>/dev/null || true
      echo "=== Helm repositories configured ==="
    EOT
  }
}
