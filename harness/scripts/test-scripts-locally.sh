#!/bin/bash
# Local Script Testing Framework
#
# Test Harness deployment scripts locally in the delegate container
# without triggering the full GitHub Actions + Harness pipeline
#
# Usage:
#   ./test-scripts-locally.sh <script-name> [environment]
#
# Examples:
#   ./test-scripts-locally.sh all dev
#   ./test-scripts-locally.sh fetch-changelog-artifact
#   ./test-scripts-locally.sh update-database dev
#   ./test-scripts-locally.sh deploy-application dev
#
# This script simulates what Harness does when calling the scripts

set -e

# ===== Configuration =====
SCRIPT_NAME="${1:-all}"
ENVIRONMENT="${2:-dev}"
DELEGATE_CONTAINER="harness-delegate-psr"

# Get version from latest git tag or commit
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "dev-$(git rev-parse --short HEAD)")
VERSION=${VERSION#v}  # Remove 'v' prefix

# Real configuration values
GITHUB_ORG="liquibase-examples"
DEMO_ID="psr"
DEPLOYMENT_TARGET="aws"

# AWS Parameters (from Terraform outputs)
# Find terraform directory (check multiple possible locations)
TERRAFORM_DIR=""
for dir in "terraform" "../terraform" "../../terraform" "/Users/recampbell/workspace/harness-gha-bagelstore/terraform"; do
  if [ -d "$dir" ]; then
    TERRAFORM_DIR="$dir"
    break
  fi
done

if [ -z "$TERRAFORM_DIR" ]; then
  echo "❌ Error: Cannot find terraform directory"
  echo "   Current directory: $(pwd)"
  echo "   Searched: terraform, ../terraform, ../../terraform"
  exit 1
fi

echo "✅ Found Terraform directory: $TERRAFORM_DIR"

# Get Terraform outputs as JSON
TF_OUTPUT=$(cd "$TERRAFORM_DIR" && terraform output -json 2>/dev/null)

if [ -z "$TF_OUTPUT" ]; then
  echo "❌ Error: Failed to get Terraform outputs. Run 'terraform init' and 'terraform apply' first."
  exit 1
fi

# Extract values for the environment
AWS_PARAMS=$(echo "$TF_OUTPUT" | jq -r --arg env "$ENVIRONMENT" '{
  "jdbc_url": .jdbc_urls.value[$env],
  "aws_region": .deployment_summary.value.aws_region,
  "liquibase_flows_bucket": .liquibase_flows_bucket.value,
  "rds_endpoint": .rds_endpoint.value,
  "app_runner_service_arn": .app_runner_services.value[$env].service_arn,
  "ecr_public_alias": .ecr_public_registry_alias.value,
  "demo_id": .deployment_summary.value.demo_id,
  "rds_address": .rds_address.value,
  "rds_port": .rds_port.value,
  "database_name": $env,
  "app_runner_service_name": "bagel-store-\(.deployment_summary.value.demo_id)-\($env)",
  "app_runner_service_url": .app_runner_services.value[$env].service_url,
  "secrets_username_arn": .secrets_rds_username_arn.value,
  "secrets_password_arn": .secrets_rds_password_arn.value
}')

# Read secrets from terraform.tfvars (no duplication needed!)
TFVARS_FILE="${TERRAFORM_DIR}/terraform.tfvars"

if [ -f "$TFVARS_FILE" ]; then
  echo "✅ Reading secrets from $TFVARS_FILE"
  GITHUB_PAT=$(grep "^github_pat" "$TFVARS_FILE" | cut -d'"' -f2)
  AWS_ACCESS_KEY_ID=$(grep "^aws_access_key_id" "$TFVARS_FILE" | cut -d'"' -f2)
  AWS_SECRET_ACCESS_KEY=$(grep "^aws_secret_access_key" "$TFVARS_FILE" | cut -d'"' -f2)
  LIQUIBASE_LICENSE_KEY=$(grep "^liquibase_license_key" "$TFVARS_FILE" | cut -d'"' -f2)
else
  echo "⚠️  Warning: terraform.tfvars not found at $TFVARS_FILE"
fi

# Fallback to environment variable for Liquibase license
if [ -z "$LIQUIBASE_LICENSE_KEY" ]; then
  LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY:-}"
