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