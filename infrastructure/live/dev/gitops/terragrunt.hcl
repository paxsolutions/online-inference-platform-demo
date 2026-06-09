# Terragrunt configuration for dev GitOps setup
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
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "mock-ca"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/gitops"
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

provider "kubectl" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}"]
  }
}
EOF
}

locals {
  env = include.env.locals
}

inputs = {
  # ArgoCD Configuration
  enable_argocd             = true
  create_argocd_application = true
  argocd_app_name           = "online-inference"
  argocd_namespace          = "inference"

  # FluxCD Configuration (side-by-side with ArgoCD)
  enable_fluxcd             = true
  create_flux_resources     = true
  flux_helmrelease_name     = "online-inference-flux"
  app_target_namespace_flux = "inference-flux"

  # GitOps Repository
  gitops_repo_url    = "https://github.com/paxsolutions/online-inference-platform-demo"
  gitops_repo_branch = "main"
  helm_chart_path    = "charts/online-inference"

  # Namespaces
  create_app_namespace = true
  app_target_namespace = "inference"
}
