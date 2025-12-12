################################################################################
# Starbucks EKS Infrastructure - Variables
################################################################################

#------------------------------------------------------------------------------
# General Configuration
#------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
  default     = "starbucks"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner of the resources - used for tagging"
  type        = string
  default     = "shubham"
}

#------------------------------------------------------------------------------
# VPC Configuration
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# EKS Cluster Configuration
#------------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks allowed to access the EKS API server publicly"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "cloudwatch_log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "eks_addon_versions" {
  description = "Versions for EKS add-ons"
  type        = map(string)
  default = {
    "coredns"            = "v1.11.1-eksbuild.9"
    "kube-proxy"         = "v1.30.0-eksbuild.3"
    "vpc-cni"            = "v1.18.2-eksbuild.1"
    "aws-ebs-csi-driver" = "v1.32.0-eksbuild.1"
  }
}

#------------------------------------------------------------------------------
# DevOps Node Group Configuration
#------------------------------------------------------------------------------

variable "devops_node_instance_types" {
  description = "Instance types for DevOps node group (Jenkins, SonarQube)"
  type        = list(string)
  default     = ["t3.large"]
}

variable "devops_node_desired_size" {
  description = "Desired number of nodes in DevOps node group"
  type        = number
  default     = 2
}

variable "devops_node_min_size" {
  description = "Minimum number of nodes in DevOps node group"
  type        = number
  default     = 2
}

variable "devops_node_max_size" {
  description = "Maximum number of nodes in DevOps node group"
  type        = number
  default     = 4
}

#------------------------------------------------------------------------------
# Application Node Group Configuration
#------------------------------------------------------------------------------

variable "app_node_instance_types" {
  description = "Instance types for Application node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "app_node_desired_size" {
  description = "Desired number of nodes in Application node group"
  type        = number
  default     = 3
}

variable "app_node_min_size" {
  description = "Minimum number of nodes in Application node group"
  type        = number
  default     = 2
}

variable "app_node_max_size" {
  description = "Maximum number of nodes in Application node group"
  type        = number
  default     = 6
}

variable "use_spot_instances" {
  description = "Use Spot instances for application node group (cost-saving)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Monitoring Node Group Configuration
#------------------------------------------------------------------------------

variable "monitoring_node_instance_types" {
  description = "Instance types for Monitoring node group (Prometheus, Grafana)"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "monitoring_node_desired_size" {
  description = "Desired number of nodes in Monitoring node group"
  type        = number
  default     = 2
}

variable "monitoring_node_min_size" {
  description = "Minimum number of nodes in Monitoring node group"
  type        = number
  default     = 2
}

variable "monitoring_node_max_size" {
  description = "Maximum number of nodes in Monitoring node group"
  type        = number
  default     = 3
}

