################################################################################
# IAM Module Outputs
################################################################################

output "alb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_role_name" {
  description = "IAM role name for AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "cluster_autoscaler_role_name" {
  description = "IAM role name for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.name
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS"
  value       = aws_iam_role.external_dns.arn
}

output "external_dns_role_name" {
  description = "IAM role name for External DNS"
  value       = aws_iam_role.external_dns.name
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for Cert Manager"
  value       = aws_iam_role.cert_manager.arn
}

output "cert_manager_role_name" {
  description = "IAM role name for Cert Manager"
  value       = aws_iam_role.cert_manager.name
}

output "jenkins_role_arn" {
  description = "IAM role ARN for Jenkins"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_role_name" {
  description = "IAM role name for Jenkins"
  value       = aws_iam_role.jenkins.name
}

output "prometheus_role_arn" {
  description = "IAM role ARN for Prometheus"
  value       = aws_iam_role.prometheus.arn
}

output "prometheus_role_name" {
  description = "IAM role name for Prometheus"
  value       = aws_iam_role.prometheus.name
}

