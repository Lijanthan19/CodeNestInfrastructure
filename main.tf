# =========================================================
# GET LATEST UBUNTU 24.04 AMI AUTOMATICALLY
# =========================================================

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}


# =========================================================
# SECURITY GROUP
# =========================================================

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


# =========================================================
# EC2 INSTANCE
# =========================================================

resource "aws_instance" "codenest" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type

  # Attach IAM Instance Profile
  # This allows EC2 to communicate with AWS Systems Manager
  iam_instance_profile = aws_iam_instance_profile.codenest.name

  # Attach Security Group
  vpc_security_group_ids = [
    aws_security_group.codenest.id
  ]

  # Install Docker automatically when EC2 starts
  user_data = <<-EOF
    #!/bin/bash

    apt-get update -y

    apt-get install -y docker.io

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ubuntu
  EOF

  tags = {
    Name = "CodeNest-Server"
  }
}


# =========================================================
# ELASTIC IP
# =========================================================

resource "aws_eip" "codenest" {
  domain = "vpc"

  tags = {
    Name = "CodeNest-Elastic-IP"
  }
}


# =========================================================
# ATTACH ELASTIC IP TO EC2
# =========================================================

resource "aws_eip_association" "codenest" {
  instance_id   = aws_instance.codenest.id
  allocation_id = aws_eip.codenest.id
}


# =========================================================
# IAM ROLE FOR EC2 / SSM
# =========================================================

resource "aws_iam_role" "codenest_ssm_role" {
  name = "CodeNest-EC2-SSM-Role"

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

  tags = {
    Name = "CodeNest-EC2-SSM-Role"
  }
}


# =========================================================
# ATTACH SSM POLICY TO EC2 IAM ROLE
# =========================================================

resource "aws_iam_role_policy_attachment" "codenest_ssm" {
  role       = aws_iam_role.codenest_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# =========================================================
# CREATE IAM INSTANCE PROFILE
# =========================================================

resource "aws_iam_instance_profile" "codenest" {
  name = "CodeNest-EC2-Instance-Profile"

  role = aws_iam_role.codenest_ssm_role.name
}


# =========================================================
# CREATE GITHUB OIDC PROVIDER
# =========================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}


# =========================================================
# IAM ROLE FOR GITHUB ACTIONS
# =========================================================

resource "aws_iam_role" "github_actions" {
  name = "CodeNest-GitHub-Actions-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            # Allow GitHub Actions only from the main branch
            # of the Lijanthan19/CodeNestGH repository
            "token.actions.githubusercontent.com:sub" = "repo:Lijanthan19/CodeNestGH:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "CodeNest-GitHub-Actions-Role"
  }
}


# =========================================================
# GIVE GITHUB ACTIONS PERMISSION TO USE SSM
# =========================================================

resource "aws_iam_role_policy_attachment" "github_actions_ssm" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}