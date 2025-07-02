# Configure the AWS provider
provider "aws" {
  region = "ap-east-1"
}

# Create a S3 bucket
resource "aws_s3_bucket" "terraform_state" {
  bucket		  = "${var.bucket_name}"
  
  versioning {
    enabled = true
  }  
  
  lifecycle {
    prevent_destroy = true
  }
}
