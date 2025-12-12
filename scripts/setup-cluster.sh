#!/bin/bash
################################################################################
# Starbucks EKS Cluster Setup Script
# 
# This script automates the deployment of the EKS infrastructure
# Usage: ./setup-cluster.sh [dev|prod]
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default environment
ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Starbucks EKS Cluster Setup${NC}"
echo -e "${BLUE}  Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "${BLUE}========================================${NC}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Use: dev, staging, or prod${NC}"
    exit 1
fi

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 is installed${NC}"
}

check_command "aws"
check_command "terraform"
check_command "kubectl"
check_command "helm"

# Check AWS credentials
echo -e "\n${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region || echo "ap-south-1")
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ AWS Region: ${AWS_REGION}${NC}"

# Navigate to terraform directory
cd "${TERRAFORM_DIR}"

# Initialize Terraform
echo -e "\n${YELLOW}Initializing Terraform...${NC}"
terraform init

# Select workspace or create if not exists
echo -e "\n${YELLOW}Selecting Terraform workspace: ${ENVIRONMENT}${NC}"
terraform workspace select ${ENVIRONMENT} 2>/dev/null || terraform workspace new ${ENVIRONMENT}

# Validate configuration
echo -e "\n${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "\n${YELLOW}Creating Terraform plan...${NC}"
terraform plan \
    -var-file="environments/${ENVIRONMENT}/terraform.tfvars" \
    -out="tfplan-${ENVIRONMENT}"

# Confirm deployment
echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Review the plan above carefully!${NC}"
echo -e "${YELLOW}========================================${NC}"
read -p "Do you want to apply this plan? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 0
fi

# Apply configuration
echo -e "\n${YELLOW}Applying Terraform configuration...${NC}"
terraform apply "tfplan-${ENVIRONMENT}"

# Get cluster name
CLUSTER_NAME=$(terraform output -raw cluster_name)

# Configure kubectl
echo -e "\n${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

# Verify cluster access
echo -e "\n${YELLOW}Verifying cluster access...${NC}"
kubectl get nodes

# Create namespaces
echo -e "\n${YELLOW}Creating Kubernetes namespaces...${NC}"
kubectl apply -f "${SCRIPT_DIR}/../k8s/namespaces/"

# Display outputs
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${BLUE}Cluster Information:${NC}"
terraform output

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. Deploy DevOps stack: ${YELLOW}./deploy-devops.sh${NC}"
echo -e "2. Deploy Monitoring: ${YELLOW}./deploy-monitoring.sh${NC}"
echo -e "3. Deploy Application: ${YELLOW}./deploy-app.sh${NC}"

echo -e "\n${GREEN}Useful Commands:${NC}"
echo -e "kubectl get nodes"
echo -e "kubectl get pods -A"
echo -e "$(terraform output -raw configure_kubectl)"

