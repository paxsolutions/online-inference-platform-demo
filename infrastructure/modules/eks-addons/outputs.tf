output "aws_lbc_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_lbc.arn
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "vpc_cni_role_arn" {
  description = "IAM role ARN for VPC CNI"
  value       = aws_iam_role.vpc_cni.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler[0].arn : null
}

output "external_dns_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = var.enable_external_dns ? aws_iam_role.external_dns[0].arn : null
}
