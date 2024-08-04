terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "al2023" {
  most_recent      = true
  owners           = ["amazon"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "name"
    values = ["al2023-ami-2023*"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "elk" {
  ami = data.aws_ami.al2023.id
  instance_type = "t2.micro"
  key_name = "Your pem key anme"
  vpc_security_group_ids = [aws_security_group.elk-sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2-profile.name
  tags = {
    Name = "elk-server"
  }
}

resource "aws_iam_role" "aws_access" {
  name = "awsrole-elk-polo"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]

}

resource "aws_iam_instance_profile" "ec2-profile" {
  name = "elk-server-profile-polo"
  role = aws_iam_role.aws_access.name
}


resource "aws_security_group" "elk-sg" {
  name = "elk-in-eks-sec-gr-polo"
  tags = {
    Name = "elk-in-eks-sec-gr-polo"
  }

  ingress {
    from_port = 22
    protocol  = "tcp"
    to_port   = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol  = "-1"
    to_port   = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "elk-server-polo-DNS" {
  value = aws_instance.elk.public_ip
}