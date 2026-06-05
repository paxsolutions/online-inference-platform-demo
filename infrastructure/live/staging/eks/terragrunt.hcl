# Terragrunt configuration for staging EKS cluster
include "root" {
  path = find_in_parent_folders()
}

include "env" {
  path   = find_in_parent_folders("env.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}/infrastructure/modules/eks"
}

locals {
  env = include.env.locals
}

# Module inputs
inputs = {
  cluster_name = "online-inference-${local.env.environment}"
  region       = local.env.region
  environment  = local.env.environment

  # Primary (On-Demand) Node Group
  primary_instance_type = local.env.primary_instance_type
  primary_min_size      = local.env.node_pool_min_count
  primary_max_size      = local.env.node_pool_max_count

  # Spot Node Group
  spot_instance_types = local.env.spot_instance_types
  spot_min_size       = local.env.spot_min_count
  spot_max_size       = local.env.spot_max_count

  # Staging: 2 AZs for availability
  availability_zone_count = 2
}
