# =============================================================================
# Argus Infra — AWS Single VM Environment
# =============================================================================
# Provisions a single EC2 instance on AWS using the aws-ec2 module.
#
# Usage:
#   cd terraform/environments/aws-single-vm
#   terraform init
#   terraform plan -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
#   terraform apply -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure backend if using remote state
  # backend "s3" {
  #   bucket = "argus-terraform-state"
  #   key    = "environments/aws-single-vm/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------
module "argus_vm" {
  source = "../../modules/aws-ec2"

  name             = var.name
  region           = var.region
  instance_type    = var.instance_type
  root_volume_size = var.root_volume_size

  ssh_public_key = var.ssh_public_key
  ssh_user       = var.ssh_user

  vpc_cidr    = var.vpc_cidr
  subnet_cidr = var.subnet_cidr

  enable_public_ip     = true
  associate_elastic_ip = true

  create_security_group = true
  allowed_ssh_cidrs     = var.allowed_ssh_cidrs
  allowed_http_cidrs    = var.allowed_http_cidrs
  allowed_https_cidrs   = var.allowed_https_cidrs

  iam_role_name   = var.iam_role_name
  iam_policy_arns = var.iam_policy_arns

  tags = {
    project = "argus"
    env     = var.environment
    managed = "terraform"
  }
}
