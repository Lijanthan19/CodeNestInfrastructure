output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.codenest.id
}

output "elastic_ip" {
  description = "Elastic IP of CodeNest EC2"
  value       = aws_eip.codenest.public_ip
}

output "application_url" {
  description = "CodeNest Application URL"
  value       = "http://${aws_eip.codenest.public_ip}:50050"
}

output "iam_role_name" {
  description = "IAM Role attached to the EC2 instance"
  value       = aws_iam_role.codenest_ssm_role.name
}

output "instance_profile_name" {
  description = "IAM Instance Profile attached to the EC2 instance"
  value       = aws_iam_instance_profile.codenest.name
}

output "github_actions_role_arn" {
  description = "IAM Role ARN used by GitHub Actions through OIDC"
  value       = aws_iam_role.github_actions.arn
}