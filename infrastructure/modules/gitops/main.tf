terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

# ArgoCD Installation
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = "argocd"
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/argocd-values.yaml", {
      domain = var.argocd_domain
      admin_password = var.argocd_admin_password
    })
  ]

  set {
    name  = "server.service.type"
    value = var.argocd_service_type
  }
}

# ArgoCD Application for the inference platform
resource "kubectl_manifest" "argocd_application" {
  count = var.enable_argocd && var.create_argocd_application ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/argocd-application.yaml", {
    name       = var.argocd_app_name
    namespace  = var.argocd_namespace
    repo_url   = var.gitops_repo_url
    repo_branch = var.gitops_repo_branch
    chart_path = var.helm_chart_path
    target_namespace = var.app_target_namespace
    values_file = var.helm_values_file
  })

  depends_on = [helm_release.argocd]
}

# FluxCD Installation
resource "helm_release" "fluxcd" {
  count = var.enable_fluxcd ? 1 : 0

  name       = "flux2"
  repository = "https://fluxcd-community.github.io/helm-charts"
  chart      = "flux2"
  version    = var.fluxcd_chart_version
  namespace  = "flux-system"
  create_namespace = true
}

# FluxCD GitRepository
resource "kubectl_manifest" "flux_gitrepository" {
  count = var.enable_fluxcd && var.create_flux_resources ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/flux-gitrepository.yaml", {
    name      = var.flux_gitrepo_name
    namespace = "flux-system"
    repo_url  = var.gitops_repo_url
    repo_branch = var.gitops_repo_branch
    interval  = var.flux_interval
  })

  depends_on = [helm_release.fluxcd]
}

# FluxCD HelmRelease
resource "kubectl_manifest" "flux_helmrelease" {
  count = var.enable_fluxcd && var.create_flux_resources ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/flux-helmrelease.yaml", {
    name             = var.flux_helmrelease_name
    namespace        = "flux-system"
    target_namespace = var.app_target_namespace_flux
    chart_path       = var.helm_chart_path
    gitrepo_name     = var.flux_gitrepo_name
    interval         = var.flux_interval
    values_file      = var.helm_values_file
  })

  depends_on = [kubectl_manifest.flux_gitrepository]
}

# Namespace for the application
resource "kubernetes_namespace" "app" {
  count = var.create_app_namespace ? 1 : 0

  metadata {
    name = var.app_target_namespace
  }
}

resource "kubernetes_namespace" "app_flux" {
  count = var.enable_fluxcd && var.app_target_namespace_flux != var.app_target_namespace ? 1 : 0

  metadata {
    name = var.app_target_namespace_flux
  }
}
