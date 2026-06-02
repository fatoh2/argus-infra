terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Name    = local.cluster_name
    project = "argus"
  })

  # Subnet CIDRs — one per AZ
  public_subnet_cidrs  = [for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i in range(length(var.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i + 64)]
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-vpc"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-igw"
  })
}

# ---------------------------------------------------------------------------
# Public Subnets (one per AZ)
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name                                          = "${local.cluster_name}-subnet-public-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  })
}

# ---------------------------------------------------------------------------
# Private Subnets (one per AZ)
# ---------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name                                          = "${local.cluster_name}-subnet-private-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  })
}

# ---------------------------------------------------------------------------
# Elastic IPs for NAT Gateways
# ---------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? length(var.availability_zones) : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-nat-eip-${var.availability_zones[count.index]}"
  })
}

# ---------------------------------------------------------------------------
# NAT Gateways (one per AZ)
# ---------------------------------------------------------------------------
resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-nat-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ---------------------------------------------------------------------------
# Public Route Table
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private Route Tables (one per AZ, route through NAT Gateway)
# ---------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-rt-private-${var.availability_zones[count.index]}"
  })
}

resource "aws_route_table_association" "private" {
  count = var.enable_nat_gateway ? length(var.availability_zones) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ---------------------------------------------------------------------------
# Security Group — EKS Cluster
# ---------------------------------------------------------------------------
resource "aws_security_group" "eks_cluster" {
  name        = "${local.cluster_name}-eks-cluster-sg"
  description = "Security group for EKS cluster control plane"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-eks-cluster-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "eks_cluster_all" {
  security_group_id = aws_security_group.eks_cluster.id

  description = "Allow all outbound traffic from EKS cluster"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

# ---------------------------------------------------------------------------
# Security Group — EKS Nodes
# ---------------------------------------------------------------------------
resource "aws_security_group" "eks_nodes" {
  name        = "${local.cluster_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-eks-nodes-sg"
  })
}

# Allow node-to-node communication
resource "aws_vpc_security_group_ingress_rule" "nodes_self" {
  security_group_id = aws_security_group.eks_nodes.id

  description                  = "Allow node-to-node communication"
  referenced_security_group_id = aws_security_group.eks_nodes.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# Allow cluster control plane to talk to nodes
resource "aws_vpc_security_group_ingress_rule" "cluster_to_nodes" {
  security_group_id = aws_security_group.eks_nodes.id

  description                  = "Allow control plane to communicate with nodes"
  referenced_security_group_id = aws_security_group.eks_cluster.id
  from_port                    = 0
  to_port                      = 65535
  ip_protocol                  = "tcp"
}

# Allow SSH from allowed CIDRs (optional, for debugging)
resource "aws_vpc_security_group_ingress_rule" "nodes_ssh" {
  count = var.enable_node_ssh ? 1 : 0

  security_group_id = aws_security_group.eks_nodes.id

  description = "SSH access to worker nodes"
  cidr_ipv4   = var.allowed_ssh_cidrs[0]
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "nodes_all" {
  security_group_id = aws_security_group.eks_nodes.id

  description = "Allow all outbound traffic from nodes"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

# ---------------------------------------------------------------------------
# IAM Role — EKS Cluster
# ---------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# ---------------------------------------------------------------------------
# IAM Role — EKS Node Group
# ---------------------------------------------------------------------------
resource "aws_iam_role" "eks_nodes" {
  name = "${local.cluster_name}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ec2_container_registry" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------------------------------------------------------------------
# EKS Cluster
# ---------------------------------------------------------------------------
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = local.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : []
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_service_policy,
  ]
}

# ---------------------------------------------------------------------------
# OIDC Provider — for IAM roles for service accounts (IRSA)
# ---------------------------------------------------------------------------
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# EKS Node Group
# ---------------------------------------------------------------------------
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id

  instance_types = var.node_instance_types
  disk_size      = var.node_disk_size

  scaling_config {
    desired_size = var.num_nodes
    min_size     = var.min_nodes
    max_size     = var.max_nodes
  }

  update_config {
    max_unavailable = 1
  }

  # Configure SSH key for node access (optional)
  dynamic "remote_access" {
    for_each = var.node_ssh_key_name != null ? [1] : []
    content {
      ec2_ssh_key               = var.node_ssh_key_name
      source_security_group_ids = [aws_security_group.eks_nodes.id]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.cluster_name}-node-group"
  })

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ec2_container_registry,
  ]
}

# ---------------------------------------------------------------------------
# kubeconfig — generated locally for immediate kubectl access
# ---------------------------------------------------------------------------
resource "local_file" "kubeconfig" {
  count = var.generate_kubeconfig ? 1 : 0

  filename = pathexpand(var.kubeconfig_path)
  content = templatefile("${path.module}/templates/kubeconfig.tftpl", {
    cluster_name     = aws_eks_cluster.this.name
    cluster_endpoint = aws_eks_cluster.this.endpoint
    cluster_ca       = aws_eks_cluster.this.certificate_authority[0].data
    region           = var.region
  })

  file_permission = "0600"
}

# ---------------------------------------------------------------------------
# Outputs for kubectl configuration
# ---------------------------------------------------------------------------
resource "null_resource" "configure_kubectl" {
  count = var.generate_kubeconfig ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      aws eks update-kubeconfig \
        --region ${var.region} \
        --name ${aws_eks_cluster.this.name} \
        --kubeconfig ${pathexpand(var.kubeconfig_path)}
    EOT
  }

  depends_on = [local_file.kubeconfig[0]]
}
