# =============================================================================
# Argus Infra — AWS EKS Environment
# =============================================================================
# Provisions a managed EKS cluster on AWS using the aws-eks module.
#
# Prerequisites:
#   - AWS credentials configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
#   - aws CLI installed and authenticated
#
# Usage:
#   cd terraform/environments/aws-eks
#   terraform init
#   terraform plan
#   terraform apply
#
# Verify:
#   eval $(terraform output -raw kubectl_env)
#   kubectl get nodes
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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

  # Uncomment and configure backend if using remote state
  # backend "s3" {
  #   bucket = "argus-terraform-state"
  #   key    = "environments/aws-eks/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
module "argus_eks" {
  source = "../../modules/aws-eks"

  cluster_name    = var.cluster_name
  region          = var.region
  cluster_version = var.cluster_version

  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway

  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access
  public_access_cidrs     = var.public_access_cidrs

  num_nodes           = var.num_nodes
  min_nodes           = var.min_nodes
  max_nodes           = var.max_nodes
  node_instance_types = var.node_instance_types
  node_disk_size      = var.node_disk_size
  node_ssh_key_name   = var.node_ssh_key_name
  enable_node_ssh     = var.enable_node_ssh
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs

  enabled_cluster_log_types = var.enabled_cluster_log_types

  generate_kubeconfig = var.generate_kubeconfig
  kubeconfig_path     = var.kubeconfig_path

  tags = {
    project = "argus"
    env     = var.environment
    managed = "terraform"
  }
}