fi

# Secrets JSON (credentials for AWS and Liquibase)
# Note: DB credentials now fetched via Liquibase native AWS Secrets Manager integration
SECRETS=$(cat <<EOF
{
  "aws_access_key_id": "${AWS_ACCESS_KEY_ID:-PLACEHOLDER}",
  "aws_secret_access_key": "${AWS_SECRET_ACCESS_KEY:-PLACEHOLDER}",
  "liquibase_license_key": "${LIQUIBASE_LICENSE_KEY:-PLACEHOLDER}"
}
EOF
)

# Service URL for health checks
SERVICE_URL=$(echo "$AWS_PARAMS" | jq -r '.app_runner_service_url')
SERVICE_NAME=$(echo "$AWS_PARAMS" | jq -r '.app_runner_service_name')

# ===== Validation =====
echo "=========================================="
echo "Local Script Testing Framework"
echo "=========================================="
echo "Script: ${SCRIPT_NAME}"
echo "Environment: ${ENVIRONMENT}"
echo "Version: ${VERSION}"
echo "Demo ID: ${DEMO_ID}"
echo "Deployment Target: ${DEPLOYMENT_TARGET}"
echo ""

# Check delegate is running
if ! docker ps | grep -q "$DELEGATE_CONTAINER"; then
  echo "❌ Delegate container not running: $DELEGATE_CONTAINER"
  echo "   Start it with: cd harness && docker compose up -d"
  exit 1
fi

# Check scripts are mounted
if ! docker exec "$DELEGATE_CONTAINER" ls /opt/harness-delegate/scripts/ > /dev/null 2>&1; then
  echo "❌ Scripts not mounted in delegate container"
  echo "   Restart delegate: cd harness && docker compose down && docker compose up -d"
  exit 1
fi

echo "✅ Delegate is running"
echo "✅ Scripts are mounted"
echo ""

# ===== Test Functions =====

test_fetch_changelog() {
  echo "=========================================="
  echo "Testing: fetch-changelog-artifact.sh"
  echo "=========================================="

  if [ -z "$GITHUB_PAT" ]; then
    echo "⚠️  Warning: GITHUB_PAT not found in terraform/terraform.tfvars"
    echo "   This test will fail without a valid GitHub PAT"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && return
  fi

  echo "✅ GitHub PAT loaded from terraform.tfvars"
  echo ""

  echo "Command:"
  echo "  docker exec $DELEGATE_CONTAINER \\"
  echo "    /opt/harness-delegate/scripts/fetch-changelog-artifact.sh \\"
  echo "    \"$VERSION\" \\"
  echo "    \"$GITHUB_ORG\" \\"
  echo "    \"$GITHUB_PAT\""
  echo ""

  docker exec "$DELEGATE_CONTAINER" \
    /opt/harness-delegate/scripts/fetch-changelog-artifact.sh \
    "$VERSION" \
    "$GITHUB_ORG" \
    "$GITHUB_PAT"

  echo ""
  echo "✅ fetch-changelog-artifact.sh completed"
  echo ""
}

test_update_database() {
  echo "=========================================="
  echo "Testing: update-database.sh"
  echo "=========================================="

  echo "Command:"
  echo "  docker exec $DELEGATE_CONTAINER bash -c '\\"
  echo "    /opt/harness-delegate/scripts/update-database.sh \\"
  echo "      \"$ENVIRONMENT\" \\"
  echo "      \"$DEMO_ID\" \\"
  echo "      \"$DEPLOYMENT_TARGET\" \\"
  echo "      '\'$AWS_PARAMS\'' \\"
  echo "      '\'$SECRETS\'''"
  echo ""

  docker exec "$DELEGATE_CONTAINER" bash -c \
    "/opt/harness-delegate/scripts/update-database.sh \
      '$ENVIRONMENT' \
      '$DEMO_ID' \
      '$DEPLOYMENT_TARGET' \
      '$AWS_PARAMS' \
      '$SECRETS'"

  echo ""
  echo "✅ update-database.sh completed"
  echo ""
}

