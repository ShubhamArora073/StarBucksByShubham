################################################################################
# Terraform Backend Configuration
# 
# This file sets up remote state storage in S3 with DynamoDB locking.
# The backend resources were created by running setup-backend.sh
################################################################################

terraform {
  backend "s3" {
    bucket         = "starbucks-shubham-terraform-state"
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "starbucks-terraform-locks"
  }
}
