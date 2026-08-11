terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Organization policy requires these tags on instances and volumes at launch.
locals {
  org_tags = {
    Name         = "${var.project_name}-connector"
    division     = var.division
    org          = var.org
    team         = var.team
    project      = var.project_name
    "keep-until" = formatdate("YYYY-MM-DD", timeadd(plantimestamp(), "24h"))
  }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "connector" {
  name          = "${var.project_name}-connector"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type           = "gp3"
      encrypted             = true
    }
  }

  network_interfaces {
    security_groups             = [var.connector_sg_id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    elasticsearch_endpoint = var.elasticsearch_endpoint
    connector_id           = var.connector_id
    connector_api_key      = var.connector_api_key
    connector_image        = var.connector_image
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = local.org_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.org_tags
  }
}

resource "aws_autoscaling_group" "connector" {
  name             = "${var.project_name}-connector"
  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.connector.id
    version = "$Latest"
  }

  # ASGs do not inherit provider default_tags — set the org-required tags here.
  dynamic "tag" {
    for_each = local.org_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
