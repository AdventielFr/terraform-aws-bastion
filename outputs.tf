output "bucket_name" {
  description = "The bucket that logs shell commands passed on the bastion."
  value = aws_s3_bucket.bucket.bucket
}

output "dns_name" {
  description = " The fqdn of the bastion"
  value = local.create_dns_record ? join("", aws_route53_record.bastion_record_name.*.fqdn) : aws_lb.bastion_lb.dns_name
}

output "bastion_host_security_group" {
  description =  "The security group attached to the network load balancer"
  value = aws_security_group.bastion_host_security_group.id
}

output "private_instances_security_group" {
   description =  "The security group attached to the ec2 instances"
  value = aws_security_group.private_instances_security_group.id
}

output "bastion_port" {
  description =" The bastion port"
  value = local.bastion_port
}
