variable "aws_region" {
  description = "AWS region"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr" {
  description = "CIDR for the public subnet"
}

variable "private_subnet_cidr" {
  description = "CIDR for the private subnet"
}

variable "db_username" {
  description = "Username for the RDS DB"
}

variable "db_password" {
  description = "Password for the RDS DB"
  sensitive   = true
}
