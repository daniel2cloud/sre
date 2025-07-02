# Configure Terraform and required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region = "ap-east-1"
}

# Create a DB instance
resource "aws_db_instance" "example" {
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.m5.large"
  db_name             = "example_database_prod"
  username            = "admin"
  password            = "${var.db_password}"
  skip_final_snapshot = true
}
