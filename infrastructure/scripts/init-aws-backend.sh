#!/bin/bash
# Initialize AWS backend for Terraform state
# Creates S3 bucket and DynamoDB table for state locking

set -e

# Configuration
BUCKET_NAME="${TG_BUCKET:-tf-state-${AWS_ACCOUNT_ID}-${AWS_DEFAULT_REGION}}"
TABLE_NAME="terraform-locks"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo "Initializing Terraform backend for AWS..."
echo "Bucket: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo ""

# Check if bucket exists
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "✓ S3 bucket already exists: ${BUCKET_NAME}"
else
    echo "Creating S3 bucket: ${BUCKET_NAME}"

    # Create bucket (different command for us-east-1 vs other regions)
    if [ "${REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}"
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --create-bucket-configuration LocationConstraint="${REGION}"
    fi

    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled

    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }'

    # Block public access
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
            BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

    echo "✓ S3 bucket created with versioning and encryption"
fi

echo ""

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "${TABLE_NAME}" 2>/dev/null; then
    echo "✓ DynamoDB table already exists: ${TABLE_NAME}"
else
    echo "Creating DynamoDB table: ${TABLE_NAME}"

    aws dynamodb create-table \
        --table-name "${TABLE_NAME}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST

    echo "✓ DynamoDB table created"
fi

echo ""
echo "Backend initialization complete!"
echo ""
echo "Set these environment variables before running terragrunt:"
echo "  export AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}"
echo "  export AWS_DEFAULT_REGION=${REGION}"
echo "  export TG_BUCKET=${BUCKET_NAME}"
