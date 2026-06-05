# Root Terragrunt configuration for AWS/EKS
# This is included by all child terragrunt.hcl files

locals {
  # Parse the directory structure to get environment and region
  path_parts = path_relative_to_include()

  # Common settings
  aws_account_id = get_env("AWS_ACCOUNT_ID", "")
  aws_region     = get_env("AWS_DEFAULT_REGION", "us-east-1")

  # Remote state configuration
  remote_state_bucket = get_env("TG_BUCKET", "tf-state-${local.aws_account_id}-${local.aws_region}")
  remote_state_prefix = "infrastructure"
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<EOF
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "online-inference"
      Environment = var.environment
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
EOF
}

# Remote state configuration (S3)
remote_state {
  backend = "s3"

  config = {
    bucket         = local.remote_state_bucket
    key            = "${local.remote_state_prefix}/${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Common inputs passed to all modules
inputs = {
  region      = local.aws_region
  environment = path_relative_to_include()
}
