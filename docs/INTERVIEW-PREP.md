# 🎯 DevOps Interview Preparation Guide
## Based on Starbucks EKS Project

*This document covers real-world scenarios, troubleshooting experiences, and technical depth from building a production-grade CI/CD pipeline on AWS EKS.*

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Kubernetes & EKS](#kubernetes--eks)
3. [CI/CD Pipeline (Jenkins)](#cicd-pipeline-jenkins)
4. [Docker & Containerization](#docker--containerization)
5. [Terraform & Infrastructure as Code](#terraform--infrastructure-as-code)
6. [AWS Services](#aws-services)
7. [Monitoring & Observability](#monitoring--observability)
8. [Security](#security)
9. [Troubleshooting Scenarios](#troubleshooting-scenarios)
10. [Behavioral Questions](#behavioral-questions)

---

## 🚀 Project Overview

### Describe the project you worked on

> "I built a complete DevOps infrastructure for deploying a Starbucks React application on Amazon EKS. The project included:
> - **Infrastructure as Code** using Terraform to provision VPC, EKS cluster, and IAM roles
> - **CI/CD Pipeline** using Jenkins running on Kubernetes with dynamic agents
> - **Monitoring Stack** with Prometheus, Grafana, and AlertManager
> - **Security Scanning** with SonarQube and Trivy
> - **GitOps-style deployments** to EKS with automated rollouts"

### What was the architecture?

```
Developer → GitHub → Jenkins (EKS) → Build → Test → Scan → ECR → Deploy to EKS → ALB → Users
                         ↓
              Prometheus/Grafana (Monitoring)
```

---

## ☸️ Kubernetes & EKS

### Q: What is the difference between EKS and self-managed Kubernetes?

| Aspect | EKS | Self-Managed |
|--------|-----|--------------|
| Control Plane | AWS managed, HA by default | You manage, configure HA |
| Upgrades | AWS handles control plane | Manual upgrades |
| Cost | $0.10/hour + nodes | Only node costs |
| Integration | Native AWS integration | Manual setup |
| Support | AWS support available | Community support |

### Q: Explain the EKS node groups you configured

```hcl
# From our Terraform configuration
eks_managed_node_groups = {
  devops = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 4
    labels         = { workload = "devops" }
  }
  application = {
    instance_types = ["t3.medium"]
    min_size       = 2
    max_size       = 6
    labels         = { workload = "application" }
  }
  monitoring = {
    instance_types = ["t3.small"]
    min_size       = 1
    max_size       = 3
    labels         = { workload = "monitoring" }
  }
}
```

**Why separate node groups?**
- **Resource isolation**: DevOps tools don't compete with application workloads
- **Cost optimization**: Different instance types based on workload needs
- **Scaling independence**: Each workload can scale independently
- **Maintenance**: Can drain/update node groups without affecting others

### Q: What Kubernetes objects did you use?

| Object | Purpose | Example from Project |
|--------|---------|---------------------|
| Deployment | Manage pod replicas | Starbucks app with 2 replicas |
| Service | Internal load balancing | ClusterIP for app, NodePort for Jenkins |
| Ingress | External access via ALB | Path-based routing to services |
| ConfigMap | Configuration data | Nginx config, app settings |
| Secret | Sensitive data | GitHub tokens, SonarQube tokens |
| HPA | Auto-scaling | Scale pods 2-6 based on CPU/Memory |
| PDB | Availability during disruptions | minAvailable: 1 |
| ServiceAccount | Pod identity | IRSA for AWS access |
| Namespace | Resource isolation | devops, monitoring, starbucks |
| ResourceQuota | Limit namespace resources | CPU/Memory limits per namespace |
| LimitRange | Default container limits | Default requests/limits |

### Q: Explain Horizontal Pod Autoscaler (HPA)

```yaml
# Our HPA configuration
spec:
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

**How it works:**
1. Metrics Server collects pod metrics
2. HPA controller checks metrics every 15 seconds
3. Calculates desired replicas: `ceil(currentReplicas × (currentMetric / targetMetric))`
4. Scales up/down respecting min/max limits

### Q: What is a Pod Disruption Budget (PDB)?

```yaml
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: starbucks
```

**Purpose:** Ensures minimum pods available during voluntary disruptions (node drain, cluster upgrade)

**Real scenario:** During EKS node group updates, PDB prevented all pods from being evicted simultaneously.

### Q: Explain the difference between ClusterIP, NodePort, and LoadBalancer

| Type | Access | Use Case |
|------|--------|----------|
| ClusterIP | Internal only | App-to-app communication |
| NodePort | External via node IP:port | Testing, non-production |
| LoadBalancer | External via cloud LB | Production traffic |

**In our project:** We used ClusterIP + ALB Ingress Controller for production-grade load balancing.

### Q: What is IRSA (IAM Roles for Service Accounts)?

**Problem:** How do pods access AWS services securely?

**Old way:** Store AWS credentials in secrets (security risk)

**IRSA way:**
1. Create IAM role with required permissions
2. Create trust policy allowing EKS OIDC provider
3. Annotate Kubernetes ServiceAccount with IAM role ARN
4. Pods using that SA automatically get temporary AWS credentials

```yaml
# ServiceAccount with IRSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/jenkins-role
```

**Benefits:**
- No long-lived credentials
- Fine-grained permissions per workload
- Automatic credential rotation
- Audit trail in CloudTrail

---

## 🔄 CI/CD Pipeline (Jenkins)

### Q: Describe your Jenkins pipeline architecture

```
Jenkins Master (StatefulSet on EKS)
         │
         ├── Dynamic Pod Agents (spawned per build)
         │   ├── node container (npm build)
         │   ├── docker container (image build)
         │   ├── aws-kubectl container (deploy)
         │   ├── trivy container (security scan)
         │   └── sonar-scanner container (code quality)
         │
         └── Persistent Storage (EBS via gp3 StorageClass)
```

### Q: Why use Kubernetes plugin for Jenkins agents?

**Benefits:**
1. **Dynamic scaling**: Agents spawn on-demand, terminate after build
2. **Resource efficiency**: No idle agents consuming resources
3. **Isolation**: Each build gets fresh environment
4. **Parallel builds**: Multiple pods can run simultaneously
5. **Cost savings**: Pay only for what you use

### Q: Explain your Jenkinsfile structure

```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
            // Pod template with multiple containers
            '''
        }
    }
    
    environment {
        // Environment variables
    }
    
    stages {
        stage('Checkout') { }
        stage('Install Dependencies') { }
        stage('Code Quality Analysis') {
            parallel {
                stage('Lint Check') { }
                stage('Unit Tests') { }
            }
        }
        stage('SonarQube Analysis') { }
        stage('Security Scan - Source') { }
        stage('Build Application') { }
        stage('Build Docker Image') { }
        stage('Security Scan - Image') { }
        stage('Push to ECR') { }
        stage('Deploy to EKS') { }
        stage('Verify Deployment') { }
        stage('Smoke Test') { }
    }
    
    post {
        success { }
        failure { }
    }
}
```

### Q: How do you handle secrets in Jenkins pipeline?

```groovy
// Using Jenkins Credentials
withCredentials([
    string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN'),
    usernamePassword(credentialsId: 'github-token', 
                     usernameVariable: 'GIT_USER', 
                     passwordVariable: 'GIT_PASS')
]) {
    sh 'echo "Token is masked: $SONAR_TOKEN"'
}
```

**Best practices:**
- Never echo credentials
- Use credential binding
- Rotate credentials regularly
- Use IRSA for AWS access (no stored credentials)

### Q: How do containers in a Jenkins pod share data?

**Workspace Volume:**
```yaml
volumes:
  - emptyDir: {}
    name: workspace-volume
```

All containers mount this volume at `/home/jenkins/agent`, enabling:
- Source code sharing between containers
- Build artifacts passed between stages
- Temporary file sharing (like ECR password)

**Challenge we solved:** `/tmp` is container-local. We moved ECR password to `${WORKSPACE}` for cross-container access.

---

## 🐳 Docker & Containerization

### Q: Explain your multi-stage Dockerfile

```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --legacy-peer-deps
COPY . .
RUN npm run build

# Stage 2: Production
FROM nginx:1.25-alpine AS production
RUN addgroup -g 1001 -S starbucks && \
    adduser -u 1001 -S starbucks -G starbucks
COPY --from=builder /app/build /usr/share/nginx/html
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
USER starbucks
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget -q -O - http://localhost:8080/health || exit 1
CMD ["nginx", "-g", "daemon off;"]
```

**Benefits:**
- **Smaller image**: ~25MB vs ~1GB with node_modules
- **Security**: No build tools in production image
- **Non-root user**: Follows least privilege principle
- **Health checks**: Kubernetes knows when container is healthy

### Q: What is the difference between COPY and ADD?

| COPY | ADD |
|------|-----|
| Simple file copy | Can extract tar files |
| Preferred for most cases | Can download from URLs |
| Predictable behavior | More "magic" behavior |

**Best practice:** Use COPY unless you specifically need ADD features.

### Q: How do you handle Docker layer caching?

```dockerfile
# ❌ Bad - invalidates cache on any file change
COPY . .
RUN npm install

# ✅ Good - only reinstalls when package.json changes
COPY package*.json ./
RUN npm install
COPY . .
```

### Q: What platform did you build for and why?

```bash
docker build --platform linux/amd64 ...
```

**Reason:** I developed on Mac M-series (ARM64), but EKS nodes are AMD64. Without explicit platform, containers failed with "exec format error".

---

## 🏗️ Terraform & Infrastructure as Code

### Q: Describe your Terraform module structure

```
terraform/
├── main.tf              # Root module, calls child modules
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── backend.tf           # S3 state configuration
├── environments/
│   ├── dev/terraform.tfvars
│   └── prod/terraform.tfvars
└── modules/
    ├── vpc/             # VPC, subnets, NAT
    ├── eks/             # EKS cluster, node groups
    └── iam/             # IRSA roles and policies
```

### Q: Why use modules?

1. **Reusability**: Same module for dev/prod
2. **Encapsulation**: Hide complexity
3. **Versioning**: Pin module versions
4. **Testing**: Test modules independently
5. **Collaboration**: Teams own their modules

### Q: How do you manage Terraform state?

```hcl
terraform {
  backend "s3" {
    bucket         = "starbucks-terraform-state"
    key            = "starbucks/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

**Components:**
- **S3**: Store state file
- **Encryption**: Protect sensitive data
- **DynamoDB**: State locking (prevent concurrent modifications)

### Q: How do you handle secrets in Terraform?

1. **Never commit secrets** to version control
2. Use **environment variables**: `TF_VAR_db_password`
3. Use **AWS Secrets Manager** and data sources
4. Use **.tfvars files** (gitignored)
5. Use **Vault** for enterprise

### Q: What is `terraform plan` vs `terraform apply`?

| Plan | Apply |
|------|-------|
| Shows what will change | Actually makes changes |
| No state modification | Updates state |
| Safe to run anytime | Requires approval |
| Outputs can be saved | Can use saved plan |

---

## ☁️ AWS Services

### Q: Explain the VPC architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (3 AZs)
│   ├── 10.0.1.0/24
│   ├── 10.0.2.0/24
│   └── 10.0.3.0/24
│   └── Internet Gateway
│   └── NAT Gateway
│
└── Private Subnets (3 AZs)
    ├── 10.0.11.0/24
    ├── 10.0.12.0/24
    └── 10.0.13.0/24
    └── EKS Nodes
```

**Why this design?**
- **Public subnets**: ALB, NAT Gateway
- **Private subnets**: EKS nodes (security)
- **3 AZs**: High availability
- **NAT Gateway**: Outbound internet for private subnets

### Q: How does ALB Ingress Controller work?

1. Deploy AWS Load Balancer Controller to EKS
2. Create Ingress resource with annotations
3. Controller watches for Ingress changes
4. Creates/updates ALB in AWS
5. Configures target groups pointing to pods
6. Uses IP mode (direct pod routing)

```yaml
annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing
  alb.ingress.kubernetes.io/target-type: ip
```

### Q: Explain ECR and how you used it

**Amazon Elastic Container Registry (ECR):**
- Private Docker registry
- Integrated with IAM
- Image scanning on push
- Lifecycle policies for cleanup

**Our workflow:**
```bash
# Login (using IRSA - no stored credentials)
aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY

# Push
docker push $ECR_REGISTRY/starbucks:$TAG
```

### Q: What is the aws-auth ConfigMap?

Maps IAM roles/users to Kubernetes RBAC:

```yaml
data:
  mapRoles: |
    - rolearn: arn:aws:iam::123456789:role/node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::123456789:role/jenkins-role
      username: jenkins
      groups:
        - system:masters
```

**Problem we solved:** Jenkins couldn't access EKS until we added its IRSA role to aws-auth.

---

## 📊 Monitoring & Observability

### Q: Explain your monitoring stack

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ Prometheus  │────▶│   Grafana   │     │AlertManager │
│ (Scraping)  │     │ (Dashboards)│     │  (Alerts)   │
└─────────────┘     └─────────────┘     └─────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────┐
│              ServiceMonitors                         │
│  • Jenkins metrics                                   │
│  • Starbucks app metrics                            │
│  • Node Exporter                                    │
│  • kube-state-metrics                               │
└─────────────────────────────────────────────────────┘
```

### Q: What metrics do you collect?

**Application metrics:**
- Request rate, error rate, latency
- HTTP status codes
- Active connections

**Infrastructure metrics:**
- CPU, Memory, Disk usage
- Network I/O
- Pod restarts

**Kubernetes metrics:**
- Deployment replicas
- Pod status
- HPA scaling events

### Q: Show an example PrometheusRule

```yaml
groups:
  - name: starbucks-alerts
    rules:
      - alert: StarbucksHighErrorRate
        expr: |
          rate(http_requests_total{job="starbucks", status=~"5.."}[5m])
          / rate(http_requests_total{job="starbucks"}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }}"
```

---

## 🔒 Security

### Q: What security measures did you implement?

| Layer | Measure |
|-------|---------|
| **Code** | SonarQube static analysis |
| **Dependencies** | Trivy filesystem scan |
| **Container Image** | Trivy image scan, non-root user |
| **Kubernetes** | RBAC, Network Policies, PodSecurityStandards |
| **AWS** | IRSA (no stored credentials), Private subnets |
| **Network** | ALB with security groups, private node groups |

### Q: Explain Trivy scanning

```bash
# Filesystem scan (dependencies)
trivy fs --severity HIGH,CRITICAL .

# Image scan (OS packages + app dependencies)
trivy image --severity HIGH,CRITICAL myimage:tag
```

**What it finds:**
- CVEs in OS packages
- Vulnerable npm/pip packages
- Secrets in code
- Misconfigurations

### Q: How do you handle container security?

```dockerfile
# Non-root user
RUN adduser -u 1001 -S starbucks
USER starbucks

# Read-only root filesystem (where possible)
# Minimal base image (alpine)
# No shell access in production
```

---

## 🔧 Troubleshooting Scenarios

### Scenario 1: Pod Won't Schedule

**Error:**
```
0/4 nodes are available: 3 Insufficient memory, 4 Insufficient cpu
```

**Our solution:**
Reduced resource requests in Jenkins agent pod:
- node: 500m → 100m CPU, 1Gi → 256Mi memory
- docker: 500m → 100m CPU, 512Mi → 256Mi memory

**Lesson:** Always set realistic resource requests based on actual usage.

### Scenario 2: Build Out of Memory

**Error:**
```
FATAL ERROR: Reached heap limit Allocation failed - JavaScript heap out of memory
```

**Our solution:**
```yaml
env:
  - name: NODE_OPTIONS
    value: "--max-old-space-size=1024"
```

**Lesson:** React builds are memory-intensive; allocate sufficient heap.

### Scenario 3: ESLint Fails CI Build

**Error:**
```
Treating warnings as errors because process.env.CI = true
```

**Our solution:**
```bash
CI=false npm run build
```

**Lesson:** CI environments often have stricter defaults.

### Scenario 4: Cross-Container File Sharing

**Error:**
```
cat: can't open '/tmp/ecr-password.txt': No such file or directory
```

**Root cause:** `/tmp` is container-local, not shared.

**Solution:** Write to `${WORKSPACE}` which is a shared volume.

### Scenario 5: kubectl Authentication Failed

**Error:**
```
error: You must be logged in to the server
```

**Root cause:** Jenkins IRSA role not in aws-auth ConfigMap.

**Solution:**
```yaml
# Add to aws-auth ConfigMap
- rolearn: arn:aws:iam::123456789:role/jenkins-role
  username: jenkins
  groups:
    - system:masters
```

### Scenario 6: Docker Image Architecture Mismatch

**Error:**
```
exec /docker-entrypoint.sh: exec format error
```

**Root cause:** Built on ARM64 (Mac M1), deployed to AMD64 (EKS).

**Solution:**
```bash
docker build --platform linux/amd64 ...
```

---

## 💬 Behavioral Questions

### Q: Describe a challenging problem you solved

> "During the CI/CD pipeline setup, the Jenkins agent pods kept failing to schedule. The error indicated insufficient CPU and memory. I analyzed the pod spec and realized we were requesting too many resources across all containers in the pod.
>
> I reduced the resource requests while keeping limits reasonable for burst scenarios. The key learning was that Kubernetes schedules based on requests, not limits, so right-sizing requests is critical for efficient cluster utilization."

### Q: How do you ensure zero-downtime deployments?

> "We implemented several strategies:
> 1. **Rolling updates** with maxSurge=1, maxUnavailable=0
> 2. **Readiness probes** to ensure new pods are ready before receiving traffic
> 3. **PodDisruptionBudget** with minAvailable=1
> 4. **HPA** to handle traffic spikes during deployment
> 5. **kubectl rollout status** to verify deployment success before marking build green"

### Q: How do you handle secrets management?

> "We follow a layered approach:
> 1. **AWS IRSA** for pod-level AWS access (no stored credentials)
> 2. **Jenkins credentials** for build-time secrets (masked in logs)
> 3. **Kubernetes Secrets** for runtime config (base64 encoded, consider External Secrets for production)
> 4. **Never commit secrets** to Git - use environment variables or secret management tools"

### Q: What would you improve in this architecture?

> "Several enhancements for a true production environment:
> 1. **GitOps with ArgoCD** instead of kubectl apply in pipeline
> 2. **External Secrets Operator** integrating with AWS Secrets Manager
> 3. **Service Mesh (Istio)** for mTLS and advanced traffic management
> 4. **Multi-cluster deployment** for disaster recovery
> 5. **Cost optimization** with Karpenter for intelligent node scaling
> 6. **Policy as Code** with OPA/Gatekeeper for compliance"

---

## 📝 Quick Reference Commands

```bash
# Kubernetes
kubectl get pods -n starbucks -o wide
kubectl describe pod <pod-name> -n starbucks
kubectl logs <pod-name> -n starbucks -f
kubectl rollout status deployment/starbucks-app -n starbucks
kubectl rollout undo deployment/starbucks-app -n starbucks

# EKS
aws eks update-kubeconfig --name starbucks-dev --region ap-south-1
eksctl get nodegroups --cluster starbucks-dev

# Docker
docker build --platform linux/amd64 -t myimage:tag .
docker scan myimage:tag

# Terraform
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -auto-approve
terraform state list

# Trivy
trivy fs --severity HIGH,CRITICAL .
trivy image myimage:tag
```

---

## 🎯 Key Takeaways

1. **Infrastructure as Code is essential** - Reproducible, version-controlled infrastructure
2. **Right-size resources** - Requests affect scheduling, limits prevent runaway
3. **Security at every layer** - Scan code, images, and runtime
4. **Observability is critical** - You can't fix what you can't see
5. **Automation reduces human error** - CI/CD pipelines ensure consistency
6. **Documentation matters** - Future you will thank present you

---

*Prepared by Shubham Arora | Based on real project implementation*

