# Environment-specific locals for production
locals {
  environment = "prod"
  region      = "us-east-1"

  # Production settings (high availability)
  node_pool_min_count = 3
  node_pool_max_count = 10
  spot_min_count      = 2
  spot_max_count      = 20

  # Larger machines for production
  primary_instance_type = "t3.xlarge"
  spot_instance_types   = ["t3.large", "t3a.large", "m5.large", "m5a.large"]
}
