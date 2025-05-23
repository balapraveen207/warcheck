provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# Private Subnet
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
}

# Route Table & Association
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group for EC2
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
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
}

# Security Group for RDS
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Allow MySQL from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2 in us-east-1
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  key_name                    = "mundapraveen" # Replace with your actual key name

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd
              sudo systemctl enable httpd
              echo "Hello World from Terraform!" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-instance"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "db_subnets" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

# RDS Database
resource "aws_db_instance" "db" {
  allocated_storage         = 20
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = "db.t3.micro"
  db_name                   = "mydb"
  username                  = "admin"
  password                  = "password123" # Replace with a secure password
  skip_final_snapshot       = true
  db_subnet_group_name      = aws_db_subnet_group.db_subnets.name
  vpc_security_group_ids    = [aws_security_group.db_sg.id]
  multi_az                  = false
  publicly_accessible       = false
  availability_zone         = "us-east-1b"
}

# CloudWatch Metric Alarms
resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  alarm_name                = "EC2-Status-Check-Failed"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "StatusCheckFailed"
  namespace                 = "AWS/EC2"
  period                    = "60"
  statistic                 = "Maximum"
  threshold                 = "1"
  alarm_description         = "Trigger alarm if EC2 instance fails status check"
  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_utilization" {
  alarm_name                = "EC2-CPU-Utilization"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "80"
  alarm_description         = "Trigger alarm if EC2 CPU utilization exceeds 80%"
  dimensions = {
    InstanceId = aws_instance.web.id
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name                = "Lambda-Errors"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = "300"
  statistic                 = "Sum"
  threshold                 = "1"
  alarm_description         = "Trigger alarm if Lambda function has errors"
  dimensions = {
    FunctionName = "hello-world"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name                = "Lambda-Duration"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "1"
  metric_name               = "Duration"
  namespace                 = "AWS/Lambda"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "2000"
  alarm_description         = "Trigger alarm if Lambda function duration exceeds 2 seconds"
  dimensions = {
    FunctionName = "hello-world"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "infra-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x    = 0,
        y    = 0,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/Lambda", "Errors", "FunctionName", "my-lambda-function" ]
          ],
          view     = "timeSeries",
          region   = "us-east-1",
          stat     = "Sum",
          period   = 300
        }
      },
      {
        type = "metric",
        x    = 0,
        y    = 6,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "InstanceId", "i-0123456789abcdef0" ]
          ],
          view     = "timeSeries",
          region   = "us-east-1",
          stat     = "Average",
          period   = 300
        }
      }
    ]
  })
}


output "ec2_instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "rds_endpoint" {
  value = aws_db_instance.db.endpoint
}
