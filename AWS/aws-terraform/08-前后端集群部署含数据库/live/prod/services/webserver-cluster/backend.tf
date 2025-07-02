# Define Terraform backend using a S3 bucket for storing the Terraform state
terraform {
  backend "s3" {
    bucket = "terraform-state-my-bucket1122"
    key    = "zero-downtime-deployment-example/live/prod/services/webserver-cluster/terraform.tfstate"
    region = "ap-east-1"
  }
}
