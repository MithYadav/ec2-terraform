locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CreatedBy   = "GitHub Actions"
  }
}

# ─────────────────────────────────────────
# GENERATE SSH KEY PAIR
# Terraform generates private + public key
# No manual key generation needed!
# ─────────────────────────────────────────
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create key pair in AWS using generated public key
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deploy-key"
  public_key = tls_private_key.ec2_key.public_key_openssh

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-deploy-key"
  })
}

# Save private key as .pem file in S3
# So GitHub Actions can download it!
resource "aws_s3_object" "private_key" {
  bucket  = "ec2-terraform-state-373447294485"
  key     = "keys/${var.project_name}-deploy-key.pem"
  content = tls_private_key.ec2_key.private_key_pem

  # Restrict access
  server_side_encryption = "AES256"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-deploy-key.pem"
  })
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# ─────────────────────────────────────────
# SUBNET
# ─────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

# ─────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# ─────────────────────────────────────────
# ROUTE TABLE
# ─────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────
# SECURITY GROUP
# ─────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg"
  description = "Security group for EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Spring Boot"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

# ─────────────────────────────────────────
# EC2 INSTANCE
# ─────────────────────────────────────────
resource "aws_instance" "app_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  key_name               = aws_key_pair.deployer.key_name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-21-amazon-corretto
    yum install -y lsof
    mkdir -p /app
    chown ec2-user:ec2-user /app
    echo "EC2 setup complete!"
  EOF

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-server"
  })

  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
# ELASTIC IP
# ─────────────────────────────────────────
resource "aws_eip" "app_server" {
  instance   = aws_instance.app_server.id
  domain     = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eip"
  })

  depends_on = [aws_internet_gateway.main]
}
