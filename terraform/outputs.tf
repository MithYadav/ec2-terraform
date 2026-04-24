output "instance_id" {
  value       = aws_instance.app_server.id
  description = "EC2 Instance ID"
}

output "public_ip" {
  value       = aws_eip.app_server.public_ip
  description = "EC2 Public IP"
}

output "key_pair_name" {
  value       = aws_key_pair.deployer.key_name
  description = "Key pair name"
}

output "pem_file_location" {
  value       = "s3://ec2-terraform-state-373447294485/keys/${var.project_name}-deploy-key.pem"
  description = "PEM file location in S3"
}

output "ssh_command" {
  value       = "ssh -i ${var.project_name}-deploy-key.pem ec2-user@${aws_eip.app_server.public_ip}"
  description = "SSH command"
}

output "summary" {
  value = <<-EOT
    =========================================
    EC2 INSTANCE READY!
    =========================================
    Instance ID  : ${aws_instance.app_server.id}
    Public IP    : ${aws_eip.app_server.public_ip}
    Key Pair     : ${aws_key_pair.deployer.key_name}
    PEM file     : s3://ec2-terraform-state-373447294485/keys/${var.project_name}-deploy-key.pem
    SSH Command  : ssh -i ${var.project_name}-deploy-key.pem ec2-user@${aws_eip.app_server.public_ip}
    =========================================
  EOT
}
