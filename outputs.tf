output "bucket_name" {
  description = "The S3 Bucker to save log of the bastion"
  value = aws_s3_bucket.bucket.bucket
}

output "dns_name" {
  description = "The DNS of the bastion"
  value = local.create_dns_record ? join("", aws_route53_record.bastion_record_name.*.fqdn) : aws_lb.bastion_lb.dns_name
}

output "bastion_host_security_group" {
  description = "The security group of the bastion"
  value = aws_security_group.bastion_host_security_group.id
}