test_deploy_application() {
  echo "=========================================="
  echo "Testing: deploy-application.sh"
  echo "=========================================="

  echo "Command:"
  echo "  docker exec $DELEGATE_CONTAINER bash -c '\\"
  echo "    /opt/harness-delegate/scripts/deploy-application.sh \\"
  echo "      \"$ENVIRONMENT\" \\"
  echo "      \"$VERSION\" \\"
  echo "      \"$GITHUB_ORG\" \\"
  echo "      \"$DEPLOYMENT_TARGET\" \\"
  echo "      '\'$AWS_PARAMS\'' \\"
  echo "      '\'$SECRETS\'''"
  echo ""

  docker exec "$DELEGATE_CONTAINER" bash -c \
    "/opt/harness-delegate/scripts/deploy-application.sh \
      '$ENVIRONMENT' \
      '$VERSION' \
      '$GITHUB_ORG' \
      '$DEPLOYMENT_TARGET' \
      '$AWS_PARAMS' \
      '$SECRETS'"

  echo ""
  echo "✅ deploy-application.sh completed"
  echo ""
}

test_health_check() {
  echo "=========================================="
  echo "Testing: health-check.sh"
  echo "=========================================="

  echo "Command:"
  echo "  docker exec $DELEGATE_CONTAINER \\"
  echo "    /opt/harness-delegate/scripts/health-check.sh \\"
  echo "    \"$ENVIRONMENT\" \\"
  echo "    \"$VERSION\" \\"
  echo "    \"$DEPLOYMENT_TARGET\" \\"
  echo "    \"$SERVICE_URL\""
  echo ""

  docker exec "$DELEGATE_CONTAINER" \
    /opt/harness-delegate/scripts/health-check.sh \
    "$ENVIRONMENT" \
    "$VERSION" \
    "$DEPLOYMENT_TARGET" \
    "$SERVICE_URL"

  echo ""
  echo "✅ health-check.sh completed"
  echo ""
}

test_fetch_instances() {
  echo "=========================================="
  echo "Testing: fetch-instances.sh"
  echo "=========================================="

  echo "Command:"
  echo "  docker exec $DELEGATE_CONTAINER \\"
  echo "    /opt/harness-delegate/scripts/fetch-instances.sh \\"
  echo "    \"$ENVIRONMENT\" \\"
  echo "    \"$DEPLOYMENT_TARGET\" \\"
  echo "    \"$SERVICE_NAME\" \\"
  echo "    \"$SERVICE_URL\""
  echo ""

  docker exec "$DELEGATE_CONTAINER" \
    /opt/harness-delegate/scripts/fetch-instances.sh \
    "$ENVIRONMENT" \
    "$DEPLOYMENT_TARGET" \
    "$SERVICE_NAME" \
    "$SERVICE_URL"

  echo ""
  echo "✅ fetch-instances.sh completed"
  echo ""
}

# ===== Main Logic =====

case "$SCRIPT_NAME" in
  fetch-changelog-artifact)
    test_fetch_changelog
    ;;

  update-database)
    test_update_database
    ;;

  deploy-application)
    test_deploy_application
    ;;

  health-check)
    test_health_check
    ;;

  fetch-instances)
    test_fetch_instances
    ;;

  all)
    echo "Testing all scripts in sequence..."
    echo ""
    test_fetch_changelog
    test_update_database
    test_deploy_application
    test_health_check
    test_fetch_instances
    ;;

  *)
    echo "❌ Unknown script: $SCRIPT_NAME"
    echo ""
    echo "Available scripts:"
    echo "  - fetch-changelog-artifact"
    echo "  - update-database"
    echo "  - deploy-application"
    echo "  - health-check"
    echo "  - fetch-instances"
    echo "  - all (run all scripts)"
    exit 1
    ;;
esac

echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
