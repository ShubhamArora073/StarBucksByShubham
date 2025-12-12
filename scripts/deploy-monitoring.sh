#!/bin/bash
################################################################################
# Monitoring Stack Deployment Script
# Deploys Prometheus, Grafana, and AlertManager on EKS
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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Monitoring Stack Deployment${NC}"
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
    exit 1
fi
echo -e "${GREEN}✓ Connected to cluster${NC}"

# Step 1: Add Helm repos
echo -e "\n${YELLOW}Step 1: Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update
echo -e "${GREEN}✓ Helm repos updated${NC}"

# Step 2: Create monitoring namespace if not exists
echo -e "\n${YELLOW}Step 2: Ensuring monitoring namespace exists...${NC}"
kubectl get namespace monitoring &>/dev/null || kubectl create namespace monitoring
echo -e "${GREEN}✓ Namespace ready${NC}"

# Step 3: Deploy kube-prometheus-stack
echo -e "\n${YELLOW}Step 3: Deploying kube-prometheus-stack...${NC}"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values "${K8S_DIR}/monitoring/kube-prometheus-stack/values.yaml" \
    --timeout 15m \
    --wait

echo -e "${GREEN}✓ Prometheus stack deployed${NC}"

# Step 4: Apply custom dashboards
echo -e "\n${YELLOW}Step 4: Applying custom dashboards...${NC}"
kubectl apply -f "${K8S_DIR}/monitoring/dashboards/starbucks-dashboard-cm.yaml"
echo -e "${GREEN}✓ Custom dashboards applied${NC}"

# Step 5: Apply ServiceMonitors
echo -e "\n${YELLOW}Step 5: Applying ServiceMonitors...${NC}"
kubectl apply -f "${K8S_DIR}/monitoring/servicemonitors/" 2>/dev/null || echo "ServiceMonitors directory may be empty"
echo -e "${GREEN}✓ ServiceMonitors applied${NC}"

# Step 6: Apply Alert Rules
echo -e "\n${YELLOW}Step 6: Applying Alert Rules...${NC}"
kubectl apply -f "${K8S_DIR}/monitoring/alertrules/"
echo -e "${GREEN}✓ Alert rules applied${NC}"

# Step 7: Create Ingress
echo -e "\n${YELLOW}Step 7: Creating Ingress resources...${NC}"
kubectl apply -f "${K8S_DIR}/monitoring/monitoring-ingress.yaml"
echo -e "${GREEN}✓ Ingress created${NC}"

# Wait for deployments
echo -e "\n${YELLOW}Waiting for deployments to be ready...${NC}"
kubectl rollout status deployment/prometheus-grafana -n monitoring --timeout=300s || true
kubectl rollout status statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring --timeout=300s || true
kubectl rollout status statefulset/alertmanager-prometheus-kube-prometheus-alertmanager -n monitoring --timeout=300s || true

# Get access information
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Monitoring Stack Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"

# Get Load Balancer URL
echo -e "\n${YELLOW}Waiting for ALB to provision (60s)...${NC}"
sleep 60

MONITORING_LB=$(kubectl get ingress grafana-ingress -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")

echo -e "\n${BLUE}Access URLs:${NC}"
echo -e "Grafana:      ${YELLOW}http://${MONITORING_LB}:3000${NC}"
echo -e "Prometheus:   ${YELLOW}http://${MONITORING_LB}:9090${NC}"
echo -e "AlertManager: ${YELLOW}http://${MONITORING_LB}:9093${NC}"

echo -e "\n${BLUE}Grafana Credentials:${NC}"
echo -e "Username: ${YELLOW}admin${NC}"
echo -e "Password: ${YELLOW}GrafanaAdmin@2024${NC}"

echo -e "\n${BLUE}Useful Commands:${NC}"
echo -e "kubectl get pods -n monitoring"
echo -e "kubectl get ingress -n monitoring"
echo -e "kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f"

echo -e "\n${YELLOW}Note: If ALB is not ready, check with:${NC}"
echo -e "kubectl get ingress -n monitoring -w"

echo -e "\n${YELLOW}Add ALB IP to /etc/hosts if needed:${NC}"
echo -e "nslookup ${MONITORING_LB} 8.8.8.8"

