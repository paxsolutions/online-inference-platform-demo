# ArgoCD Variables
variable "enable_argocd" {
  description = "Enable ArgoCD installation"
  type        = bool
  default     = false
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.3.11"
}

variable "argocd_domain" {
  description = "Domain for ArgoCD server"
  type        = string
  default     = ""
}

variable "argocd_admin_password" {
  description = "ArgoCD admin password (bcrypted)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_service_type" {
  description = "Kubernetes service type for ArgoCD"
  type        = string
  default     = "ClusterIP"
}

variable "create_argocd_application" {
  description = "Create ArgoCD Application for the inference platform"
  type        = bool
  default     = false
}

variable "argocd_app_name" {
  description = "Name of the ArgoCD Application"
  type        = string
  default     = "online-inference"
}

variable "argocd_namespace" {
  description = "Target namespace where the application is deployed"
  type        = string
  default     = "inference"
}

variable "argocd_apps_path" {
  description = "Path in the repo that the app-of-apps Application watches (contains Application manifests)"
  type        = string
  default     = "deploy/argocd"
}

# FluxCD Variables
variable "enable_fluxcd" {
  description = "Enable FluxCD installation"
  type        = bool
  default     = false
}

variable "fluxcd_chart_version" {
  description = "FluxCD Helm chart version"
  type        = string
  default     = "2.12.4"
}

variable "create_flux_resources" {
  description = "Create FluxCD GitRepository and HelmRelease"
  type        = bool
  default     = false
}

variable "flux_gitrepo_name" {
  description = "Name of FluxCD GitRepository"
  type        = string
  default     = "online-inference"
}

variable "flux_helmrelease_name" {
  description = "Name of FluxCD HelmRelease"
  type        = string
  default     = "online-inference-flux"
}

variable "flux_interval" {
  description = "FluxCD reconciliation interval"
  type        = string
  default     = "1m"
}

# GitOps Common Variables
variable "gitops_repo_url" {
  description = "URL of the GitOps repository"
  type        = string
}

variable "gitops_repo_branch" {
  description = "Branch of the GitOps repository"
  type        = string
  default     = "main"
}

variable "helm_chart_path" {
  description = "Path to Helm chart in the repo"
  type        = string
  default     = "charts/online-inference"
}

variable "helm_values_file" {
  description = "Path to values file"
  type        = string
  default     = "values.yaml"
}

variable "app_target_namespace" {
  description = "Target namespace for ArgoCD application"
  type        = string
  default     = "inference"
}

variable "app_target_namespace_flux" {
  description = "Target namespace for FluxCD HelmRelease"
  type        = string
  default     = "inference-flux"
}

variable "create_app_namespace" {
  description = "Create the application namespace"
  type        = bool
  default     = true
}
