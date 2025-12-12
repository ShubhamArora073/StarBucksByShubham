#!/bin/bash
################################################################################
# DevOps Stack Deployment Script
# Deploys Jenkins, SonarQube, and Trivy on EKS
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="${SCRIPT_DIR}/../k8s"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  DevOps Stack Deployment${NC}"
echo -e "${BLUE}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $1 is installed${NC}"
}

check_command "kubectl"
check_command "helm"

# Verify cluster connection
echo -e "\n${YELLOW}Verifying cluster connection...${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster${NC}"
    echo -e "${YELLOW}Run: aws eks update-kubeconfig --region ap-south-1 --name starbucks-dev${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"

# Get Jenkins IAM Role ARN from Terraform
echo -e "\n${YELLOW}Getting IAM role ARN...${NC}"
cd "${TERRAFORM_DIR}"
JENKINS_ROLE_ARN=$(terraform output -raw jenkins_role_arn 2>/dev/null || echo "")
if [[ -z "$JENKINS_ROLE_ARN" ]]; then
    echo -e "${YELLOW}Warning: Could not get Jenkins role ARN from Terraform${NC}"
    echo -e "${YELLOW}Using default service account without IRSA${NC}"
fi
echo -e "${GREEN}✓ Jenkins Role ARN: ${JENKINS_ROLE_ARN}${NC}"

cd "${SCRIPT_DIR}"

# Step 1: Create GP3 Storage Class
echo -e "\n${YELLOW}Step 1: Creating GP3 Storage Class...${NC}"
kubectl apply -f "${K8S_DIR}/devops/storage-class.yaml"
echo -e "${GREEN}✓ Storage class created${NC}"

# Step 2: Deploy Jenkins RBAC and Secrets
echo -e "\n${YELLOW}Step 2: Deploying Jenkins RBAC and Secrets...${NC}"
kubectl apply -f "${K8S_DIR}/devops/jenkins/secrets.yaml"
kubectl apply -f "${K8S_DIR}/devops/jenkins/rbac.yaml"

# Patch service account with IRSA annotation if ARN exists
if [[ -n "$JENKINS_ROLE_ARN" ]]; then
    echo -e "${YELLOW}Patching Jenkins service account with IRSA...${NC}"
    kubectl annotate serviceaccount jenkins -n devops \
        eks.amazonaws.com/role-arn="${JENKINS_ROLE_ARN}" \
        --overwrite
fi
echo -e "${GREEN}✓ Jenkins RBAC configured${NC}"

# Step 3: Add Helm repos
echo -e "\n${YELLOW}Step 3: Adding Helm repositories...${NC}"
helm repo add jenkins https://charts.jenkins.io 2>/dev/null || true
helm repo add aqua https://aquasecurity.github.io/helm-charts/ 2>/dev/null || true
helm repo update
echo -e "${GREEN}✓ Helm repos updated${NC}"

# Step 4: Deploy Jenkins
echo -e "\n${YELLOW}Step 4: Deploying Jenkins...${NC}"
helm upgrade --install jenkins jenkins/jenkins \
    --namespace devops \
    --values "${K8S_DIR}/devops/jenkins/values.yaml" \
    --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${JENKINS_ROLE_ARN}" \
    --timeout 10m \
    --wait

echo -e "${GREEN}✓ Jenkins deployed${NC}"

# Step 5: Deploy SonarQube
echo -e "\n${YELLOW}Step 5: Deploying SonarQube...${NC}"
kubectl apply -f "${K8S_DIR}/devops/sonarqube/sonarqube-standalone.yaml"
echo -e "${GREEN}✓ SonarQube deployed${NC}"

# Step 6: Deploy Trivy Operator
echo -e "\n${YELLOW}Step 6: Deploying Trivy Operator...${NC}"
helm upgrade --install trivy-operator aqua/trivy-operator \
    --namespace trivy-system \
    --create-namespace \
    --values "${K8S_DIR}/devops/trivy/values.yaml" \
    --timeout 5m \
    --wait
echo -e "${GREEN}✓ Trivy Operator deployed${NC}"

# Step 7: Create Ingress for Jenkins
echo -e "\n${YELLOW}Step 7: Creating Ingress resources...${NC}"
kubectl apply -f "${K8S_DIR}/devops/jenkins/jenkins-ingress.yaml"
echo -e "${GREEN}✓ Ingress created${NC}"

# Wait for deployments
echo -e "\n${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/jenkins -n devops --timeout=300s || true
kubectl rollout status deployment/sonarqube -n devops --timeout=300s || true
kubectl rollout status deployment/sonarqube-postgresql -n devops --timeout=300s || true

# Get access information
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  DevOps Stack Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# Get Jenkins admin password
echo -e "\n${BLUE}Jenkins Credentials:${NC}"
echo -e "Username: ${YELLOW}admin${NC}"
JENKINS_PASSWORD=$(kubectl get secret jenkins-admin-secret -n devops -o jsonpath="{.data.jenkins-admin-password}" | base64 -d)
echo -e "Password: ${YELLOW}${JENKINS_PASSWORD}${NC}"

# Get Load Balancer URLs
echo -e "\n${BLUE}Getting Load Balancer URLs (may take 2-3 minutes)...${NC}"
sleep 10

JENKINS_LB=$(kubectl get ingress jenkins-ingress -n devops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
SONAR_LB=$(kubectl get ingress sonarqube-ingress -n devops -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo -e "\n${BLUE}Access URLs:${NC}"
echo -e "Jenkins:   ${YELLOW}http://${JENKINS_LB}${NC}"
echo -e "SonarQube: ${YELLOW}http://${SONAR_LB}${NC}"

echo -e "\n${BLUE}SonarQube Credentials:${NC}"
echo -e "Username: ${YELLOW}admin${NC}"
echo -e "Password: ${YELLOW}admin${NC} (change on first login)"

echo -e "\n${BLUE}Useful Commands:${NC}"
echo -e "kubectl get pods -n devops"
echo -e "kubectl get ingress -n devops"
echo -e "kubectl logs -n devops -l app.kubernetes.io/name=jenkins -f"

echo -e "\n${YELLOW}Note: ALB provisioning may take 2-5 minutes. Check status with:${NC}"
echo -e "kubectl get ingress -n devops -w"

