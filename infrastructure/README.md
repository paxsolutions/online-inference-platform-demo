# Infrastructure as Code

This directory contains Terraform and Terragrunt configurations for managing the EKS infrastructure and GitOps tooling for the online inference platform.

## Architecture

```
infrastructure/
├── modules/
│   ├── eks/           # EKS cluster module with spot/managed nodes
│   └── gitops/        # ArgoCD/FluxCD installation and bootstrap
├── live/
│   ├── terragrunt.hcl # Root Terragrunt configuration
│   ├── dev/
│   │   ├── env.hcl    # Dev environment variables
│   │   ├── eks/       # Dev EKS cluster
│   │   └── gitops/    # Dev GitOps setup
│   ├── staging/
│   └── prod/
└── README.md
```

## Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.5.0
- [Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= 0.50
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured
- AWS Account with appropriate permissions

### Authentication

```bash
# Configure AWS credentials
aws configure

# Set your account and region
export AWS_ACCOUNT_ID="123456789012"
export AWS_DEFAULT_REGION="us-east-1"
export TG_BUCKET="tf-state-${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}"

# Create state bucket and DynamoDB table (one-time)
./scripts/init-aws-backend.sh
```

### Deploy Dev Environment

```bash
cd infrastructure/live/dev/eks

# Plan
terragrunt plan

# Apply
terragrunt apply

# Get kubeconfig
terragrunt output -raw cluster_name
aws eks update-kubeconfig --name $(terragrunt output -raw cluster_name) --region us-east-1
```

### Deploy GitOps (ArgoCD + FluxCD)

```bash
cd infrastructure/live/dev/gitops

# Plan
terragrunt plan

# Apply - installs both ArgoCD and FluxCD side-by-side
terragrunt apply
```

## Cost Optimization

The infrastructure is designed for cost-efficiency:

| Feature | Cost Impact |
|---------|-------------|
| **Spot/Preemptible Nodes** | ~70% cheaper than regular nodes |
| **e2-medium in dev** | Smallest viable machine type |
| **Cluster Autoscaler** | Scales to zero when idle |
| **GKE Autopilot alternative** | Available in modules/gke-autopilot/ |

### Node Pool Strategy

- **Primary Pool**: Regular nodes for critical workloads (API, Redis)
- **Spot Pool**: Preemptible nodes for batch workers (tolerates interruptions)

## Multi-Environment Workflow

### Deploy All Environments

```bash
# Dev
cd infrastructure/live/dev/gke && terragrunt apply

# Staging (after dev is stable)
cd infrastructure/live/staging/gke && terragrunt apply

# Production (manual promotion only)
cd infrastructure/live/prod/gke && terragrunt apply
```

### Terragrunt Commands

```bash
# Plan all environments
cd infrastructure/live
terragrunt run-all plan

# Apply specific environment
cd infrastructure/live/dev/gke
terragrunt apply

# Destroy (with confirmation)
cd infrastructure/live/dev/gke
terragrunt destroy
```

## GitOps Integration

The GitOps module supports both **ArgoCD** and **FluxCD** running side-by-side:

| | ArgoCD | FluxCD |
|---|---|---|
| **UI** | Built-in web UI | CLI-based |
| **Namespace** | `inference` | `inference-flux` |
| **Release Name** | `online-inference` | `online-inference-flux` |
| **Resources** | ScaledObject, HPA | ScaledObject, HPA |

### Enable Only ArgoCD

```hcl
# infrastructure/live/dev/gitops/terragrunt.hcl
inputs = {
  enable_argocd = true
  enable_fluxcd = false
}
```

### Enable Only FluxCD

```hcl
inputs = {
  enable_argocd = false
  enable_fluxcd = true
}
```

### Enable Both (Default)

```hcl
inputs = {
  enable_argocd = true
  enable_fluxcd = true
}
```

## Module Details

### GKE Module (`modules/gke`)

Creates a private GKE cluster with:
- VPC and subnet with secondary ranges (pods, services)
- Regular node pool for stable workloads
- Spot/preemptible node pool for cost savings
- Workload Identity enabled
- Cluster autoscaler configured
- Managed Prometheus and Cloud Logging

### GitOps Module (`modules/gitops`)

Installs and configures:
- ArgoCD with custom values
- ArgoCD Application for the Helm chart
- FluxCD controllers
- FluxCD GitRepository and HelmRelease
- Application namespaces

## State Management

Terraform state is stored in S3 buckets with DynamoDB locking:
- `s3://tf-state-{account-id}-{region}/infrastructure/dev/eks/terraform.tfstate`
- `s3://tf-state-{account-id}-{region}/infrastructure/dev/gitops/terraform.tfstate`

Locking is handled by DynamoDB table `terraform-locks`.

## Troubleshooting

### KEDA ScaledObject DNS Issues

If KEDA can't resolve Redis hostname, the template uses FQDN:
```yaml
address: "redis.{{ .Release.Namespace }}.svc.cluster.local:6379"
```

### HelmRelease Timeout

If FluxCD HelmRelease times out waiting for ScaledObject:
```bash
# Suspend and resume to force fresh install
flux suspend helmrelease online-inference-flux -n flux-system
flux resume helmrelease online-inference-flux -n flux-system
```

## CI/CD Integration

Example GitHub Actions workflow for automated infrastructure deployment:

```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['infrastructure/**']

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - uses: gruntwork-io/terragrunt-action@v2
      - run: |
          cd infrastructure/live/dev/gke
          terragrunt plan
```
