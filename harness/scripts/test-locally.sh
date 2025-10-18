#!/bin/bash
# Test Deployment Scripts Locally
#
# This script allows you to test deployment scripts directly in the delegate
# container using real parameter values, without triggering a full pipeline run.
#
# Usage:
#   ./test-locally.sh <script-name> [environment]
#
# Examples:
#   ./test-locally.sh fetch-changelog-artifact
#   ./test-locally.sh update-database dev
#   ./test-locally.sh deploy-application dev
#   ./test-locally.sh health-check dev
#   ./test-locally.sh fetch-instances dev
#   ./test-locally.sh all dev
#
# Arguments:
#   script-name  - Name of script to test (or "all" to test all)
#   environment  - Target environment (dev/test/staging/prod) - default: dev

set -e

# ===== Configuration =====
SCRIPT_NAME="${1:-fetch-changelog-artifact}"
ENVIRONMENT="${2:-dev}"
DELEGATE_CONTAINER="harness-delegate-psr"

# Get current commit SHA as VERSION
VERSION=$(git log --oneline -1 | awk '{print $1}')

# Real values (update these if your setup differs)
GITHUB_ORG="liquibase-examples"
DEMO_ID="psr"
DEPLOYMENT_TARGET="aws"

# Read GitHub PAT from harness/.env file
if [ -f ../harness/.env ]; then
  source ../harness/.env
fi

if [ -z "$GITHUB_PAT" ]; then
  echo "⚠️  Warning: GITHUB_PAT not set. Reading from harness/.env..."
  if [ -f /Users/recampbell/workspace/harness-gha-bagelstore/harness/.env ]; then
    GITHUB_PAT=$(grep "^GITHUB_PAT=" /Users/recampbell/workspace/harness-gha-bagelstore/harness/.env | cut -d= -f2)
  fi
fi

# AWS Parameters (for AWS mode)
AWS_PARAMS_JSON='{
  "jdbc_url": "jdbc:postgresql://demo1-bagel-dev.xxxxx.us-east-1.rds.amazonaws.com:5432/dev",
  "aws_region": "us-east-1",
  "liquibase_flows_bucket": "demo1-bagel-flows",
  "rds_endpoint": "demo1-bagel-dev.xxxxx.us-east-1.rds.amazonaws.com",
  "app_runner_service_arn": "arn:aws:apprunner:us-east-1:xxxxx:service/demo1-bagel-dev/xxxxx",
  "demo_id": "demo1",
  "rds_address": "demo1-bagel-dev.xxxxx.us-east-1.rds.amazonaws.com",
  "rds_port": "5432",
  "database_name": "dev",
  "app_runner_service_name": "demo1-bagel-dev",
  "app_runner_service_url": "xxxxx.us-east-1.awsapprunner.com"
}'

# Secrets JSON (placeholders - will be populated from Harness in real execution)
SECRETS_JSON='{
  "aws_access_key_id": "PLACEHOLDER",
  "aws_secret_access_key": "PLACEHOLDER",
  "liquibase_license_key": "PLACEHOLDER",
  "db_username": "PLACEHOLDER",
  "db_password": "PLACEHOLDER"
}'

