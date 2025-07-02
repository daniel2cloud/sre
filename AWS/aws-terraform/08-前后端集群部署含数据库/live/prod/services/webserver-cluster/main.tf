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

# Use Module
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"
  
  ami         = "ami-0a016692298cf2ee2"
  server_text = "Hello, World"

  cluster_name           = "werservers-prod"
  db_remote_state_bucket = "${var.db_remote_state_bucket}"
  db_remote_state_key    = "${var.db_remote_state_key}"

  instance_type       = "t3.small"
  min_size            = 2
  max_size            = 10
  enable_autoscaling  = true
}
