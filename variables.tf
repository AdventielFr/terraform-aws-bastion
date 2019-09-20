variable "environment" {
  description = "The environment"
  type        = string
}

variable "bucket_name" {
  type        = string
  description = "Bucket name were the bastion will store the logs"
}

variable "bucket_versioning" {
  default     = true
  type        = bool
  description = "Enable bucket versioning or not"
}

variable "bucket_force_destroy" {
  default     = false
  type        = bool
  description = "The bucket and all objects should be destroyed when using true"
}

variable "tags" {
  description = "A mapping of tags to assign"
  default     = {}
  type        = "map"
}

variable "region" {
  type        = string 
  description = "The deployment aws region"
}

variable "cidrs" {
  description = "List of CIDRs than can access to the bastion. Default : 0.0.0.0/0"
  type        = list(string)
  default = [
    "0.0.0.0/0",
  ]
}

variable "vpc_id" {
  type        = string
  description = "VPC id were we'll deploy the bastion"
}

variable "bastion_host_key_pair" {
  type        = string
  description = "Select the key pair to use to launch the bastion host"
}

variable "bastion_instance_type" {
  type        = string
  description = "The ec2 instance type for the bastion"
  default     = "t2.nano"
}

variable "bastion_dns_zone_id" {
  type        = string
  description = "The ID of the hosted zone were we'll register the bastion DNS name"
  default     = ""
}

variable "bastion_dns_record_name" {
  type        = string
  description = "The DNS record name to use for the bastion"
  default     = ""
}

variable "elb_subnets" {
  type        = list(string)
  description = "List of subnet were the ELB will be deployed"
}

variable "auto_scaling_group_subnets" {
  type        = list(string)
  description = "List of subnet were the Auto Scalling Group will deploy the instances"
}

variable "bastion_instance_count" {
  type = number
  description = "The count of instance of bastion"
  default = 1
}

variable "log_auto_clean" {
  type        = bool
  description = "Enable or not the lifecycle"
  default     = false
}

variable "log_standard_ia_days" {
  type        = number
  description = "Number of days before moving logs to IA Storage"
  default     = 30
}

variable "log_glacier_days" {
  type        = number
  description = "Number of days before moving logs to Glacier"
  default     = 60
}

variable "log_expiry_days" {
  type        = number
  description = "Number of days before logs expiration"
  default     = 90
}

variable "public_ssh_port" {
  type        = number
  description = "Set the SSH port to use from desktop to the bastion"
  default     = 22
}

variable "public_security_group" {
  type = string
  default = ""
}

variable "private_security_group" {
  type = string
  default = ""
}
