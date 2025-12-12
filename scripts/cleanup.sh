#!/bin/bash
################################################################################
# Starbucks EKS Cluster Cleanup Script
# 
# This script destroys all resources created by Terraform
# Usage: ./cleanup.sh [dev|prod]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

echo -e "${RED}========================================${NC}"
echo -e "${RED}  ⚠️  DANGER: Cluster Destruction${NC}"
echo -e "${RED}  Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "${RED}========================================${NC}"

echo -e "\n${RED}This will PERMANENTLY DELETE:${NC}"
echo -e "  - EKS Cluster and all nodes"
echo -e "  - VPC and networking resources"
echo -e "  - ECR repository and images"
echo -e "  - S3 backup bucket"
echo -e "  - All deployed applications"

echo -e "\n${YELLOW}This action cannot be undone!${NC}"
read -p "Type 'DESTROY' to confirm: " CONFIRM

if [[ "$CONFIRM" != "DESTROY" ]]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

# Navigate to terraform directory
cd "${TERRAFORM_DIR}"

# Select workspace
echo -e "\n${YELLOW}Selecting Terraform workspace: ${ENVIRONMENT}${NC}"
terraform workspace select ${ENVIRONMENT}

# Get cluster name for cleanup
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")

if [[ -n "$CLUSTER_NAME" ]]; then
    # Delete all Helm releases first
    echo -e "\n${YELLOW}Removing Helm releases...${NC}"
    helm list -A --short | xargs -r helm uninstall -n kube-system 2>/dev/null || true
    
    # Delete all LoadBalancer services (to cleanup ALB/NLB)
    echo -e "\n${YELLOW}Removing LoadBalancer services...${NC}"
    kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer 2>/dev/null || true
    
    # Wait for LB cleanup
    echo -e "${YELLOW}Waiting for LoadBalancers to be deleted (60s)...${NC}"
    sleep 60
fi

# Empty S3 bucket before destruction
echo -e "\n${YELLOW}Emptying S3 bucket...${NC}"
BUCKET_NAME="${CLUSTER_NAME}-jenkins-backups"
aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null || true

# Destroy infrastructure
echo -e "\n${YELLOW}Destroying Terraform resources...${NC}"
terraform destroy \
    -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
    -auto-approve

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Note: The Terraform backend (S3 bucket and DynamoDB table)${NC}"
echo -e "${YELLOW}was NOT deleted. To remove them, run:${NC}"
echo -e "aws s3 rb s3://starbucks-shubham-terraform-state --force"
echo -e "aws dynamodb delete-table --table-name starbucks-terraform-locks"

