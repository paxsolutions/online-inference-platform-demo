variable "cluster_name" {
  description = "Online Inference EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS Region for the cluster"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zone_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 2
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed for public access to Kubernetes API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Primary (On-Demand) Node Group
variable "primary_instance_type" {
  description = "Instance type for primary node group"
  type        = string
  default     = "t3.large"
}

variable "primary_disk_size" {
  description = "Disk size for primary nodes (GB)"
  type        = number
  default     = 50
}

variable "primary_desired_size" {
  description = "Desired size of primary node group"
  type        = number
  default     = 2
}

variable "primary_min_size" {
  description = "Minimum size of primary node group"
  type        = number
  default     = 1
}

variable "primary_max_size" {
  description = "Maximum size of primary node group"
  type        = number
  default     = 5
}

# Spot Node Group
variable "spot_instance_types" {
  description = "Instance types for spot node group (multiple for diversification)"
  type        = list(string)
  default     = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
}

variable "spot_disk_size" {
  description = "Disk size for spot nodes (GB)"
  type        = number
  default     = 30
}

variable "spot_desired_size" {
  description = "Desired size of spot node group"
  type        = number
  default     = 0
}

variable "spot_min_size" {
  description = "Minimum size of spot node group"
  type        = number
  default     = 0
}

variable "spot_max_size" {
  description = "Maximum size of spot node group"
  type        = number
  default     = 10
}

variable "enable_karpenter" {
  description = "Enable Karpenter for advanced autoscaling"
  type        = bool
  default     = false
}