# ===== Helper Functions =====
test_script() {
  local script="$1"
  echo ""
  echo "=========================================="
  echo "Testing: $script"
  echo "=========================================="

  case "$script" in
    fetch-changelog-artifact)
      echo "Command:"
      echo "  docker exec $DELEGATE_CONTAINER /opt/harness-delegate/scripts/fetch-changelog-artifact.sh \\"
      echo "    \"$VERSION\" \\"
      echo "    \"$GITHUB_ORG\" \\"
      echo "    \"$GITHUB_PAT\""
      echo ""
      read -p "Execute? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker exec "$DELEGATE_CONTAINER" \
          /opt/harness-delegate/scripts/fetch-changelog-artifact.sh \
          "$VERSION" \
          "$GITHUB_ORG" \
          "$GITHUB_PAT"
      fi
      ;;

    update-database)
      echo "Command:"
      echo "  docker exec $DELEGATE_CONTAINER /opt/harness-delegate/scripts/update-database.sh \\"
      echo "    \"$ENVIRONMENT\" \\"
      echo "    \"$DEMO_ID\" \\"
      echo "    \"$DEPLOYMENT_TARGET\" \\"
      echo "    '$AWS_PARAMS_JSON' \\"
      echo "    '$SECRETS_JSON'"
      echo ""
      echo "⚠️  NOTE: This will attempt to run Liquibase - requires:"
      echo "  - Valid AWS credentials in SECRETS_JSON"
      echo "  - Changelog artifact in /tmp/changelog (run fetch-changelog-artifact first)"
      echo ""
      read -p "Execute? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker exec "$DELEGATE_CONTAINER" bash -c \
          "/opt/harness-delegate/scripts/update-database.sh \
          '$ENVIRONMENT' \
          '$DEMO_ID' \
          '$DEPLOYMENT_TARGET' \
          '$AWS_PARAMS_JSON' \
          '$SECRETS_JSON'"
      fi
      ;;

    deploy-application)
      echo "Command:"
      echo "  docker exec $DELEGATE_CONTAINER /opt/harness-delegate/scripts/deploy-application.sh \\"
      echo "    \"$ENVIRONMENT\" \\"
      echo "    \"$VERSION\" \\"
      echo "    \"$GITHUB_ORG\" \\"
      echo "    \"$DEPLOYMENT_TARGET\" \\"
      echo "    '$AWS_PARAMS_JSON' \\"
      echo "    '$SECRETS_JSON'"
      echo ""
      echo "⚠️  NOTE: This will deploy to AWS App Runner - requires valid credentials"
      echo ""
      read -p "Execute? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker exec "$DELEGATE_CONTAINER" bash -c \
          "/opt/harness-delegate/scripts/deploy-application.sh \
          '$ENVIRONMENT' \
          '$VERSION' \
          '$GITHUB_ORG' \
          '$DEPLOYMENT_TARGET' \
          '$AWS_PARAMS_JSON' \
          '$SECRETS_JSON'"
      fi
      ;;

    health-check)
      SERVICE_URL=$(echo "$AWS_PARAMS_JSON" | jq -r '.app_runner_service_url')
      echo "Command:"
      echo "  docker exec $DELEGATE_CONTAINER /opt/harness-delegate/scripts/health-check.sh \\"
      echo "    \"$ENVIRONMENT\" \\"
      echo "    \"$VERSION\" \\"
      echo "    \"$DEPLOYMENT_TARGET\" \\"
      echo "    \"$SERVICE_URL\""
      echo ""
      read -p "Execute? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker exec "$DELEGATE_CONTAINER" \
          /opt/harness-delegate/scripts/health-check.sh \
          "$ENVIRONMENT" \
          "$VERSION" \
          "$DEPLOYMENT_TARGET" \
          "$SERVICE_URL"
      fi
      ;;

    fetch-instances)
      SERVICE_NAME=$(echo "$AWS_PARAMS_JSON" | jq -r '.app_runner_service_name')
      SERVICE_URL=$(echo "$AWS_PARAMS_JSON" | jq -r '.app_runner_service_url')
      echo "Command:"
      echo "  docker exec $DELEGATE_CONTAINER /opt/harness-delegate/scripts/fetch-instances.sh \\"
      echo "    \"$ENVIRONMENT\" \\"
      echo "    \"$DEPLOYMENT_TARGET\" \\"
      echo "    \"$SERVICE_NAME\" \\"
      echo "    \"$SERVICE_URL\""
      echo ""
      read -p "Execute? (y/N) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker exec "$DELEGATE_CONTAINER" \
          /opt/harness-delegate/scripts/fetch-instances.sh \
          "$ENVIRONMENT" \
          "$DEPLOYMENT_TARGET" \
          "$SERVICE_NAME" \
          "$SERVICE_URL"
      fi
      ;;

    *)
      echo "❌ Unknown script: $script"
      echo ""
      echo "Available scripts:"
      echo "  - fetch-changelog-artifact"
      echo "  - update-database"
      echo "  - deploy-application"
      echo "  - health-check"
      echo "  - fetch-instances"
      exit 1
      ;;
  esac
}

# ===== Main Logic =====
echo "=========================================="
echo "Deployment Script Local Testing"
echo "=========================================="
echo "Delegate Container: $DELEGATE_CONTAINER"
echo "Environment: $ENVIRONMENT"
echo "Version: $VERSION"
echo "GitHub Org: $GITHUB_ORG"
echo "Deployment Target: $DEPLOYMENT_TARGET"
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

echo "✅ Delegate is running and scripts are mounted"
echo ""

if [ "$SCRIPT_NAME" = "all" ]; then
  test_script "fetch-changelog-artifact"
  test_script "health-check"
  test_script "fetch-instances"
  # Skip update-database and deploy-application in "all" mode (too dangerous)
  echo ""
  echo "⚠️  Skipped: update-database, deploy-application (run individually if needed)"
else
  test_script "$SCRIPT_NAME"
fi

echo ""
echo "=========================================="
echo "Testing Complete!"
echo "=========================================="
