################################################################################
# Starbucks EKS Infrastructure - Outputs
################################################################################

#------------------------------------------------------------------------------
# VPC Outputs
#------------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_ips" {
  description = "List of NAT Gateway public IPs"
  value       = module.vpc.nat_gateway_ips
}

#------------------------------------------------------------------------------
# EKS Cluster Outputs
#------------------------------------------------------------------------------

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for cluster authentication"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_version" {
  description = "The Kubernetes version of the cluster"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Provider"
  value       = module.eks.oidc_provider_url
}

#------------------------------------------------------------------------------
# IAM Role Outputs
#------------------------------------------------------------------------------

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = module.iam.alb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "jenkins_role_arn" {
  description = "IAM role ARN for Jenkins"
  value       = module.iam.jenkins_role_arn
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus"
  value       = module.iam.prometheus_role_arn
}

#------------------------------------------------------------------------------
# ECR Outputs
#------------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL of the ECR repository for Starbucks app"
  value       = aws_ecr_repository.starbucks.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.starbucks.arn
}

#------------------------------------------------------------------------------
# S3 Outputs
#------------------------------------------------------------------------------

output "jenkins_backup_bucket" {
  description = "S3 bucket name for Jenkins backups"
  value       = aws_s3_bucket.jenkins_backups.id
}

#------------------------------------------------------------------------------
# Useful Commands
#------------------------------------------------------------------------------

output "configure_kubectl" {
  description = "AWS CLI command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login_command" {
  description = "AWS CLI command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.starbucks.repository_url}"
}

