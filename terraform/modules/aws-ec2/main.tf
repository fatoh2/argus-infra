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
  # Resolve availability zone: default to <region>a if not specified
  availability_zone = var.availability_zone != null ? var.availability_zone : "${var.region}a"

  # Default user data script installs Docker on Ubuntu
  user_data = var.user_data != null ? var.user_data : templatefile(
    "${path.module}/scripts/install-docker.sh.tftpl",
    {}
  )

  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Name    = var.name
    project = "argus"
  })

  # IAM role name
  iam_role_name = var.iam_role_name != null ? var.iam_role_name : "${var.name}-role"
}

# ---------------------------------------------------------------------------
# AMI — Latest Ubuntu 22.04 LTS
# ---------------------------------------------------------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.name}-vpc"
  })
}

# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-igw"
  })
}

# ---------------------------------------------------------------------------
# Public Subnet
# ---------------------------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = var.enable_public_ip

  tags = merge(local.common_tags, {
    Name = "${var.name}-subnet-public"
  })
}

# ---------------------------------------------------------------------------
# Route Table — Public subnet → Internet Gateway
# ---------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-rt-public"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------
resource "aws_security_group" "this" {
  count       = var.create_security_group ? 1 : 0
  name        = "${var.name}-sg"
  description = "Security group for Argus EC2 instance (${var.name})"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = var.create_security_group ? 1 : 0
  security_group_id = aws_security_group.this[0].id

  description = "SSH access"
  cidr_ipv4   = var.allowed_ssh_cidrs[0]
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  count             = var.create_security_group ? 1 : 0
  security_group_id = aws_security_group.this[0].id

  description = "HTTP access"
  cidr_ipv4   = var.allowed_http_cidrs[0]
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  count             = var.create_security_group ? 1 : 0
  security_group_id = aws_security_group.this[0].id

  description = "HTTPS access"
  cidr_ipv4   = var.allowed_https_cidrs[0]
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  count             = var.create_security_group ? 1 : 0
  security_group_id = aws_security_group.this[0].id

  description = "Allow all outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  to_port     = 0
  ip_protocol = "-1"
}

# ---------------------------------------------------------------------------
# IAM Role & Instance Profile
# ---------------------------------------------------------------------------
resource "aws_iam_role" "this" {
  count = var.iam_role_name != null ? 1 : 0
  name  = local.iam_role_name

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

resource "aws_iam_role_policy_attachment" "this" {
  count      = var.iam_role_name != null ? length(var.iam_policy_arns) : 0
  role       = aws_iam_role.this[0].name
  policy_arn = var.iam_policy_arns[count.index]
}

resource "aws_iam_instance_profile" "this" {
  count = var.iam_role_name != null ? 1 : 0
  name  = "${local.iam_role_name}-profile"
  role  = aws_iam_role.this[0].name

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# SSH Key Pair
# ---------------------------------------------------------------------------
resource "aws_key_pair" "this" {
  count      = var.ssh_public_key != null ? 1 : 0
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------
resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = var.create_security_group ? [aws_security_group.this[0].id] : []
  key_name               = var.ssh_public_key != null ? aws_key_pair.this[0].key_name : null
  iam_instance_profile   = var.iam_role_name != null ? aws_iam_instance_profile.this[0].name : null
  user_data              = base64encode(local.user_data)
  user_data_replace_on_change = false

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${var.name}-root-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = var.name
  })

  # Allow stopping for updates
  disable_api_termination = false
}

# ---------------------------------------------------------------------------
# Elastic IP
# ---------------------------------------------------------------------------
resource "aws_eip" "this" {
  count    = var.associate_elastic_ip ? 1 : 0
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name}-eip"
  })
}

resource "aws_eip_association" "this" {
  count         = var.associate_elastic_ip ? 1 : 0
  instance_id   = aws_instance.this.id
  allocation_id = aws_eip.this[0].id
}
