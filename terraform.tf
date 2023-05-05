provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "terraform_sg" {
  name_prefix = "test-sg"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "test-sg"
  }
  vpc_id = data.aws_vpc.default.id
}

resource "aws_launch_configuration" "example" {
  name_prefix      = "example-lc-"
  image_id         = "ami-007855ac798b5175e"
  instance_type    = "t2.micro"
  key_name         = "vinay"
  security_groups  = [aws_security_group.terraform_sg.id]
  user_data        = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt install docker.io -y
    docker pull digitalocean/flask-helloworld
    docker run -d -p 5000:5000 digitalocean/flask-helloworld
    EOF
}


resource "aws_autoscaling_group" "example" {
  name                 = "terraform-asg"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 1
  health_check_grace_period = 300
  health_check_type = "EC2"
  force_delete = true
  launch_configuration = aws_launch_configuration.example.id
  vpc_zone_identifier  = [data.aws_subnets.default.ids[0], data.aws_subnets.default.ids[0]]
  termination_policies = ["OldestInstance", "ClosestToNextInstanceHour", "Default"]
  tag {
    key                 = "Name"
    value               = "example"
    propagate_at_launch = true
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "example-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors CPU utilization for the example application"
  alarm_actions       = [aws_autoscaling_policy.example.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }
}

resource "aws_autoscaling_policy" "example" {
  name                   = "example-autoscaling-policy"
  policy_type            = "TargetTrackingScaling"
  estimated_instance_warmup = 120
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
  autoscaling_group_name  = aws_autoscaling_group.example.name
}


resource "aws_cloudwatch_metric_alarm" "memory_alarm" {
  alarm_name          = "example-memory-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "System/Linux"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors memory utilization for the example application"
  alarm_actions       = [aws_autoscaling_policy.example.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }
}

