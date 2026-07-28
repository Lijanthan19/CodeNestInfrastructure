# Get the latest Ubuntu 24.04 AMI automatically
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}


# Security Group
resource "aws_security_group" "codenest" {
  name        = "codenest-security-group"
  description = "Allow SSH and CodeNest application traffic"

  # Allow SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow CodeNest application
  ingress {
    description = "CodeNest Application"
    from_port   = 50050
    to_port     = 50050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "CodeNest-Security-Group"
  }
}


# Create EC2 Instance
resource "aws_instance" "codenest" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.codenest.id
  ]

  tags = {
    Name = "CodeNest-Server"
  }
}


# Create Elastic IP
resource "aws_eip" "codenest" {
  domain = "vpc"

  tags = {
    Name = "CodeNest-Elastic-IP"
  }
}


# Attach Elastic IP to EC2
resource "aws_eip_association" "codenest" {
  instance_id   = aws_instance.codenest.id
  allocation_id = aws_eip.codenest.id
}