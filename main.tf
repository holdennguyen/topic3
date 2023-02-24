terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 3.0"
      }
    }
}

# Configure the AWS provider 
provider "aws" {
    region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "Topic3-VPC"{
    cidr_block = var.cidr_block[0]
    tags = {
        Name = "Topic3-VPC"
    }
}

# Create Subnet (Public)
resource "aws_subnet" "Topic3-Subnet" {
    vpc_id = aws_vpc.Topic3-VPC.id
    cidr_block = var.cidr_block[1]
    tags = {
        Name = "Topic3-Subnet"
    }
}

# Create Internet Gateway
resource "aws_internet_gateway" "Topic3-IGW" {
    vpc_id = aws_vpc.Topic3-VPC.id
    tags = {
        Name = "Topic3-IGW"
    }
}

# Create Security Group
resource "aws_security_group" "Topic3-SG" {
    name = "Topic3-SG"
    description = "To allow inbound and outbount traffic to Topic3 lab"
    vpc_id = aws_vpc.Topic3-VPC.id
    dynamic ingress {
        iterator = port
        for_each = var.ports
            content {
              from_port = port.value
              to_port = port.value
              protocol = "tcp"
              cidr_blocks = ["0.0.0.0/0"]
            }
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "allow traffic"
    }
}

# Create route table and association
resource "aws_route_table" "Topic3-rtb" {
    vpc_id = aws_vpc.Topic3-VPC.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.Topic3-IGW.id
    }
    tags = {
        Name = "Topic3-rtb"
    }
}

resource "aws_route_table_association" "Topic3-rtba" {
    subnet_id = aws_subnet.Topic3-Subnet.id
    route_table_id = aws_route_table.Topic3-rtb.id
}

# Create an AWS EC2 Instance to host Ansible Controller (Control node)
resource "aws_instance" "Ansible-Controller" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.Topic3-SG.id]
  subnet_id = aws_subnet.Topic3-Subnet.id
  associate_public_ip_address = true
  user_data = file("./InstallAnsibleController.sh")

  tags = {
    Name = "Ansible-Controller"
  }
}

# Create an AWS S3 Bucket
resource "aws_s3_bucket" "Topic3-S3" {
  bucket = "topic3-holdennguyen"

  tags = {
    Name = "Topic3 bucket"
  }
}

# Block all public access for AWS S3
resource "aws_s3_bucket_public_access_block" "Topic3-S3-Block" {
  bucket = aws_s3_bucket.Topic3-S3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Copy an S3 object (file index.html)
resource "aws_s3_bucket_object" "index" {
  bucket = aws_s3_bucket.Topic3-S3.id
  key = "index.html"
  source = "./index.html"
}

# Create IAM role for EC2 to access S3's data
resource "aws_iam_role" "ec2-role" {
  name = "access-s3"
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
}

# Create policy to Read S3's data
resource "aws_iam_policy" "s3-read-policy" {
  name        = "s3-read-policy"
  description = "Access to Read S3 Data"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.Topic3-S3.arn}/*"
      ]
    }
  ]
}
EOF
}

# Attach policy to IAM role
resource "aws_iam_role_policy_attachment" "access-s3-attachment" {
  policy_arn = aws_iam_policy.s3-read-policy.arn
  role = aws_iam_role.ec2-role.name
}

# Create IAM instance profile with IAM role
resource "aws_iam_instance_profile" "profile-access-s3" {
  name = "profile-access-s3"
  role = aws_iam_role.ec2-role.name
}

# Create an AWS EC2 Instance to install Docker
resource "aws_instance" "Topic3-Dockerhost" {
  ami           = var.ami
  instance_type = var.instance_type
  key_name = "ec2"
  vpc_security_group_ids = [aws_security_group.Topic3-SG.id]
  subnet_id = aws_subnet.Topic3-Subnet.id
  associate_public_ip_address = true
  user_data = file("./InstallDocker.sh")
  # IAM instance profile to launch EC2 Instance with
  iam_instance_profile = aws_iam_instance_profile.profile-access-s3.name

  tags = {
    Name = "Topic3-Dockerhost"
  }
}
