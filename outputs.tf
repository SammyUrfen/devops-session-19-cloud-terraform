output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "security_group_id" {
  value = aws_security_group.web.id
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI picked by the data source."
  value       = data.aws_ami.al2023.id
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_dns}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}
