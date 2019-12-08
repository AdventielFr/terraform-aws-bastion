
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.sh")}"

  vars = {
    aws_region   = var.region
    bucket_name  = var.bucket_name
    bastion_port = var.bastion_port
  }
}

locals {
  create_dns_record = var.bastion_dns_zone_id != "" && var.bastion_dns_record_name != "" ? true : false
  tags_asg_format   = [null_resource.tags_as_list_of_maps.*.triggers]
  tags              = merge(var.tags, map("Environment", var.environment))
}

resource "null_resource" "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers = map(
    "key", element(keys(var.tags), count.index),
    "value", element(values(var.tags), count.index),
    "propagate_at_launch", "true"
  )
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

  tags = local.tags
}

resource "aws_s3_bucket_object" "bucket_public_keys_readme" {
  bucket  = aws_s3_bucket.bucket.id
  key     = "public-keys/README.txt"
  content = "Drop here the ssh public keys for connect by bastion"
}

resource "aws_security_group" "bastion_host_security_group" {
  name        = "${var.environment}-bastion-from-internet-sg"
  description = "Enable SSH access to the bastion host from internet via SSH port"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.bastion_port
    protocol    = "TCP"
    to_port     = var.bastion_port
    cidr_blocks = var.cidrs
  }

  egress {
    from_port   = 0
    protocol    = "TCP"
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, map("Name", "${var.environment}-bastion-from-internet-sg"))

}

resource "aws_security_group" "private_instances_security_group" {
  name        = "${var.environment}-bastion-from-private-sg"
  description = "Enable SSH access to the Private instances from the bastion via SSH port"
  vpc_id      = var.vpc_id

  ingress {
    from_port = var.bastion_port
    protocol  = "TCP"
    to_port   = var.bastion_port

    security_groups = [aws_security_group.bastion_host_security_group.id]
  }

  tags = merge(local.tags, map("Name", "${var.environment}-bastion-from-private-sg"))
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

  tags = merge(local.tags, map("Name", "${var.environment}-bastion-role"))
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
  count   = local.create_dns_record ? 1 : 0
  name    = var.bastion_dns_record_name
  zone_id = var.bastion_dns_zone_id
  type    = "A"
  alias {
    evaluate_target_health = true
    name                   = aws_lb.bastion_lb.dns_name
    zone_id                = aws_lb.bastion_lb.zone_id
  }
}

resource "aws_lb" "bastion_lb" {
  name     = "${var.environment}-bastion-nlb"
  internal = var.is_lb_private

  subnets = var.elb_subnets

  load_balancer_type = "network"

  tags = merge(local.tags, map("Name", "${var.environment}-bastion-nlb"))
}

resource "aws_lb_target_group" "bastion_lb_target_group" {
  name        = "${var.environment}-bastion-tg"
  port        = var.bastion_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    port     = "traffic-port"
    protocol = "TCP"
  }

  tags = merge(local.tags, map("Name", "${var.environment}-bastion-tg"))
}

resource "aws_lb_listener" "bastion_lb_listener" {
  default_action {
    target_group_arn = aws_lb_target_group.bastion_lb_target_group.arn
    type             = "forward"
  }

  load_balancer_arn = aws_lb.bastion_lb.arn
  port              = var.bastion_port
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
  security_groups             = [aws_security_group.bastion_host_security_group.id]
  user_data                   = data.template_file.user_data.rendered
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

  tag {
    key                 = "Name"
    value               = "${var.environment}-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


data "aws_iam_policy_document" "find_and_remove_expired_ssh_keys" {

  statement {
    effect = "Allow"
    resources = [
      aws_s3_bucket.bucket.arn
    ]

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
    ]
  }

  statement {
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.bucket.arn}/*"
    ]

    actions = [
      "s3:ListBucket"
    ]
  }

  statement {
    sid       = "AllowSNSPermissions"
    effect    = "Allow"
    resources = [
      aws_sns_topic.find_and_remove_expired_ssh_keys.[0].arn
      ]

    actions = [
      "sns:Publish"
    ]
  }

  statement {
    sid       = "AllowCloudwatck"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "find_and_remove_expired_ssh_keys" {
  count  = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  name   = "bastion-find-and-remove-expired-ssh-keys-policy"
  policy = data.aws_iam_policy_document.find_and_remove_expired_ssh_keys.json
}

resource "aws_iam_role" "find_and_remove_expired_ssh_keys" {
  count              = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  name               = "bastion-find-and-remove-expired-ssh-keys-role"
  description        = "Set of access policies granted to lambda Bastion find and remove expired public SSH key}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
  tags               = merge(local.tags, map("Lambda", "bastion-find-and-remove-expired-ssh-keys"))
}

resource "aws_iam_role_policy_attachment" "find_and_remove_expired_ssh_keys" {
  count      = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  policy_arn = aws_iam_policy.find_and_remove_expired_ssh_keys[0].arn
  role       = aws_iam_role.find_and_remove_expired_ssh_keys[0].name
}

resource "aws_lambda_function" "find_and_remove_expired_ssh_keys" {
  count         = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  function_name = "bastion-find-and-remove-expired-ssh-keys"
  memory_size   = 128
  description   = "Find and remove public SSH Key in AWS S3 bucket who are obsolete"
  timeout       = 60
  runtime       = "python3.7"
  filename      = "${path.module}/bastion-find-and-remove-expired-ssh-keys.zip"
  handler       = "lambda_handler.main"
  role          = aws_iam_role.find_and_remove_expired_ssh_keys[0].arn

  environment {
    variables = {
      AWS_SNS_RESULT_ARN = aws_sns_topic.find_and_remove_expired_ssh_keys[0].arn
      AWS_S3_BUCKET      = var.bucket_name
    }
  }

  tags = merge(local.tags, map("Lambda", "bastion-find-and-remove-expired-ssh-keys"))

  depends_on = [
    aws_iam_role_policy_attachment.find_and_remove_expired_ssh_keys,
    aws_cloudwatch_log_group.find_and_remove_expired_ssh_keys
  ]
}

resource "aws_lambda_permission" "find_and_remove_expired_ssh_keys" {
  count         = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.find_and_remove_expired_ssh_keys[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.find_and_remove_expired_ssh_keys[0].arn
}

resource "aws_cloudwatch_log_group" "find_and_remove_expired_ssh_keys" {
  count             = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  name              = "/aws/lambda/bastion-find-and-remove-expired-ssh-keys"
  retention_in_days = var.cloudwatch_log_retention
}

resource "aws_cloudwatch_event_rule" "find_and_remove_expired_ssh_keys" {
  count               = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  name                = "bastion-find-and-remove-expired-ssh-keys-schedule"
  schedule_expression = "rate(${var.scan_alarm_clock} minutes)"
}

resource "aws_cloudwatch_event_target" "find_and_remove_expired_ssh_keys" {
  count     = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  rule      = aws_cloudwatch_event_rule.find_and_remove_expired_ssh_keys[0].name
  target_id = "bastion-find-and-remove-expired-ssh-keys-schedule"
  arn       = aws_lambda_function.find_and_remove_expired_ssh_keys[0].arn
}

resource "aws_sns_topic" "find_and_remove_expired_ssh_keys" {
  count        = var.with_auto_clean_obsolete_publc_keys ? 1 : 0
  name         = "bastion-find-and-remove-expired-ssh-keys-result"
  display_name = "Topic for Bastion Find and Remove SSH public expired key result"
  tags         = local.tags
}