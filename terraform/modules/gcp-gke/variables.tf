variable "project_id" {
  description = "GCP project ID where the GKE cluster will be created."
  type        = string
}

variable "region" {
  description = "GCP region to deploy the GKE cluster in."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "argus-cluster"
}

variable "num_nodes" {
  description = "Number of nodes in the default node pool (only used for Standard mode; Autopilot manages this automatically)."
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine type for nodes (only used for Standard mode; Autopilot selects machine types automatically)."
  type        = string
  default     = "e2-standard-4"
}

variable "enable_autopilot" {
  description = "Whether to enable Autopilot mode. When true, num_nodes and node_machine_type are ignored."
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel (UNSPECIFIED, RAPID, REGULAR, STABLE)."
  type        = string
  default     = "REGULAR"
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

variable "master_ipv4_cidr_block" {
  description = "CIDR block for the GKE control plane (must be /28). Only used for private clusters."
  type        = string
  default     = null
}

variable "enable_private_endpoint" {
  description = "Whether the master's internal IP address is used as the cluster endpoint."
  type        = bool
  default     = false
}

variable "enable_private_nodes" {
  description = "Whether nodes have internal IP addresses only."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection on the cluster."
  type        = bool
  default     = false
}

variable "labels" {
  description = "GCP resource labels to apply to the cluster."
  type        = map(string)
  default = {
    project = "argus"
    managed = "terraform"
  }
}

variable "helm_repos" {
  description = "Map of Helm repository names to URLs to add after cluster creation."
  type        = map(string)
  default = {
    "argo"                = "https://argoproj.github.io/argo-helm"
    "traefik"             = "https://traefik.github.io/charts"
    "prometheus-community" = "https://prometheus-community.github.io/helm-charts"
    "grafana"             = "https://grafana.github.io/helm-charts"
    "jetstack"            = "https://charts.jetstack.io"
    "external-secrets"    = "https://charts.external-secrets.io"
  }
}

variable "service_account_email" {
  description = "Email of the service account to attach to nodes. If null, the default compute engine service account is used."
  type        = string
  default     = null
}
