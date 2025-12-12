# ☕ Starbucks EKS Deployment

A production-ready deployment of the Starbucks clone application on Amazon EKS with complete DevOps tooling, CI/CD pipeline, and monitoring stack.

## 🎯 Project Status: **COMPLETE** ✅

All phases have been successfully implemented and deployed!

---

## 📋 Overview

This project provides a complete DevSecOps implementation including:

| Component | Tool | Status |
|-----------|------|--------|
| **Infrastructure** | Terraform + AWS EKS | ✅ Deployed |
| **CI/CD Pipeline** | Jenkins on Kubernetes | ✅ Running |
| **Code Quality** | SonarQube | ✅ Running |
| **Security Scanning** | Trivy Operator | ✅ Running |
| **Monitoring** | Prometheus + Grafana | ✅ Running |
| **Application** | Starbucks React App | ✅ Running |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (ap-south-1)                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                           VPC (10.0.0.0/16)                               │   │
│  │                                                                           │   │
│  │  ┌─────────────────────┐         ┌─────────────────────────────────────┐ │   │
│  │  │   Public Subnets    │         │         Private Subnets             │ │   │
│  │  │                     │         │                                     │ │   │
│  │  │  ┌───────────────┐  │         │  ┌─────────────────────────────┐   │ │   │
│  │  │  │      ALB      │  │         │  │       EKS Cluster           │   │ │   │
│  │  │  │  • Jenkins    │  │         │  │                             │   │ │   │
│  │  │  │  • SonarQube  │  │         │  │  ┌─────────┐ ┌─────────┐   │   │ │   │
│  │  │  │  • Grafana    │◀─┼─────────┼──┼──│ DevOps  │ │  App    │   │   │ │   │
│  │  │  │  • Prometheus │  │         │  │  │  Nodes  │ │  Nodes  │   │   │ │   │
│  │  │  │  • App        │  │         │  │  └─────────┘ └─────────┘   │   │ │   │
│  │  │  └───────────────┘  │         │  │                             │   │ │   │
│  │  │                     │         │  │  ┌─────────┐               │   │ │   │
│  │  │  ┌───────────────┐  │         │  │  │Monitor  │               │   │ │   │
│  │  │  │   Internet    │  │         │  │  │ Nodes   │               │   │ │   │
│  │  │  │   Gateway     │  │         │  │  └─────────┘               │   │ │   │
│  │  │  └───────────────┘  │         │  └─────────────────────────────┘   │ │   │
│  │  └─────────────────────┘         │                                     │ │   │
│  │                                   │  ┌─────────────────────────────┐   │ │   │
│  │                                   │  │      NAT Gateway            │   │ │   │
│  │                                   │  └─────────────────────────────┘   │ │   │
│  │                                   └─────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐                 │
│  │    ECR     │  │     S3     │  │  DynamoDB  │  │ CloudWatch │                 │
│  │ (Images)   │  │  (State)   │  │  (Locks)   │  │  (Logs)    │                 │
│  └────────────┘  └────────────┘  └────────────┘  └────────────┘                 │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 Access URLs

### Service Endpoints

| Service | Port | URL |
|---------|------|-----|
| **🚀 Starbucks App** | 80 | http://starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com |
| **🔧 Jenkins** | 8080 | http://k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com:8080 |
| **📊 SonarQube** | 9000 | http://k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com:9000 |
| **📈 Grafana** | 3000 | http://k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com:3000 |
| **🔥 Prometheus** | 9090 | http://k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com:9090 |
| **🚨 AlertManager** | 9093 | http://k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com:9093 |

### /etc/hosts Configuration

```bash
# Add these entries to /etc/hosts
13.127.44.63    starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com
65.0.112.228    k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com
13.126.85.193   k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com
```

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| **Grafana** | admin | StarbucksAdmin2024! |
| **SonarQube** | admin | admin (change on first login) |
| **Jenkins** | admin | Run: `kubectl exec -n devops jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword` |

---

## 📁 Project Structure

```
StarBucksByShubham/
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                 # VPC, subnets, NAT Gateway
│   │   ├── eks/                 # EKS cluster, node groups, add-ons
│   │   └── iam/                 # IAM roles (IRSA)
│   ├── environments/
│   │   ├── dev/                 # Development configuration
│   │   └── prod/                # Production configuration
│   ├── main.tf                  # Root module with Helm releases
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output values
│   └── backend.tf               # S3 backend configuration
├── k8s/                         # Kubernetes Manifests
│   ├── namespaces/              # Namespace definitions with quotas
│   │   ├── devops.yaml
│   │   ├── monitoring.yaml
│   │   └── starbucks.yaml
│   ├── devops/                  # DevOps tools
│   │   ├── jenkins/             # Jenkins Helm values & Ingress
│   │   ├── sonarqube/           # SonarQube deployment & Ingress
│   │   ├── trivy/               # Trivy Operator values
│   │   └── storage-class.yaml   # GP3 storage class
│   ├── monitoring/              # Monitoring stack
│   │   ├── kube-prometheus-stack/  # Prometheus Helm values
│   │   ├── dashboards/          # Custom Grafana dashboards
│   │   ├── servicemonitors/     # ServiceMonitor definitions
│   │   ├── alertrules/          # AlertManager rules
│   │   └── monitoring-ingress.yaml
│   ├── starbucks/               # Application deployment
│   │   ├── deployment.yaml      # Production deployment
│   │   ├── service.yaml         # ClusterIP service
│   │   ├── ingress.yaml         # ALB Ingress
│   │   ├── hpa.yaml             # Horizontal Pod Autoscaler
│   │   ├── pdb.yaml             # Pod Disruption Budget
│   │   └── configmap.yaml       # Configuration
│   └── security/                # Security policies (future)
├── docker/                      # Docker configurations
│   ├── Dockerfile              # Multi-stage production build
│   ├── nginx.conf              # Nginx server configuration
│   └── .dockerignore           # Build context exclusions
├── ci-cd/                       # CI/CD configurations
│   ├── Jenkinsfile             # Pipeline definition
│   └── sonar-project.properties # SonarQube config
├── scripts/                     # Automation scripts
│   ├── setup-backend.sh        # Create S3/DynamoDB backend
│   ├── setup-cluster.sh        # Deploy EKS cluster
│   ├── deploy-devops.sh        # Deploy DevOps stack
│   ├── deploy-monitoring.sh    # Deploy monitoring stack
│   ├── deploy-starbucks.sh     # Deploy application
│   └── cleanup.sh              # Destroy all resources
└── docs/                        # Documentation
    ├── ARCHITECTURE.md         # Architecture details
    └── DEPLOYMENT.md           # Deployment & CI/CD guide
```

