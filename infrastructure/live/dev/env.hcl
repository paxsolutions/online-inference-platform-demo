# Environment-specific locals for dev
locals {
  environment = "dev"
  region      = "us-east-1"

  # Dev-specific settings (cost-optimized)
  node_pool_min_count = 1
  node_pool_max_count = 3
  spot_min_count      = 0
  spot_max_count      = 5

  # Smaller machines for dev
  primary_instance_type = "t3.medium"
  spot_instance_types   = ["t3.medium", "t3a.medium"]
}
