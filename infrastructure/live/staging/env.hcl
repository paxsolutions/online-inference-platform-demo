# Environment-specific locals for staging
locals {
  environment = "staging"
  region      = "us-east-1"

  # Staging settings (moderate capacity)
  node_pool_min_count = 2
  node_pool_max_count = 5
  spot_min_count      = 1
  spot_max_count      = 8

  # Standard machines for staging
  primary_instance_type = "t3.large"
  spot_instance_types   = ["t3.large", "t3a.large", "m5.large"]
}
