#!/bin/bash
# Update Database with Liquibase
#
# Runs Liquibase update against target database using flow files (AWS mode)
# or direct update (local mode).
#
# Usage:
#   update-database.sh <ENVIRONMENT> <DEMO_ID> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
#
# Arguments:
#   ENVIRONMENT        - Target environment (dev/test/staging/prod)
#   DEMO_ID            - Demo instance identifier
#   DEPLOYMENT_TARGET  - Deployment mode: "aws" or "local"
#   AWS_PARAMS_JSON    - JSON with AWS parameters (for AWS mode)
#   SECRETS_JSON       - JSON with secret references (license, credentials)
#
# Exit Codes:
#   0 - Success
#   1 - Database update failed

set -e

# ===== Argument Parsing =====
if [ $# -ne 5 ]; then
  echo "Usage: $0 <ENVIRONMENT> <DEMO_ID> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>"
  echo "Example: $0 dev demo1 aws '{...}' '{...}'"
  exit 1
fi

ENVIRONMENT="$1"
DEMO_ID="$2"
DEPLOYMENT_TARGET="$3"
AWS_PARAMS_JSON="$4"
SECRETS_JSON="$5"

# ===== Configuration =====
CHANGELOG_DIR="/tmp/changelog"
LIQUIBASE_VERSION="5.0.1"

# ===== Main Logic =====
echo "=== Updating Database with Liquibase ==="
echo "Environment: ${ENVIRONMENT}"
echo "Demo ID: ${DEMO_ID}"
echo "Deployment Target: ${DEPLOYMENT_TARGET}"

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE - Use S3 Flow Files =====

  # Extract AWS parameters
  JDBC_URL=$(echo "$AWS_PARAMS_JSON" | jq -r '.jdbc_url')
  AWS_REGION=$(echo "$AWS_PARAMS_JSON" | jq -r '.aws_region')
  FLOWS_BUCKET=$(echo "$AWS_PARAMS_JSON" | jq -r '.liquibase_flows_bucket')
  RDS_ENDPOINT=$(echo "$AWS_PARAMS_JSON" | jq -r '.rds_endpoint')

  # Extract secrets
  AWS_ACCESS_KEY_ID=$(echo "$SECRETS_JSON" | jq -r '.aws_access_key_id')
  AWS_SECRET_ACCESS_KEY=$(echo "$SECRETS_JSON" | jq -r '.aws_secret_access_key')
  LIQUIBASE_LICENSE_KEY=$(echo "$SECRETS_JSON" | jq -r '.liquibase_license_key')
  DB_USERNAME=$(echo "$SECRETS_JSON" | jq -r '.db_username')
  DB_PASSWORD=$(echo "$SECRETS_JSON" | jq -r '.db_password')

  echo "Using AWS RDS endpoint: ${RDS_ENDPOINT}"
  echo "Flow file: s3://${FLOWS_BUCKET}/main-deployment-flow.yaml"

  docker run --rm \
    -v "${CHANGELOG_DIR}:/liquibase/changelog" \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -e AWS_REGION="${AWS_REGION}" \
    -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
    -e LIQUIBASE_COMMAND_URL="${JDBC_URL}" \
    -e LIQUIBASE_COMMAND_USERNAME="${DB_USERNAME}" \
    -e LIQUIBASE_COMMAND_PASSWORD="${DB_PASSWORD}" \
    -e LIQUIBASE_COMMAND_CHANGELOG_FILE=changelog-master.yaml \
    -e LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE="s3://${FLOWS_BUCKET}/liquibase.checks-settings.conf" \
    -w /liquibase/changelog \
    "liquibase/liquibase-secure:${LIQUIBASE_VERSION}" \
    flow \
    --flow-file="s3://${FLOWS_BUCKET}/main-deployment-flow.yaml"

else
  # ===== LOCAL MODE - Direct Update =====

  # Extract secrets
  LIQUIBASE_LICENSE_KEY=$(echo "$SECRETS_JSON" | jq -r '.liquibase_license_key')

  echo "Using local PostgreSQL container: postgres-${ENVIRONMENT}"
  echo "Note: Local mode uses direct update, not flow files"

  # Connect to Docker Compose network
  docker run --rm \
    --network harness-gha-bagelstore_bagel-network \
    -v "${CHANGELOG_DIR}:/liquibase/changelog" \
    -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
    "liquibase/liquibase-secure:${LIQUIBASE_VERSION}" \
    --url="jdbc:postgresql://postgres-${ENVIRONMENT}:5432/${ENVIRONMENT}" \
    --username=postgres \
    --password=postgres \
    --changeLogFile=changelog-master.yaml \
    --log-level=INFO \
    update
fi

echo "✅ Database update completed successfully"
