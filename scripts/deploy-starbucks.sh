#!/bin/bash
# =============================================================================
# Starbucks Application Deployment Script
# Deploys the Starbucks React application to EKS
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-ap-south-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-245279657609}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY="starbucks"
IMAGE_TAG="${IMAGE_TAG:-latest}"
NAMESPACE="starbucks"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PARENT_ROOT="$(dirname "$PROJECT_ROOT")"

echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Starbucks Application Deployment${NC}"
echo -e "${BLUE}=============================================${NC}"

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Check required tools
echo -e "\n${YELLOW}Checking required tools...${NC}"
check_command "kubectl"
check_command "aws"
check_command "docker"

# Verify kubectl connection
echo -e "\n${YELLOW}Verifying Kubernetes connection...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Please run: aws eks update-kubeconfig --region ${AWS_REGION} --name <cluster-name>${NC}"
    exit 1
fi

# Check if namespace exists
echo -e "\n${YELLOW}Checking namespace...${NC}"
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo -e "${YELLOW}Creating namespace ${NAMESPACE}...${NC}"
    kubectl apply -f "${PROJECT_ROOT}/k8s/namespaces/starbucks.yaml"
else
    echo -e "${GREEN}Namespace ${NAMESPACE} exists${NC}"
fi

# Build and push Docker image
build_and_push() {
    echo -e "\n${YELLOW}Building Docker image...${NC}"
    
    # Login to ECR
    echo -e "${YELLOW}Logging into ECR...${NC}"
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    # Create ECR repository if not exists
    echo -e "${YELLOW}Ensuring ECR repository exists...${NC}"
    aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} 2>/dev/null || \
        aws ecr create-repository --repository-name ${ECR_REPOSITORY} --region ${AWS_REGION}
    
    # Build the image from parent directory (where source code is)
    echo -e "${YELLOW}Building Docker image...${NC}"
    cd "${PARENT_ROOT}"
    
    # Copy nginx config to expected location
    mkdir -p docker
    cp "${PROJECT_ROOT}/docker/nginx.conf" docker/nginx.conf
    
    docker build \
        -f "${PROJECT_ROOT}/docker/Dockerfile" \
        -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} \
        -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
        .
    
    # Push the image
    echo -e "${YELLOW}Pushing image to ECR...${NC}"
    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
    
    echo -e "${GREEN}Image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}${NC}"
    
    # Cleanup
    rm -rf docker
}

# Deploy to Kubernetes
deploy() {
    echo -e "\n${YELLOW}Deploying to Kubernetes...${NC}"
    
    # Apply all manifests
    echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"
    kubectl apply -f "${PROJECT_ROOT}/k8s/starbucks/"
    
    # Wait for deployment
    echo -e "${YELLOW}Waiting for deployment to be ready...${NC}"
    kubectl rollout status deployment/starbucks-app -n ${NAMESPACE} --timeout=300s
    
    echo -e "${GREEN}Deployment successful!${NC}"
}

# Get deployment status
status() {
    echo -e "\n${YELLOW}Deployment Status:${NC}"
    echo -e "\n${BLUE}Pods:${NC}"
    kubectl get pods -n ${NAMESPACE} -l app=starbucks -o wide
    
    echo -e "\n${BLUE}Services:${NC}"
    kubectl get svc -n ${NAMESPACE} -l app=starbucks
    
    echo -e "\n${BLUE}Ingress:${NC}"
    kubectl get ingress -n ${NAMESPACE}
    
    echo -e "\n${BLUE}HPA:${NC}"
    kubectl get hpa -n ${NAMESPACE}
    
    # Get ALB URL
    echo -e "\n${BLUE}Application URL:${NC}"
    ALB_URL=$(kubectl get ingress starbucks-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Pending...")
    if [ -n "$ALB_URL" ] && [ "$ALB_URL" != "Pending..." ]; then
        echo -e "${GREEN}http://${ALB_URL}${NC}"
    else
        echo -e "${YELLOW}ALB URL is still being provisioned...${NC}"
    fi
}

# Main script
case "${1:-all}" in
    build)
        build_and_push
        ;;
    deploy)
        deploy
        ;;
    status)
        status
        ;;
    all)
        build_and_push
        deploy
        status
        ;;
    *)
        echo "Usage: $0 {build|deploy|status|all}"
        echo ""
        echo "Commands:"
        echo "  build   - Build and push Docker image to ECR"
        echo "  deploy  - Deploy application to Kubernetes"
        echo "  status  - Show deployment status"
        echo "  all     - Build, deploy, and show status"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=============================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}=============================================${NC}"

