#!/bin/bash
# Build and Push Custom Harness Delegate Image
#
# This script builds the custom delegate image with baked-in deployment scripts
# and pushes it to AWS ECR for use by EC2 delegate.
#
# Usage:
#   ./scripts/build-delegate-image.sh
#   ./scripts/build-delegate-image.sh [aws-region]
#
# Prerequisites:
#   - AWS credentials configured (AWS_PROFILE or AWS_ACCESS_KEY_ID)
#   - Docker running locally
#   - Terraform applied (ECR repository must exist)
#
# The custom image extends the official Harness delegate and adds:
#   - Deployment scripts (harness/scripts/*.sh) baked into /opt/harness-delegate/scripts
#   - Additional tools: jq, AWS CLI v2, Docker CLI, Terraform
#
# Image tags:
#   - {delegate-version} (e.g., 25.09.86800)
#   - latest

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

# Configuration
AWS_REGION=${1:-us-east-1}
DELEGATE_VERSION="25.09.86800"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_info "Building custom Harness delegate image..."
echo "  Region: $AWS_REGION"
echo "  Delegate version: $DELEGATE_VERSION"
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

# Check Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker and try again."
    exit 1
fi
log_info "Docker is running"

# Check AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    log_error "AWS credentials not configured. Please run 'aws configure' or set AWS_PROFILE."
    exit 1
fi
CALLER_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
log_info "AWS credentials configured: $CALLER_IDENTITY"

# Check Terraform state
if [ ! -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]; then
    log_error "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi
log_info "Terraform state found"

# Get ECR repository URL from Terraform output
log_info "Getting ECR repository URL from Terraform..."
cd "$PROJECT_ROOT/terraform"
if ! ECR_REPO=$(terraform output -raw delegate_ecr_repository_url 2>/dev/null); then
    log_error "Could not get ECR repository URL from Terraform output."
    log_error "Make sure you've applied terraform/delegate-ec2.tf"
    exit 1
fi
log_info "ECR repository: $ECR_REPO"

# Login to ECR
log_info "Logging into ECR..."
if ! aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REPO" > /dev/null 2>&1; then
    log_error "Failed to login to ECR"
    exit 1
fi
log_info "Logged into ECR"

# Build image
log_info "Building Docker image..."
cd "$PROJECT_ROOT/harness"
if ! docker build \
    --platform linux/amd64 \
    --build-arg DELEGATE_VERSION="$DELEGATE_VERSION" \
    -t "harness-delegate-custom:$DELEGATE_VERSION" \
    -t "harness-delegate-custom:latest" \
    -f Dockerfile.delegate \
    . ; then
    log_error "Docker build failed"
    exit 1
fi
log_info "Image built successfully"

# Tag for ECR
log_info "Tagging image for ECR..."
docker tag "harness-delegate-custom:$DELEGATE_VERSION" "$ECR_REPO:$DELEGATE_VERSION"
docker tag "harness-delegate-custom:latest" "$ECR_REPO:latest"
log_info "Image tagged"

# Push to ECR
log_info "Pushing image to ECR (this may take a few minutes)..."
if ! docker push "$ECR_REPO:$DELEGATE_VERSION"; then
    log_error "Failed to push versioned image"
    exit 1
fi
if ! docker push "$ECR_REPO:latest"; then
    log_error "Failed to push latest image"
    exit 1
fi

# Get image digest
IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$ECR_REPO:latest" 2>/dev/null || echo "unknown")

log_info ""
log_info "════════════════════════════════════════════════════════════════"
log_info "✓ Custom delegate image successfully built and pushed to ECR"
log_info "════════════════════════════════════════════════════════════════"
echo ""
echo "Image details:"
echo "  Repository: $ECR_REPO"
echo "  Tags: $DELEGATE_VERSION, latest"
echo "  Digest: $IMAGE_DIGEST"
echo ""
echo "Next steps:"
echo ""
echo "1. Deploy EC2 delegate (if not already running):"
echo "   cd terraform && terraform apply"
echo ""
echo "2. Verify image on EC2:"
echo "   ssh ec2-user@\$(cd terraform && terraform output -raw delegate_public_ip)"
echo "   docker images | grep harness-delegate"
echo ""
echo "3. Restart delegate to use new image:"
echo "   ssh ec2-user@\$(cd terraform && terraform output -raw delegate_public_ip)"
echo "   cd /opt/harness-delegate"
echo "   aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO"
echo "   docker-compose pull"
echo "   docker-compose up -d"
echo ""
echo "4. Verify scripts in new image:"
echo "   docker exec harness-delegate-demo1 ls -la /opt/harness-delegate/scripts/"
echo ""
log_warn "Note: EC2 instance must restart delegate to use the new image"
