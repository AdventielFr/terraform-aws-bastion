<table>
  <tr>
    <td style="text-align: center; vertical-align: middle;"><img src="_docs/logo_aws.jpg"/></td>
    <td style="text-align: center; vertical-align: middle;"><img src="_docs/logo_adv.jpg"/></td>
  </tr> 
<table>

# AWS EC2 Bastion Terraform module

## I - Infrastructure components

This module aims to create resilient bastion. This module creates for each bastion creates:

### I.1 - AWS Network Load Balancer

Name : **{{environment}}**-bastion-nlb

### I.2 - AWS AutoScaling groups

Name: **{{environment}}**-bastion-asg

### I.3 - AWS Launch Configuration

Name: **{{environment}}**-bastion-instance-lc

### I.4 - AWS EC2 instance

Name: **{{environment}}**-bastion

## II - Inputs / Outputs

## Inputs

| Name | Description | Type | Default |
|------|-------------|:----:|:-----:|
| auto\_scaling\_group\_subnets | List of subnet were the Auto Scalling Group will deploy the instances | list(string) | n/a |
| bastion\_dns\_record\_name | The DNS record name to use for the bastion | string | "" |
| bastion\_dns\_zone\_id | The ID of the hosted zone were we'll register the bastion DNS name | string | "" |
| bastion\_host\_key\_pair | Select the key pair to use to launch the bastion host | string | n/a |
| bastion\_instance\_count | The count of instance of bastion | number | 1 |
| bastion\_instance\_type | The ec2 instance type for the bastion | string | "t2.nano" |
| bastion\_port | Set the SSH port to use to access to the bastion | number | 22 |
| bucket\_force\_destroy | The bucket and all objects should be destroyed when using true | bool | false |
| bucket\_name | Bucket name were the bastion will store the logs | string | n/a |
| bucket\_versioning | Enable bucket versioning or not | bool | true |
| cidrs | List of CIDRs than can access to the bastion. Default : 0.0.0.0/0 | list(string) | \["0.0.0.0/0",\] |
| cloudwatch\_log\_retention | The cloudwatch log retention ( default 7 days ). | number | 7 |
| elb\_subnets | List of subnet were the ELB will be deployed | list(string) | n/a |
| environment | The environment | string | n/a |
| is\_lb\_private | If TRUE the load balancer scheme will be \ | bool | false |
| log\_auto\_clean | Enable or not the lifecycle | bool | false |
| log\_expiry\_days | Number of days before logs expiration | number | 90 |
| log\_glacier\_days | Number of days before moving logs to Glacier | number | 60 |
| log\_standard\_ia\_days | Number of days before moving logs to IA Storage | number | 30 |
| private\_security\_group |  | string | "" |
| public\_security\_group |  | string | "" |
| region | The deployment aws region | string | n/a |
| scan\_alarm\_clock | The time between two scan to find and remove publi SSH key in S3 bucket ( in minutes default 30 minutes) | number | 30 |
| tags | A mapping of tags to assign | map | {} |
| vpc\_id | VPC id were we'll deploy the bastion | string | n/a |
| with\_auto\_clean\_obsolete\_publc\_keys | Activate or deactivate auto cleaner ssh public key in s3 bucker | bool | true |

## Outputs

| Name | Description |
|------|-------------|
| bastion\_host\_security\_group | The security group attached to the network load balancer |
| bucket\_name | The bucket that logs shell commands passed on the bastion. |
| dns\_name | The fqdn of the bastion |
| private\_instances\_security\_group | The security group attached to the ec2 instances |

## III - Usage

`````

module "sample"
  environment                = "stage"
  auto_scaling_group_subnets = ["subnet-09431a12fc6xxxxx","subnet-09431a12fc6yyyyy"]
  region                     = "eu-west-3"
  bastion_host_key_pair      = "my-keypair"
  bastion_instance_count     = "1"
  bucket_name                = "mybucket-bastion-logs"
  bucket_force_destroy       = true
  cidrs                      = "10.0.0.0/16"
  elb_subnets                = ["subnet-09431a12fc6wwwwww","subnet-09431a12fc6zzzzz"]
  is_lb_private              = "false"
  log_expiry_days            = "90"
  log_glacier_days           = "60"
  log_standard_ia_days       = "10"
  private_ssh_port           = "22"
  public_ssh_port            = "2"
  vpc_id                     = "vpc-08543dc6bb8b6xxxx"

  tags = {
    Name        = stage-bastion"
    Environment = "stage"
  }

`````