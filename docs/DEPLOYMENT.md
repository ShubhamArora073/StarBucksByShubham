# Starbucks EKS Deployment Guide

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Phase 1: Infrastructure Foundation](#phase-1-infrastructure-foundation)
- [Phase 2: DevOps Stack](#phase-2-devops-stack)
- [Phase 3: Monitoring Stack](#phase-3-monitoring-stack)
- [Phase 4: Application Deployment](#phase-4-application-deployment)
- [CI/CD Pipeline Setup](#cicd-pipeline-setup)
- [Accessing Services](#accessing-services)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)

---

## Prerequisites

### Required Tools

| Tool | Version | Installation |
|------|---------|--------------|
| AWS CLI | v2.x | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | >= 1.5.0 | [Install Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| kubectl | >= 1.28 | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| Helm | >= 3.x | [Install Guide](https://helm.sh/docs/intro/install/) |
| Docker | >= 24.x | [Install Guide](https://docs.docker.com/get-docker/) |

### AWS Credentials

```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-south-1"

# Verify credentials
aws sts get-caller-identity
```

### Required IAM Permissions

- AmazonEKSClusterPolicy
- AmazonEKSWorkerNodePolicy
- AmazonVPCFullAccess
- IAMFullAccess
- AmazonEC2FullAccess
- AmazonS3FullAccess
- AmazonECRFullAccess
- AmazonDynamoDBFullAccess
- ElasticLoadBalancingFullAccess

---

## Quick Start

```bash
# Clone the repository
cd StarBucksByShubham

# Make scripts executable
chmod +x scripts/*.sh

# 1. Setup Terraform backend (one-time)
./scripts/setup-backend.sh

# 2. Deploy EKS cluster
./scripts/setup-cluster.sh dev

# 3. Deploy DevOps tools
./scripts/deploy-devops.sh

# 4. Deploy Monitoring stack
./scripts/deploy-monitoring.sh

# 5. Deploy Starbucks application
./scripts/deploy-starbucks.sh
```

---

## Phase 1: Infrastructure Foundation

### 1.1 Setup Terraform Backend

```bash
cd StarBucksByShubham/scripts
./setup-backend.sh
```

This creates:
- S3 bucket for Terraform state
- DynamoDB table for state locking

### 1.2 Deploy EKS Cluster

```bash
# For development
./setup-cluster.sh dev

# For production
./setup-cluster.sh prod
```

### 1.3 Verify Cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name starbucks-dev

# Verify nodes
kubectl get nodes

# Verify system components
kubectl get pods -n kube-system
```

### Infrastructure Components

| Component | Description |
|-----------|-------------|
| VPC | 10.0.0.0/16 with public/private subnets across 3 AZs |
| EKS Cluster | Kubernetes 1.30 with managed node groups |
| Node Groups | DevOps, Application, Monitoring nodes |
| ALB Controller | AWS Load Balancer Controller for Ingress |
| Cluster Autoscaler | Automatic node scaling |
| EBS CSI Driver | Persistent volume support |

---

## Phase 2: DevOps Stack

### 2.1 Create Namespaces

```bash
kubectl apply -f k8s/namespaces/
```

### 2.2 Deploy Jenkins

```bash
# Deploy storage class
kubectl apply -f k8s/devops/storage-class.yaml

# Deploy Jenkins RBAC
kubectl apply -f k8s/devops/jenkins/rbac.yaml
kubectl apply -f k8s/devops/jenkins/secrets.yaml

# Install Jenkins via Helm
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm upgrade --install jenkins jenkins/jenkins \
  -n devops \
  -f k8s/devops/jenkins/values.yaml \
  --wait --timeout 10m

# Deploy Ingress
kubectl apply -f k8s/devops/jenkins/jenkins-ingress.yaml
```

### 2.3 Deploy SonarQube

```bash
# Deploy SonarQube
kubectl apply -f k8s/devops/sonarqube/sonarqube-standalone.yaml

# Deploy Ingress
kubectl apply -f k8s/devops/sonarqube/sonarqube-ingress.yaml
```

### 2.4 Deploy Trivy Operator

```bash
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

helm upgrade --install trivy-operator aqua/trivy-operator \
  -n devops \
  -f k8s/devops/trivy/values.yaml
```

### 2.5 Get Jenkins Password

```bash
kubectl exec -n devops jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword
```

---

## Phase 3: Monitoring Stack

### 3.1 Deploy Prometheus Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s/monitoring/kube-prometheus-stack/values.yaml \
  --wait --timeout 10m
```

### 3.2 Deploy Custom Dashboards

```bash
kubectl apply -f k8s/monitoring/dashboards/
```

### 3.3 Deploy ServiceMonitors

```bash
kubectl apply -f k8s/monitoring/servicemonitors/
```

### 3.4 Deploy Alert Rules

```bash
kubectl apply -f k8s/monitoring/alertrules/
```

### 3.5 Deploy Monitoring Ingress

```bash
kubectl apply -f k8s/monitoring/monitoring-ingress.yaml
```

### Grafana Credentials

- **Username:** admin
- **Password:** StarbucksAdmin2024!

---

## Phase 4: Application Deployment

### 4.1 Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name starbucks \
  --region ap-south-1 \
  --image-scanning-configuration scanOnPush=true
```

### 4.2 Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin 245279657609.dkr.ecr.ap-south-1.amazonaws.com

# Build for AMD64 (EKS nodes)
docker buildx build --platform linux/amd64 \
  -f StarBucksByShubham/docker/Dockerfile \
  -t 245279657609.dkr.ecr.ap-south-1.amazonaws.com/starbucks:latest \
  --push .
```

### 4.3 Deploy Application

```bash
kubectl apply -f k8s/starbucks/
```

### 4.4 Verify Deployment

```bash
# Check pods
kubectl get pods -n starbucks

# Check services
kubectl get svc -n starbucks

# Check ingress
kubectl get ingress -n starbucks

# Check HPA
kubectl get hpa -n starbucks
```

---

## CI/CD Pipeline Setup

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│   Jenkins   │────▶│     ECR     │────▶│     EKS     │
│             │     │             │     │             │     │             │
└─────────────┘     └──────┬──────┘     └─────────────┘     └─────────────┘
                          │
                    ┌─────┴─────┐
                    │           │
              ┌─────▼─────┐ ┌───▼───┐
              │ SonarQube │ │ Trivy │
              └───────────┘ └───────┘
```

### Jenkins Pipeline Configuration

#### Step 1: Configure Jenkins Credentials

Navigate to **Jenkins > Manage Jenkins > Credentials** and add:

| Credential ID | Type | Description |
|--------------|------|-------------|
| `github-token` | Username with password | GitHub PAT for repository access |
| `sonar-token` | Secret text | SonarQube authentication token |
| `aws-credentials` | AWS Credentials | AWS access for ECR/EKS (or use IRSA) |

#### Step 2: Configure SonarQube in Jenkins

1. Install **SonarQube Scanner** plugin in Jenkins
2. Navigate to **Manage Jenkins > Configure System**
3. Add SonarQube server:
   - Name: `SonarQube`
   - Server URL: `http://sonarqube-service.devops.svc.cluster.local:9000`
   - Server authentication token: `sonar-token`

#### Step 3: Create Jenkins Pipeline Job

1. Create a new **Pipeline** job
2. Configure Pipeline from SCM:
   - SCM: Git
   - Repository URL: `https://github.com/your-org/starbucks-kubernetes.git`
   - Credentials: `github-token`
   - Branch: `*/main`
   - Script Path: `StarBucksByShubham/ci-cd/Jenkinsfile`

### Jenkinsfile Pipeline Stages

```groovy
pipeline {
    agent {
        kubernetes {
            // Dynamic Kubernetes agents
        }
    }
    
    stages {
        stage('Checkout')           // Clone repository
        stage('Install Dependencies') // npm ci
        stage('Run Tests')          // npm test with coverage
        stage('SonarQube Analysis') // Code quality scan
        stage('Security Scan - Source') // Trivy filesystem scan
        stage('Build Application')  // npm run build
        stage('Build Docker Image') // Multi-stage Docker build
        stage('Security Scan - Image') // Trivy image scan
        stage('Push to ECR')        // Push to AWS ECR
        stage('Deploy to EKS')      // kubectl apply
        stage('Verify Deployment')  // Health checks
    }
}
```

### SonarQube Configuration

#### Create Project

1. Login to SonarQube (`admin/admin`, change on first login)
2. Create new project: `starbucks`
3. Generate authentication token
4. Add token to Jenkins credentials

#### Quality Gate

Configure quality gate rules:
- Coverage > 50%
- Duplications < 10%
- Bugs = 0
- Vulnerabilities = 0
- Code Smells < 50

### GitHub Webhook Setup

1. Go to your GitHub repository > Settings > Webhooks
2. Add webhook:
   - Payload URL: `http://<jenkins-url>:8080/github-webhook/`
   - Content type: `application/json`
   - Events: Push events, Pull request events
3. Save webhook

### Complete CI/CD Flow

```
1. Developer pushes code to GitHub
           │
           ▼
2. GitHub webhook triggers Jenkins
           │
           ▼
3. Jenkins pulls latest code
           │
           ▼
4. Install dependencies (npm ci)
           │
           ▼
5. Run unit tests with coverage
           │
           ▼
6. SonarQube analysis
           │
           ▼
7. Quality Gate check
           │
           ▼
8. Trivy filesystem scan
           │
           ▼
9. Build production assets
           │
           ▼
10. Build Docker image (multi-stage)
           │
           ▼
11. Trivy image scan
           │
           ▼
12. Push to ECR
           │
           ▼
13. Deploy to EKS (kubectl set image / apply)
           │
           ▼
14. Rollout status verification
           │
           ▼
15. Health check validation
           │
           ▼
16. Notification (Success/Failure)
```

### Environment Variables

```groovy
environment {
    AWS_REGION = 'ap-south-1'
    AWS_ACCOUNT_ID = '245279657609'
    ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_REPOSITORY = 'starbucks'
    EKS_CLUSTER_NAME = 'starbucks-dev'
    K8S_NAMESPACE = 'starbucks'
    SONAR_HOST_URL = 'http://sonarqube-service.devops.svc.cluster.local:9000'
    IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.take(7)}"
}
```

### Deployment Strategies

#### Rolling Update (Default)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

#### Blue-Green Deployment

```bash
# Deploy new version with different label
kubectl apply -f deployment-green.yaml

# Switch service selector
kubectl patch svc starbucks-service -p '{"spec":{"selector":{"version":"green"}}}'

# Cleanup old version
kubectl delete deployment starbucks-blue
```

#### Canary Deployment

```bash
# Deploy canary (10% traffic)
kubectl apply -f deployment-canary.yaml

# Verify metrics in Grafana
# Gradually increase traffic by scaling canary

# Full rollout
kubectl scale deployment starbucks-canary --replicas=0
kubectl scale deployment starbucks-app --replicas=4
```

---

## Accessing Services

### DNS/Hosts Configuration

Add to `/etc/hosts`:

```
# Starbucks EKS - Application
13.127.44.63    starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com

# Starbucks EKS - DevOps Stack
65.0.112.228    k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com

# Starbucks EKS - Monitoring Stack
13.126.85.193   k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com
```

### Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Starbucks App** | http://starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com | N/A |
| **Jenkins** | http://k8s-starbucksdevops-...:8080 | admin / (see kubectl command) |
| **SonarQube** | http://k8s-starbucksdevops-...:9000 | admin / admin |
| **Grafana** | http://k8s-starbucksmonitori-...:3000 | admin / StarbucksAdmin2024! |
| **Prometheus** | http://k8s-starbucksmonitori-...:9090 | N/A |
| **AlertManager** | http://k8s-starbucksmonitori-...:9093 | N/A |

---

## Troubleshooting

### Common Issues

#### Pods Not Starting

```bash
# Check pod events
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name> --previous

# Check resource limits
kubectl describe quota -n <namespace>
```

#### ALB Not Provisioning

```bash
# Check ALB controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify IAM role
kubectl describe sa -n kube-system aws-load-balancer-controller

# Check ingress events
kubectl describe ingress -n <namespace> <ingress-name>
```

#### Image Pull Errors

```bash
# Verify ECR login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 245279657609.dkr.ecr.ap-south-1.amazonaws.com

# Check image exists
aws ecr describe-images --repository-name starbucks --region ap-south-1
```

#### Jenkins Pipeline Fails

```bash
# Check Jenkins agent logs
kubectl logs -n devops -l jenkins/label=jenkins-agent

# Verify Jenkins RBAC
kubectl auth can-i --list --as=system:serviceaccount:devops:jenkins -n starbucks
```

#### SonarQube Connection Issues

```bash
# Check SonarQube pod
kubectl get pods -n devops -l app=sonarqube

# Test connectivity from Jenkins
kubectl exec -n devops jenkins-0 -- curl -s http://sonarqube-service.devops.svc.cluster.local:9000/api/system/status
```

### Useful Commands

```bash
# View all resources in namespace
kubectl get all -n <namespace>

# Port forward for debugging
kubectl port-forward -n devops svc/jenkins 8080:8080

# View resource usage
kubectl top nodes
kubectl top pods -A

# View cluster events
kubectl get events --sort-by='.lastTimestamp' -A

# Force pod restart
kubectl rollout restart deployment/<name> -n <namespace>
```

---

## Cleanup

### Delete Application

```bash
kubectl delete -f k8s/starbucks/
```

### Delete Monitoring Stack

```bash
helm uninstall prometheus -n monitoring
kubectl delete -f k8s/monitoring/
```

### Delete DevOps Stack

```bash
helm uninstall jenkins -n devops
helm uninstall trivy-operator -n devops
kubectl delete -f k8s/devops/
```

### Delete EKS Cluster

```bash
./scripts/cleanup.sh dev
```

### Delete ECR Repository

```bash
aws ecr delete-repository --repository-name starbucks --region ap-south-1 --force
```

### Delete Terraform Backend (Final Cleanup)

```bash
aws s3 rb s3://starbucks-shubham-terraform-state --force
aws dynamodb delete-table --table-name starbucks-terraform-locks
```

⚠️ **Warning**: This permanently deletes all resources and data.

---

## Security Best Practices

### Pod Security

- Non-root containers
- Read-only root filesystem where possible
- Security contexts with dropped capabilities
- Network policies for namespace isolation

### Secrets Management

- Use AWS Secrets Manager or Kubernetes secrets
- Encrypt secrets at rest (EKS default)
- Rotate credentials regularly

### Image Security

- Trivy scans on every build
- Use minimal base images (Alpine)
- Pin image versions (avoid `latest` in production)
- ECR image scanning enabled

### Network Security

- Private subnets for worker nodes
- Security groups with minimal required ports
- ALB with WAF (optional)
- VPC Flow Logs enabled

---

## Support

For issues and questions:
- Check the troubleshooting section above
- Review Kubernetes events and logs
- Consult AWS and Kubernetes documentation

**Author:** Shubham Arora  
**Last Updated:** December 2024
