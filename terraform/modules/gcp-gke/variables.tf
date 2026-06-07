# ---------------------------------------------------------------------------
# Required variables
# ---------------------------------------------------------------------------
variable "project_id" {
  description = "GCP project ID where the GKE cluster will be created."
  type        = string
}

variable "name" {
  description = "Name of the GKE cluster."
  type        = string
}

# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------
variable "region" {
  description = "GCP region for the cluster (used if zone is not specified)."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for a zonal cluster. If null, a regional cluster is created."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Cluster mode
# ---------------------------------------------------------------------------
variable "enable_autopilot" {
  description = "Whether to enable Autopilot mode. When true, node pool and many Standard-mode settings are ignored."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "network" {
  description = "VPC network name to use for the cluster."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork name to use for the cluster."
  type        = string
  default     = null
}

variable "enable_vpc_native" {
  description = "Whether to enable VPC-native (alias IP) mode."
  type        = bool
  default     = true
}

variable "cluster_secondary_range_name" {
  description = "Name of the secondary range for pod IPs (VPC-native mode)."
  type        = string
  default     = null
}

variable "services_secondary_range_name" {
  description = "Name of the secondary range for service IPs (VPC-native mode)."
  type        = string
  default     = null
}

variable "enable_private_nodes" {
  description = "Whether to enable private nodes (no public IP on nodes)."
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Whether the master endpoint is private (no public endpoint)."
  type        = bool
  default     = false
}

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the master (control plane) VPC."
  type        = string
  default     = "172.16.0.0/28"
}

variable "master_authorized_cidrs" {
  description = "List of CIDR blocks allowed to access the cluster master endpoint."
  type        = list(string)
  default     = null
}

# ---------------------------------------------------------------------------
# Node pool configuration (Standard mode only)
# ---------------------------------------------------------------------------
variable "machine_type" {
  description = "Machine type for the node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Disk size in GB for node pool instances."
  type        = number
  default     = 100
}

variable "disk_type" {
  description = "Disk type for node pool instances (pd-standard, pd-ssd, pd-balanced)."
  type        = string
  default     = "pd-standard"
}

variable "image_type" {
  description = "Image type for node pool instances."
  type        = string
  default     = "COS_CONTAINERD"
}

variable "initial_node_count" {
  description = "Initial number of nodes in the node pool."
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling."
  type        = number
  default     = 5
}

variable "oauth_scopes" {
  description = "OAuth scopes for the node service account."
  type        = list(string)
  default = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring.write",
  ]
}

variable "node_service_account_email" {
  description = "Service account email for the node pool. If null, the default compute service account is used."
  type        = string
  default     = null
}

variable "node_oauth_scopes" {
  description = "OAuth scopes for the node service account (used when node_service_account_email is set)."
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "node_labels" {
  description = "Labels to apply to node pool instances."
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "Network tags to apply to node pool instances."
  type        = list(string)
  default     = ["argus", "gke-node"]
}

# ---------------------------------------------------------------------------
# Cluster features
# ---------------------------------------------------------------------------
variable "release_channel" {
  description = "GKE release channel (UNSPECIFIED, RAPID, REGULAR, STABLE)."
  type        = string
  default     = "REGULAR"
}

variable "enable_http_load_balancing" {
  description = "Whether to enable the HTTP load balancing addon."
  type        = bool
  default     = true
}

variable "enable_horizontal_pod_autoscaling" {
  description = "Whether to enable the horizontal pod autoscaling addon."
  type        = bool
  default     = true
}

variable "enable_network_policy" {
  description = "Whether to enable network policy enforcement."
  type        = bool
  default     = false
}

variable "enable_workload_identity" {
  description = "Whether to enable Workload Identity."
  type        = bool
  default     = true
}

variable "enable_vpa" {
  description = "Whether to enable vertical pod autoscaling."
  type        = bool
  default     = false
}

variable "enable_cluster_autoscaling" {
  description = "Whether to enable cluster autoscaling."
  type        = bool
  default     = false
}

variable "enable_secure_boot" {
  description = "Whether to enable Shielded VM secure boot on nodes."
  type        = bool
  default     = false
}

variable "maintenance_window_start" {
  description = "Start time for the daily maintenance window (HH:MM format)."
  type        = string
  default     = "03:00"
}

# ---------------------------------------------------------------------------
# Labels
# ---------------------------------------------------------------------------
variable "labels" {
  description = "Additional labels to apply to all resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Deletion protection
# ---------------------------------------------------------------------------
variable "deletion_protection" {
  description = "Whether to enable deletion protection on the cluster."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Kubeconfig
# ---------------------------------------------------------------------------
variable "generate_kubeconfig" {
  description = "Whether to generate a kubeconfig file locally."
  type        = bool
  default     = false
}

variable "kubeconfig_path" {
  description = "Path to write the generated kubeconfig file. If null, defaults to ~/.kube/config-<cluster_name>."
  type        = string
  default     = null
}
