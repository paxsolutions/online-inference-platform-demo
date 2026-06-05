# Terragrunt configuration for dev GitOps setup
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

dependency "gke" {
  config_path = "../gke"
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/gitops"
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
