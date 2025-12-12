# Starbucks EKS Architecture

## Overview

This document describes the architecture of the Starbucks application deployed on Amazon EKS with a complete DevOps and monitoring stack.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS CLOUD                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                              VPC (10.0.0.0/16)                               ││
│  │                                                                              ││
│  │  ┌──────────────────────────┐    ┌──────────────────────────┐               ││
│  │  │     Public Subnets       │    │     Private Subnets      │               ││
│  │  │   (10.0.0.0/20, etc.)   │    │   (10.0.64.0/20, etc.)   │               ││
│  │  │                          │    │                          │               ││
│  │  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │               ││
│  │  │  │  Internet Gateway  │  │    │  │    NAT Gateway     │  │               ││
│  │  │  └────────────────────┘  │    │  └────────────────────┘  │               ││
│  │  │                          │    │                          │               ││
│  │  │  ┌────────────────────┐  │    │  ┌────────────────────┐  │               ││
│  │  │  │  ALB (Ingress)     │  │    │  │   EKS Cluster      │  │               ││
│  │  │  │  - Jenkins         │  │    │  │                    │  │               ││
│  │  │  │  - Grafana         │  │    │  │  ┌──────────────┐  │  │               ││
│  │  │  │  - Starbucks App   │  │    │  │  │ Control Plane│  │  │               ││
│  │  │  └────────────────────┘  │    │  │  └──────────────┘  │  │               ││
│  │  │                          │    │  │                    │  │               ││
│  │  └──────────────────────────┘    │  │  ┌──────────────┐  │  │               ││
│  │                                   │  │  │ Node Groups │  │  │               ││
│  │                                   │  │  │ - devops    │  │  │               ││
│  │                                   │  │  │ - app       │  │  │               ││
│  │                                   │  │  │ - monitoring│  │  │               ││
│  │                                   │  │  └──────────────┘  │  │               ││
│  │                                   │  │                    │  │               ││
│  │                                   │  └────────────────────┘  │               ││
│  │                                   └──────────────────────────┘               ││
│  │                                                                              ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
│  │      ECR        │  │       S3        │  │   CloudWatch    │                  │
│  │  (Container     │  │  (Backups &     │  │  (Logs &        │                  │
│  │   Registry)     │  │   State)        │  │   Metrics)      │                  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Network Layer

| Component | Description |
|-----------|-------------|
| **VPC** | Isolated network with CIDR 10.0.0.0/16 |
| **Public Subnets** | 3 subnets across AZs for load balancers |
| **Private Subnets** | 3 subnets across AZs for EKS nodes |
| **NAT Gateway** | Enables private subnet internet access |
| **Internet Gateway** | Public subnet internet access |

### 2. EKS Cluster

| Component | Description |
|-----------|-------------|
| **Control Plane** | Managed by AWS, HA across 3 AZs |
| **Node Groups** | 3 managed node groups with autoscaling |
| **OIDC Provider** | Enables IAM Roles for Service Accounts |

### 3. Node Groups

| Name | Purpose | Instance Type | Min/Max |
|------|---------|--------------|---------|
| **devops** | Jenkins, SonarQube | t3.large | 2/4 |
| **application** | Starbucks App | t3.medium | 2/6 |
| **monitoring** | Prometheus, Grafana | t3.medium | 2/3 |

### 4. Kubernetes Namespaces

