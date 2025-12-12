################################################################################
# Starbucks EKS Infrastructure - Main Configuration
# Production-ready EKS cluster with full DevOps stack
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Uncomment and configure for remote state (recommended for production)
  # backend "s3" {
  #   bucket         = "starbucks-terraform-state"
  #   key            = "eks/terraform.tfstate"
  #   region         = "ap-south-1"
  #   encrypt        = true
  #   dynamodb_table = "starbucks-terraform-locks"
  # }
}

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes provider configuration (after cluster is created)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm provider configuration
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

################################################################################
# Local Variables
################################################################################

locals {
  cluster_name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = var.owner
  }

  # Node group configurations
  node_groups = {
    # DevOps node group - for Jenkins, SonarQube, etc.
    devops = {
      instance_types = var.devops_node_instance_types
      desired_size   = var.devops_node_desired_size
      min_size       = var.devops_node_min_size
      max_size       = var.devops_node_max_size
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      labels = {
        workload = "devops"
        role     = "devops"
      }
    }

    # Application node group - for Starbucks app
    application = {
      instance_types = var.app_node_instance_types
      desired_size   = var.app_node_desired_size
      min_size       = var.app_node_min_size
      max_size       = var.app_node_max_size
      capacity_type  = var.use_spot_instances ? "SPOT" : "ON_DEMAND"
      disk_size      = 50
      labels = {
        workload = "application"
        role     = "app"
      }
    }

    # Monitoring node group - for Prometheus, Grafana
    monitoring = {
      instance_types = var.monitoring_node_instance_types
      desired_size   = var.monitoring_node_desired_size
      min_size       = var.monitoring_node_min_size
      max_size       = var.monitoring_node_max_size
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      labels = {
        workload = "monitoring"
        role     = "monitoring"
      }
    }
  }
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "./modules/vpc"

  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = true
  single_nat_gateway = var.environment != "prod" # Use single NAT for non-prod to save cost
  enable_flow_logs   = var.enable_vpc_flow_logs

  tags = local.common_tags
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_enabled_log_types     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_retention_days = var.cloudwatch_log_retention_days

  node_groups = local.node_groups

  addon_versions = var.eks_addon_versions

  tags = local.common_tags
}

################################################################################
# IAM Module (IRSA Roles)
################################################################################

module "iam" {
  source = "./modules/iam"

  cluster_name      = local.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer

  tags = local.common_tags
}

################################################################################
# ECR Repository for Starbucks App
################################################################################

resource "aws_ecr_repository" "starbucks" {
  name                 = "${var.project_name}/starbucks-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "starbucks" {
  repository = aws_ecr_repository.starbucks.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

################################################################################
# S3 Bucket for Jenkins Backups
################################################################################

resource "aws_s3_bucket" "jenkins_backups" {
  bucket = "${local.cluster_name}-jenkins-backups"

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "jenkins_backups" {
  bucket = aws_s3_bucket.jenkins_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "jenkins_backups" {
  bucket = aws_s3_bucket.jenkins_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "jenkins_backups" {
  bucket = aws_s3_bucket.jenkins_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "jenkins_backups" {
  bucket = aws_s3_bucket.jenkins_backups.id

  rule {
    id     = "cleanup-old-backups"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

################################################################################
# Helm Release: AWS Load Balancer Controller
################################################################################

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.alb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [module.eks]
}

################################################################################
# Helm Release: Cluster Autoscaler
################################################################################

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.35.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam.cluster_autoscaler_role_arn
  }

  set {
    name  = "extraArgs.balance-similar-node-groups"
    value = "true"
  }

  set {
    name  = "extraArgs.skip-nodes-with-system-pods"
    value = "false"
  }

  depends_on = [module.eks]
}

################################################################################
# Helm Release: Metrics Server (required for HPA)
################################################################################

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.0"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [module.eks]
}

