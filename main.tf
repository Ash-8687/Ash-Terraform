provider "aws" {
  region = "ap-southeast-2"
}

terraform {
  backend "s3" {
    bucket = "ash-terraform-demo-bucket-2026"
    key    = "terraform.tfstate"
    region = "ap-southeast-2"
  }
}

terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ----- Variables -----

variable "region" {
  default = "ap-southeast-2"
}

variable "instance_type" {
  default = "t3.micro"
}

variable "name_prefix" {
  default = "ssm-demo"
}

# ----- Data Sources -----

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Default VPC (simplest setup)
data "aws_vpc" "default" {
  default = true
}

# Pick the first available subnet in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ----- IAM Role for SSM -----

resource "aws_iam_role" "ssm_role" {
  name = "${var.name_prefix}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# ----- Security Group (no inbound needed for SSM!) -----

resource "aws_security_group" "ssm_sg" {
  name        = "${var.name_prefix}-ssm-sg"
  description = "Allow outbound HTTPS for SSM agent - no inbound needed"
  vpc_id      = data.aws_vpc.default.id

  # SSM agent needs outbound HTTPS to reach AWS endpoints
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for SSM endpoints"
  }

  tags = {
    Name = "${var.name_prefix}-ssm-sg"
  }
}

# ----- EC2 Instance -----

resource "aws_instance" "ssm_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.ssm_sg.id]

  # Public IP so SSM agent can reach AWS endpoints via internet
  associate_public_ip_address = true

  # No key pair needed - we connect via SSM only!

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-instance"
  }
}

# ----- Outputs -----

output "instance_id" {
  description = "Use this to connect: aws ssm start-session --target <instance_id>"
  value       = aws_instance.ssm_instance.id
}

output "ami_used" {
  value = data.aws_ami.amazon_linux.id
}

output "region" {
  value = var.region
}
