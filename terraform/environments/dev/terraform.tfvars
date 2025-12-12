################################################################################
# Development Environment Configuration
################################################################################

# General
aws_region   = "ap-south-1"
project_name = "starbucks"
environment  = "dev"
owner        = "shubham"

# VPC
vpc_cidr             = "10.0.0.0/16"
enable_vpc_flow_logs = true

# EKS Cluster
kubernetes_version                   = "1.30"
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Restrict in production!
cloudwatch_log_retention_days        = 7            # Shorter retention for dev

# EKS Add-on Versions (use latest stable)
eks_addon_versions = {
  "coredns"            = "v1.11.1-eksbuild.9"
  "kube-proxy"         = "v1.30.0-eksbuild.3"
  "vpc-cni"            = "v1.18.2-eksbuild.1"
  "aws-ebs-csi-driver" = "v1.32.0-eksbuild.1"
}

# DevOps Node Group (Jenkins, SonarQube)
devops_node_instance_types = ["t3.medium"]
devops_node_desired_size   = 2
devops_node_min_size       = 1
devops_node_max_size       = 3

# Application Node Group (Starbucks App)
app_node_instance_types = ["t3.medium"]
app_node_desired_size   = 2
app_node_min_size       = 1
app_node_max_size       = 4
use_spot_instances      = true # Use spot for dev to save cost

# Monitoring Node Group (Prometheus, Grafana)
monitoring_node_instance_types = ["t3.medium"]
monitoring_node_desired_size   = 1
monitoring_node_min_size       = 1
monitoring_node_max_size       = 2