```
┌─────────────────────────────────────────────────────────────────┐
│                        EKS Cluster                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │    kube-system  │  │     devops      │  │   monitoring    │  │
│  │                 │  │                 │  │                 │  │
│  │  - CoreDNS      │  │  - Jenkins      │  │  - Prometheus   │  │
│  │  - kube-proxy   │  │  - SonarQube    │  │  - Grafana      │  │
│  │  - VPC CNI      │  │  - Trivy        │  │  - AlertManager │  │
│  │  - ALB Ctrl     │  │                 │  │  - Loki         │  │
│  │  - Autoscaler   │  │                 │  │                 │  │
│  │  - Metrics Srv  │  │                 │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                  │
│  ┌─────────────────┐                                            │
│  │   starbucks     │                                            │
│  │                 │                                            │
│  │  - Starbucks    │                                            │
│  │    Deployment   │                                            │
│  │  - HPA          │                                            │
│  │  - PDB          │                                            │
│  │  - Ingress      │                                            │
│  └─────────────────┘                                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## CI/CD Pipeline

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            CI/CD Pipeline Flow                                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐              │
│   │  GitHub  │────▶│  Webhook │────▶│ Jenkins  │────▶│  Build   │              │
│   │   Push   │     │ Trigger  │     │ Pipeline │     │  Stage   │              │
│   └──────────┘     └──────────┘     └──────────┘     └──────────┘              │
│                                                             │                    │
│                                                             ▼                    │
│   ┌──────────────────────────────────────────────────────────────────┐         │
│   │                    Quality & Security Gates                       │         │
│   │  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐      │         │
│   │  │   npm    │──▶│ SonarQube│──▶│  Trivy   │──▶│  Trivy   │      │         │
│   │  │   test   │   │ Analysis │   │ FS Scan  │   │ Img Scan │      │         │
│   │  └──────────┘   └──────────┘   └──────────┘   └──────────┘      │         │
│   └──────────────────────────────────────────────────────────────────┘         │
│                                                             │                    │
│                                                             ▼                    │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐              │
│   │  Grafana │◀────│Prometheus│◀────│   EKS    │◀────│   ECR    │              │
│   │ Dashboard│     │ Metrics  │     │  Deploy  │     │   Push   │              │
│   └──────────┘     └──────────┘     └──────────┘     └──────────┘              │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Pipeline Stages

| Stage | Tool | Purpose |
|-------|------|---------|
| **Checkout** | Git | Clone source code |
| **Dependencies** | npm | Install packages |
| **Unit Tests** | Jest | Run tests with coverage |
| **Code Analysis** | SonarQube | Quality gate check |
| **Security Scan** | Trivy | Filesystem vulnerabilities |
| **Build** | npm/Docker | Production build |
| **Image Scan** | Trivy | Container vulnerabilities |
| **Push** | AWS ECR | Store container image |
| **Deploy** | kubectl | Rolling update to EKS |
| **Verify** | Health checks | Validate deployment |

### Jenkins Configuration

```
Jenkins (devops namespace)
├── Kubernetes Cloud Plugin
│   └── Dynamic agents in EKS
├── SonarQube Scanner
│   └── http://sonarqube-service.devops:9000
├── Credentials
│   ├── github-token (GitHub PAT)
│   ├── sonar-token (SonarQube auth)
│   └── AWS (IRSA - automatic)
└── Pipeline Jobs
    └── Starbucks-CI-CD (Jenkinsfile)