---

## 🚀 Quick Start

### Prerequisites

- AWS CLI v2 configured
- Terraform >= 1.5.0
- kubectl >= 1.28
- Helm >= 3.x
- Docker >= 24.x

### Deployment

```bash
# Clone and setup
cd StarBucksByShubham
chmod +x scripts/*.sh

# 1. Setup Terraform backend (one-time)
./scripts/setup-backend.sh

# 2. Deploy EKS cluster
./scripts/setup-cluster.sh dev

# 3. Deploy DevOps tools (Jenkins, SonarQube, Trivy)
./scripts/deploy-devops.sh

# 4. Deploy Monitoring (Prometheus, Grafana, AlertManager)
./scripts/deploy-monitoring.sh

# 5. Deploy Starbucks Application
./scripts/deploy-starbucks.sh

# 6. Verify everything
kubectl get pods -A
kubectl get ingress -A
```

---

## 🔄 CI/CD Pipeline

### Pipeline Flow

```
GitHub Push → Jenkins Webhook → Build → Test → SonarQube → Trivy Scan → Docker Build → ECR Push → EKS Deploy → Health Check
```

### Stages

| Stage | Description |
|-------|-------------|
| **Checkout** | Clone source code from GitHub |
| **Install Dependencies** | npm ci --legacy-peer-deps |
| **Run Tests** | Jest tests with coverage |
| **SonarQube Analysis** | Code quality & coverage report |
| **Trivy FS Scan** | Filesystem vulnerability scan |
| **Build Application** | npm run build (production) |
| **Build Docker Image** | Multi-stage build with Nginx |
| **Trivy Image Scan** | Container vulnerability scan |
| **Push to ECR** | Push image to AWS ECR |
| **Deploy to EKS** | kubectl apply / rollout |
| **Verify Deployment** | Health check validation |

---

## 📊 Monitoring & Observability

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics collection from all services |
| **Grafana** | Dashboards & visualization |
| **AlertManager** | Alert routing & notifications |
| **ServiceMonitors** | Auto-discovery of metrics endpoints |
| **Node Exporter** | Host-level metrics |
| **Kube-State-Metrics** | Kubernetes object metrics |

### Pre-configured Dashboards

- Kubernetes Cluster Overview
- Node Health Dashboard
- Starbucks Application Dashboard
- Jenkins Pipeline Metrics

---

## 🔐 Security Features

- ✅ Private subnets for all workloads
- ✅ IRSA (IAM Roles for Service Accounts)
- ✅ KMS encryption for EKS secrets
- ✅ Trivy vulnerability scanning (FS + Image)
- ✅ SonarQube code quality gates
- ✅ Non-root containers
- ✅ Resource limits & quotas
- ✅ Pod security contexts

---

## 📝 Implementation Phases

- [x] **Phase 1**: Infrastructure Foundation (VPC, EKS, IAM, ALB Controller)
- [x] **Phase 2**: DevOps Platform (Jenkins, SonarQube, Trivy)
- [x] **Phase 3**: Monitoring Stack (Prometheus, Grafana, AlertManager)
- [x] **Phase 4**: Application Deployment (Starbucks App with HPA)
- [x] **Phase 5**: CI/CD Pipeline (Jenkinsfile, ECR integration)
- [ ] **Phase 6**: Security Hardening (Network Policies, Pod Security)

---

## 🗑️ Cleanup

```bash
# Delete all resources (WARNING: Permanent!)
./scripts/cleanup.sh dev
```

---

## 📚 Documentation

- [Architecture Guide](docs/ARCHITECTURE.md) - Detailed architecture documentation
- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment & CI/CD setup

---

## 💰 Cost Estimation (Dev Environment)

| Resource | Type | Monthly Cost (Est.) |
|----------|------|---------------------|
| EKS Cluster | Control Plane | $72 |
| DevOps Nodes | 2x t3.medium | ~$60 |
| App Nodes | 2x t3.medium | ~$60 |
| Monitoring Nodes | 1x t3.medium | ~$30 |
| NAT Gateway | Single | ~$32 |
| ALB (3x) | Application | ~$50 |
| **Total** | | **~$304/month** |

---

## 👤 Author

**Shubham Arora**

---

## 📄 License

This project is for educational and demonstration purposes.
