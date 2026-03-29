provider "aws" {
  region = "ap-southeast-2"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ash-ec2-ssh-sg"
  description = "Allow SSH inbound traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ash-ec2-ssh-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "ash-terraform-key"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "Ash-Terraform-EC2"
  }
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}
