# ---------- Network ----------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id # implicit dependency on the VPC
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-public-subnet" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------- Security group ----------
resource "aws_security_group" "web" {
  name        = "${var.project}-web-sg"
  description = "HTTP from anywhere, SSH only from ssh_allowed_cidr"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from one trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (dnf needs it in user_data)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

# ---------- EC2 ----------
# Latest Amazon Linux 2023 AMI, looked up at plan time instead of a hard-coded ID that differs per region.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = var.key_name

  user_data = <<-EOT
    #!/bin/bash
    dnf install -y nginx
    echo "<h1>Hello from ${var.project} (Terraform, Session 19)</h1>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  # Explicit dependency: nothing in this block references the route table association,
  # so Terraform could boot the instance before the subnet has a route to the internet.
  # user_data then runs `dnf install` with no internet access and the hello page never appears.
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${var.project}-web" }
}

# ---------- S3 ----------
# Bucket names are global, so a random suffix avoids name clashes.
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-artifacts-${random_id.bucket_suffix.hex}"
  force_destroy = true # lets `terraform destroy` remove the bucket even if it has objects
  tags          = { Name = "${var.project}-artifacts" }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
