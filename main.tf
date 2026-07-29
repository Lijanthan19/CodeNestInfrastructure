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
/*resource "aws_instance" "codenest" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type

  vpc_security_group_ids = [
    aws_security_group.codenest.id
  ]

  tags = {
    Name = "CodeNest-Server"
  }
}*/

resource "aws_instance" "codenest" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = var.instance_type

  iam_instance_profile = aws_iam_instance_profile.codenest.name

  vpc_security_group_ids = [
    aws_security_group.codenest.id
  ]

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

# Crete IAM role
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



#Attach policy to SSM
resource "aws_iam_role_policy_attachment" "codenest_ssm" {
  role       = aws_iam_role.codenest_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#Create Instance profile 
resource "aws_iam_instance_profile" "codenest" {
  name = "CodeNest-EC2-Instance-Profile"

  role = aws_iam_role.codenest_ssm_role.name
}

#Create the GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

#Create the IAM Role for GitHub actions
/*resource "aws_iam_role" "github_actions" {
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
          }

          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Lijanthan19/CodeNestGH:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "CodeNest-GitHub-Actions-Role"
  }
}*/
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

#Give GitHub Actions permission to use SSM
resource "aws_iam_role_policy_attachment" "github_actions_ssm" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}