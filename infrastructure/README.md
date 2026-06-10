# Infrastructure as Code

This directory contains Terraform and Terragrunt configurations for managing the EKS infrastructure and GitOps tooling for the online inference platform.

## Architecture

```
infrastructure/
├── modules/
│   ├── eks/           # EKS cluster, VPC, node groups, security groups
│   ├── eks-addons/    # Helm add-ons (ALB Controller, KEDA, Metrics Server, etc.)
│   └── gitops/        # ArgoCD installation and bootstrap
├── live/
│   ├── terragrunt.hcl # Root Terragrunt configuration (providers, backend)
│   ├── dev/
│   │   ├── env.hcl    # Dev environment variables
│   │   ├── eks/       # Dev EKS cluster
│   │   ├── eks-addons/# Dev EKS add-ons
│   │   └── gitops/    # Dev GitOps setup
│   ├── staging/
│   └── prod/
├── scripts/
│   └── init-aws-backend.sh  # S3 + DynamoDB state backend init
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

### Deploy Dev Environment (All Stacks)

```bash
# Deploy all stacks in dependency order (eks → eks-addons → gitops)
cd infrastructure/live/dev
terragrunt run-all apply
```

### Deploy Individual Stacks

```bash
# 1. EKS cluster (VPC, node groups, security groups)
cd infrastructure/live/dev/eks
terragrunt apply

# 2. EKS add-ons (ALB Controller, KEDA, Metrics Server)
cd infrastructure/live/dev/eks-addons
terragrunt apply

# 3. GitOps (ArgoCD + Application manifest)
cd infrastructure/live/dev/gitops
terragrunt apply
```

### Get kubeconfig

```bash
aws eks update-kubeconfig --name online-inference-dev --region us-east-1
```

## Cost Optimization

The infrastructure is designed for cost-efficiency:

| Feature | Cost Impact |
|---------|-------------|
| **Spot Nodes** | ~70% cheaper than on-demand |
| **t3.medium in dev** | Smallest viable instance type |
| **Scale to zero nodes** | No EC2 cost when idle |

### Node Group Strategy

- **Primary**: On-demand nodes for critical workloads (API, Redis, observability)
- **Spot**: Spot instances for batch workers (tolerates interruptions, tainted with `spot=true:NoSchedule`)

### Scaling Down to Save Costs

```bash
# Scale node groups to zero when not testing
aws eks update-nodegroup-config \
  --cluster-name online-inference-dev \
  --nodegroup-name primary \
  --scaling-config minSize=0,maxSize=5,desiredSize=0

aws eks update-nodegroup-config \
  --cluster-name online-inference-dev \
  --nodegroup-name spot \
  --scaling-config minSize=0,maxSize=10,desiredSize=0

# Delete ALB to avoid ~$16/month
kubectl delete ingress online-inference -n inference
```

**Approximate costs at zero nodes:** EKS control plane ~$72/month, NAT Gateway ~$32/month.

## Multi-Environment Workflow

### Deploy All Environments

```bash
# Dev
cd infrastructure/live/dev && terragrunt run-all apply

# Staging (after dev is stable)
cd infrastructure/live/staging && terragrunt run-all apply

# Production (manual promotion only)
cd infrastructure/live/prod && terragrunt run-all apply
```

### Terragrunt Commands

```bash
# Plan all stacks in an environment
cd infrastructure/live/dev
terragrunt run-all plan

# Apply a single stack
cd infrastructure/live/dev/eks
terragrunt apply

# Destroy all stacks (reverse dependency order)
cd infrastructure/live/dev
terragrunt run-all destroy

# Destroy with exclusion
terragrunt run-all apply --terragrunt-exclude-dir infrastructure/live/dev/gitops
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

### EKS Module (`modules/eks`)

Creates a production-ready EKS cluster with:
- VPC with public/private subnets across 2 AZs
- NAT Gateway for private subnet egress
- EKS cluster with KMS-encrypted secrets
- Primary on-demand node group
- Spot node group with taints
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Security group rules for intra-cluster Prometheus scraping (ports 8080, 9100)
- CloudWatch logging (API, audit, authenticator, controller manager, scheduler)

### EKS Add-ons Module (`modules/eks-addons`)

Deploys cluster add-ons via Helm:
- AWS Load Balancer Controller (with IRSA)
- KEDA for event-driven autoscaling
- Metrics Server
- EBS CSI Driver
- Cluster Autoscaler

### GitOps Module (`modules/gitops`)

Installs and configures:
- ArgoCD with Helm
- ArgoCD Application manifest pointing to `charts/online-inference/`
- GHCR image pull secret

## State Management

Terraform state is stored in S3 with DynamoDB locking:
- `s3://tf-state-{account-id}-{region}/infrastructure/dev/eks/terraform.tfstate`
- `s3://tf-state-{account-id}-{region}/infrastructure/dev/eks-addons/terraform.tfstate`
- `s3://tf-state-{account-id}-{region}/infrastructure/dev/gitops/terraform.tfstate`

Locking is handled by DynamoDB table `terraform-locks`.

## Troubleshooting

### KEDA ScaledObject DNS Issues

If KEDA can't resolve Redis hostname, the template uses FQDN:
```yaml
address: "redis.{{ .Release.Namespace }}.svc.cluster.local:6379"
```

### Prometheus Scrape Failures

If Prometheus shows `context deadline exceeded` for inference-api:
1. Verify the scrape target uses the **service port** (80), not the container targetPort (8080)
2. Check that EKS security group rules allow intra-cluster traffic on ports 8080 and 9100
3. Confirm the pod has passed its startup probe (`kubectl describe pod <name> -n inference`)

### Subnet Dependency on Destroy

If `terragrunt destroy` fails with subnet/IGW dependency errors, the ALB is still attached:
```bash
# Find and delete the ALB
aws elbv2 describe-load-balancers --query "LoadBalancers[?contains(DNSName, 'onlinein')].LoadBalancerArn" --output text | \
  xargs -I{} aws elbv2 delete-load-balancer --load-balancer-arn {}

# Wait ~30 seconds, then retry destroy
terragrunt destroy
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
          cd infrastructure/live/dev
          terragrunt run-all plan
```
