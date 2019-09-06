output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "dns_name" {
  value = local.create_dns_record ? join("", aws_route53_record.bastion_record_name.*.fqdn) : aws_lb.bastion_lb.dns_name
}

output "bastion_host_security_group" {
  value = aws_security_group.bastion_host_security_group.id
}

output "private_instances_security_group" {
  value = aws_security_group.private_instances_security_group.id
}