```

## Security

### IAM Roles for Service Accounts (IRSA)

| Service Account | IAM Role | Purpose |
|----------------|----------|---------|
| aws-load-balancer-controller | ALB Controller Role | Manage ALB/NLB |
| cluster-autoscaler | Autoscaler Role | Scale node groups |
| jenkins | Jenkins Role | ECR push, EKS deploy |
| prometheus-server | Prometheus Role | CloudWatch metrics |

### Network Security

- Private subnets for all workloads
- Security groups per component
- Network policies between namespaces
- TLS for all external traffic

### Data Encryption

- EKS secrets encrypted with KMS
- EBS volumes encrypted
- S3 buckets encrypted
- TLS for data in transit

## Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Monitoring Architecture                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────┐         ┌─────────────┐         ┌─────────────┐               │
│  │  Starbucks  │────────▶│ Prometheus  │────────▶│   Grafana   │               │
│  │    App      │ metrics │             │ query   │             │               │
│  └─────────────┘         └─────────────┘         └─────────────┘               │
│                                 │                                                │
│  ┌─────────────┐                │                 ┌─────────────┐               │
│  │   Jenkins   │────────────────┤                 │AlertManager │               │
│  └─────────────┘                │                 └─────────────┘               │
│                                 │                        │                       │
│  ┌─────────────┐                │                        │                       │
│  │ K8s Metrics │────────────────┘                        ▼                       │
│  │ (kube-state)│                                  ┌─────────────┐               │
│  └─────────────┘                                  │   Slack/    │               │
│                                                   │   Email     │               │
│                                                   └─────────────┘               │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Cost Optimization

| Strategy | Implementation |
|----------|---------------|
| **Spot Instances** | Used for dev/staging app nodes |
| **Single NAT** | Single NAT Gateway for non-prod |
| **Autoscaling** | Cluster Autoscaler + HPA |
| **Right-sizing** | Appropriate instance types per workload |
| **S3 Lifecycle** | Auto-archive old backups |

## High Availability

- Multi-AZ deployment
- Pod anti-affinity rules
- PodDisruptionBudgets
- Rolling deployments
- Health checks (liveness/readiness)

## Deployed Services

### Access URLs

| Service | Port | ALB DNS |
|---------|------|---------|
| **Starbucks App** | 80 | starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com |
| **Jenkins** | 8080 | k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com |
| **SonarQube** | 9000 | k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com |
| **Grafana** | 3000 | k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com |
| **Prometheus** | 9090 | k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com |
| **AlertManager** | 9093 | k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com |

### /etc/hosts Configuration

```
# Starbucks Application
13.127.44.63    starbucks-app-alb-754901974.ap-south-1.elb.amazonaws.com

# DevOps Stack (Jenkins, SonarQube)
65.0.112.228    k8s-starbucksdevops-9ebfc70ebb-2033360495.ap-south-1.elb.amazonaws.com

# Monitoring Stack (Grafana, Prometheus, AlertManager)
13.126.85.193   k8s-starbucksmonitori-d7d886c643-426750916.ap-south-1.elb.amazonaws.com
```

### Credentials

| Service | Username | Password |
|---------|----------|----------|
| **Grafana** | admin | StarbucksAdmin2024! |
| **SonarQube** | admin | admin (change on first login) |
| **Jenkins** | admin | `kubectl exec -n devops jenkins-0 -- cat /var/jenkins_home/secrets/initialAdminPassword` |

## Project Structure

```
StarBucksByShubham/
├── terraform/                    # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                 # VPC, subnets, NAT
│   │   ├── eks/                 # EKS cluster, node groups
│   │   └── iam/                 # IAM roles (IRSA)
│   ├── environments/
│   │   ├── dev/                 # Dev configuration
│   │   └── prod/                # Prod configuration
│   └── main.tf                  # Root module
├── k8s/                         # Kubernetes manifests
│   ├── namespaces/              # Namespace definitions
│   ├── devops/                  # Jenkins, SonarQube, Trivy
│   │   ├── jenkins/
│   │   ├── sonarqube/
│   │   └── trivy/
│   ├── monitoring/              # Prometheus stack
│   │   ├── kube-prometheus-stack/
│   │   ├── dashboards/
│   │   ├── servicemonitors/
│   │   └── alertrules/
│   └── starbucks/               # Application manifests
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml
│       └── pdb.yaml
├── docker/                      # Docker configurations
│   ├── Dockerfile              # Multi-stage build
│   └── nginx.conf              # Nginx configuration
├── ci-cd/                       # CI/CD configurations
│   ├── Jenkinsfile             # Pipeline definition
│   └── sonar-project.properties
├── scripts/                     # Automation scripts
│   ├── setup-backend.sh
│   ├── setup-cluster.sh
│   ├── deploy-devops.sh
│   ├── deploy-monitoring.sh
│   ├── deploy-starbucks.sh
│   └── cleanup.sh
└── docs/                        # Documentation
    ├── ARCHITECTURE.md
    └── DEPLOYMENT.md
```

---

**Author:** Shubham Arora  
**Last Updated:** December 2024

