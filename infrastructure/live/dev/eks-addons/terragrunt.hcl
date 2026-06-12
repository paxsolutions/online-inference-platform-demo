# Terragrunt configuration for dev EKS add-ons
# Deploys after the EKS cluster is ready
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

dependency "eks" {
  config_path = "../eks"

  mock_outputs = {
    cluster_name             = "mock-cluster"
    cluster_endpoint         = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "mock-ca"
    oidc_provider_arn        = "arn:aws:iam::123456789012:oidc-provider/mock"
    oidc_provider_url        = "https://oidc.eks.us-east-1.amazonaws.com/id/mock"
    vpc_id                   = "vpc-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/eks-addons"
}

generate "k8s_provider" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}"]
  }
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}"]
    }
  }
}

EOF
}

locals {
  env = include.env.locals
}

inputs = {
  cluster_name      = dependency.eks.outputs.cluster_name
  region            = local.env.region
  environment       = local.env.environment
  vpc_id            = dependency.eks.outputs.vpc_id
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  oidc_provider_url = dependency.eks.outputs.oidc_provider_url

  tags = {
    Project     = "online-inference"
    Environment = local.env.environment
    ManagedBy   = "terraform"
  }

  # Add-ons: all enabled for dev
  enable_aws_lbc            = true
  enable_metrics_server     = true
  enable_cluster_autoscaler = true
  enable_keda               = true
  enable_argo_rollouts      = true
  enable_external_dns       = false  # enable if you have a Route53 hosted zone
}
