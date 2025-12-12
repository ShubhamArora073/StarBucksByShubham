#!/bin/bash
################################################################################
# Terraform Backend Setup Script
# 
# This script creates the S3 bucket and DynamoDB table for Terraform state
# Run this ONCE before setting up the cluster
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BUCKET_NAME="starbucks-shubham-terraform-state"
DYNAMODB_TABLE="starbucks-terraform-locks"
REGION="ap-south-1"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Terraform Backend Setup${NC}"
echo -e "${BLUE}========================================${NC}"

# Check AWS credentials
echo -e "\n${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT_ID}${NC}"

# Create S3 bucket
echo -e "\n${YELLOW}Creating S3 bucket for Terraform state...${NC}"
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo -e "${GREEN}✓ S3 bucket already exists${NC}"
else
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${REGION}" \
        --create-bucket-configuration LocationConstraint="${REGION}"
    echo -e "${GREEN}✓ S3 bucket created${NC}"
fi

# Enable versioning
echo -e "\n${YELLOW}Enabling bucket versioning...${NC}"
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo -e "\n${YELLOW}Enabling bucket encryption...${NC}"
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo -e "\n${YELLOW}Blocking public access...${NC}"
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'
echo -e "${GREEN}✓ Public access blocked${NC}"

# Create DynamoDB table
echo -e "\n${YELLOW}Creating DynamoDB table for state locking...${NC}"
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" 2>/dev/null; then
    echo -e "${GREEN}✓ DynamoDB table already exists${NC}"
else
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}"
    
    # Wait for table to be active
    echo -e "${YELLOW}Waiting for table to be active...${NC}"
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Backend Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${BLUE}Backend Configuration:${NC}"
echo -e "S3 Bucket: ${YELLOW}${BUCKET_NAME}${NC}"
echo -e "DynamoDB Table: ${YELLOW}${DYNAMODB_TABLE}${NC}"
echo -e "Region: ${YELLOW}${REGION}${NC}"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. Uncomment the backend configuration in ${YELLOW}terraform/backend.tf${NC}"
echo -e "2. Run ${YELLOW}terraform init${NC} to migrate state to S3"
echo -e "3. Run ${YELLOW}./setup-cluster.sh dev${NC} to create the cluster"

