variable "cluster_name" {
  description = "Online inference platform cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the Load Balancer Controller"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from the EKS cluster (for IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC provider URL from the EKS cluster (for IRSA trust policies)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ============================================================
# EKS Managed Add-on versions
# ============================================================

variable "coredns_version" {
  description = "CoreDNS managed add-on version"
  type        = string
  default     = "v1.11.3-eksbuild.2"
}

variable "kube_proxy_version" {
  description = "kube-proxy managed add-on version"
  type        = string
  default     = "v1.32.0-eksbuild.2"
}

variable "vpc_cni_version" {
  description = "VPC CNI managed add-on version"
  type        = string
  default     = "v1.19.0-eksbuild.1"
}

variable "ebs_csi_version" {
  description = "EBS CSI driver managed add-on version"
  type        = string
  default     = "v1.37.0-eksbuild.1"
}

# ============================================================
# AWS Load Balancer Controller
# ============================================================

variable "enable_aws_lbc" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_lbc_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "1.7.2"
}

# ============================================================
# Argo Rollouts
# ============================================================

variable "enable_argo_rollouts" {
  description = "Enable Argo Rollouts for progressive delivery (canary/blue-green)"
  type        = bool
  default     = true
}

variable "argo_rollouts_version" {
  description = "Helm chart version for Argo Rollouts"
  type        = string
  default     = "2.35.1"
}

# ============================================================
# KEDA
# ============================================================

variable "enable_keda" {
  description = "Enable KEDA for event-driven autoscaling"
  type        = bool
  default     = true
}

variable "keda_version" {
  description = "Helm chart version for KEDA"
  type        = string
  default     = "2.14.2"
}

# ============================================================
# Metrics Server
# ============================================================

variable "enable_metrics_server" {
  description = "Enable Metrics Server (required for HPA)"
  type        = bool
  default     = true
}

variable "metrics_server_version" {
  description = "Helm chart version for Metrics Server"
  type        = string
  default     = "3.12.1"
}

# ============================================================
# ExternalDNS
# ============================================================

variable "enable_external_dns" {
  description = "Enable ExternalDNS for automatic Route53 record management"
  type        = bool
  default     = false
}

variable "external_dns_version" {
  description = "Helm chart version for ExternalDNS"
  type        = string
  default     = "1.14.4"
}

# ============================================================
# Cluster Autoscaler
# ============================================================

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

variable "cluster_autoscaler_version" {
  description = "Helm chart version for Cluster Autoscaler"
  type        = string
  default     = "9.36.0"
}
