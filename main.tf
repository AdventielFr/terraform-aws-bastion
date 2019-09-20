data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.sh")}"

  vars = {
    aws_region  = var.region
    bucket_name = var.bucket_name
  }
}

locals {
  create_dns_record = var.bastion_dns_zone_id != "" && var.bastion_dns_record_name != "" ? true : false
}


resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket_name
  acl    = "bucket-owner-full-control"

  force_destroy = var.bucket_force_destroy

  versioning {
    enabled = var.bucket_versioning
  }

  lifecycle_rule {
    id      = "log"
    enabled = var.log_auto_clean

    prefix = "logs/"

    tags = {
      rule      = "log"
      autoclean = var.log_auto_clean
    }

    transition {
      days          = var.log_standard_ia_days
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = var.log_glacier_days
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_expiry_days
    }
  }

  tags = "${merge(var.tags)}"
}

resource "aws_s3_bucket_object" "bucket_public_keys_readme" {
  bucket  =  aws_s3_bucket.bucket.id
  key     = "public-keys/README.txt"
  content = "Drop here the ssh public keys for connect by bastion"
}

resource "aws_security_group" "bastion_host_security_group" {
  name        = "${var.environment}-bastion-from-nlb-sg"
  description = "Enable SSH access to the bastion host from network load balancer subnets"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.public_ssh_port
    protocol    = "TCP"
    to_port     = 22
    cidr_blocks = var.elb_subnets
  }

  egress {
    from_port   = 0
    protocol    = "TCP"
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, map("Name","${var.environment}-bastion-from-nlb","Environment",var.environment  ))
}

resource "aws_iam_role" "bastion_host_role" {
  name = "${var.environment}-bastion-role"
  path = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com"
        ]
      },
      "Action": [
        "sts:AssumeRole"
      ]
    }
  ]
}
EOF

  tags = merge(var.tags, map("Name","${var.environment}-bastion-role","Environment",var.environment  ))
  
}

resource "aws_iam_role_policy" "bastion_host_role_policy" {
  role = aws_iam_role.bastion_host_role.id
  name = "${var.environment}-bastion-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": "arn:aws:s3:::${var.bucket_name}/logs/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${var.bucket_name}/public-keys/*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::${var.bucket_name}",
      "Condition": {
        "StringEquals": {
          "s3:prefix": "public-keys/"
        }
      }
    }
  ]
}
EOF
}

resource "aws_route53_record" "bastion_record_name" {
  count   = local.create_dns_record ? 1: 0
  name    = var.bastion_dns_record_name
  zone_id = var.bastion_dns_zone_id
  type    = "A"
  alias {
    evaluate_target_health = true
    name                   = "${aws_lb.bastion_lb.dns_name}"
    zone_id                = "${aws_lb.bastion_lb.zone_id}"
  }
}

resource "aws_lb" "bastion_lb" {
  name     = "${var.environment}-bastion-nlb"
  internal =  var.is_lb_private

  subnets = var.elb_subnets

  load_balancer_type = "network"

  tags = merge(var.tags, map("Name","${var.environment}-bastion-nlb","Environment",var.environment  ))
  
}

resource "aws_lb_target_group" "bastion_lb_target_group" {
  name        = "${var.environment}-bastion-tg"
  port        = 22
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    port     = "traffic-port"
    protocol = "TCP"
  }

  tags = merge(var.tags, map("Name","${var.environment}-bastion-tg","Environment",var.environment  ))
}

resource "aws_lb_listener" "bastion_lb_listener" {
  default_action {
    target_group_arn = aws_lb_target_group.bastion_lb_target_group.arn
    type             = "forward"
  }

  load_balancer_arn = aws_lb.bastion_lb.arn
  port              = var.public_ssh_port
  protocol          = "TCP"
}

resource "aws_iam_instance_profile" "bastion_host_profile" {
  role = aws_iam_role.bastion_host_role.name
  path = "/"
}

resource "aws_launch_configuration" "bastion_launch_configuration" {
  name                        = "${var.environment}-bastion-instance-lc"
  image_id                    = data.aws_ami.amazon-linux-2.id
  instance_type               = var.bastion_instance_type
  associate_public_ip_address = false
  enable_monitoring           = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_host_profile.name
  key_name                    = var.bastion_host_key_pair

  security_groups = [aws_security_group.bastion_host_security_group.id]

  user_data = data.template_file.user_data.rendered

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion_auto_scaling_group" {
  name                 = "${var.environment}-bastion-asg"
  launch_configuration = aws_launch_configuration.bastion_launch_configuration.name
  max_size             = var.bastion_instance_count
  min_size             = var.bastion_instance_count
  desired_capacity     = var.bastion_instance_count

  vpc_zone_identifier = var.auto_scaling_group_subnets

  default_cooldown          = 180
  health_check_grace_period = 180
  health_check_type         = "EC2"

  target_group_arns = [aws_lb_target_group.bastion_lb_target_group.arn]

  termination_policies = [
    "OldestLaunchConfiguration",
  ]

  tags = merge(var.tags, map("Name","${var.environment}-bastion","Environment", var.environment  ))

  lifecycle {
    create_before_destroy = true
  }
}
