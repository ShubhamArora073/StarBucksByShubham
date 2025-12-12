################################################################################
# Production Environment Configuration
################################################################################

# General
aws_region   = "ap-south-1"
project_name = "starbucks"
environment  = "prod"
owner        = "shubham"

# VPC
vpc_cidr             = "10.0.0.0/16"
enable_vpc_flow_logs = true

# EKS Cluster
kubernetes_version = "1.30"
# IMPORTANT: Restrict API access to your office/VPN IPs in production!
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # TODO: Replace with your CIDR
cloudwatch_log_retention_days        = 90           # Longer retention for prod

# EKS Add-on Versions
eks_addon_versions = {
  "coredns"            = "v1.11.1-eksbuild.9"
  "kube-proxy"         = "v1.30.0-eksbuild.3"
  "vpc-cni"            = "v1.18.2-eksbuild.1"
  "aws-ebs-csi-driver" = "v1.32.0-eksbuild.1"
}

# DevOps Node Group (Jenkins, SonarQube)
# Using larger instances for production CI/CD
devops_node_instance_types = ["t3.medium"]
devops_node_desired_size   = 2
devops_node_min_size       = 2
devops_node_max_size       = 4

# Application Node Group (Starbucks App)
# Using ON_DEMAND for production reliability
app_node_instance_types = ["t3.medium", "t3.large"]
app_node_desired_size   = 1
app_node_min_size       = 1
app_node_max_size       = 10
use_spot_instances      = false # ON_DEMAND for production

# Monitoring Node Group (Prometheus, Grafana)
# Dedicated nodes for monitoring stack
monitoring_node_instance_types = ["t3.large"]
monitoring_node_desired_size   = 1
monitoring_node_min_size       = 1
monitoring_node_max_size       = 4

