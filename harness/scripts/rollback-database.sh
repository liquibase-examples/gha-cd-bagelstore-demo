#!/bin/bash
# Rollback Database with Liquibase
#
# Rolls back database changes to a specific tagged version using the rollback
# flow file. Mirrors update-database.sh structure for AWS and local modes.
#
# Usage:
#   rollback-database.sh <ENVIRONMENT> <DEMO_ID> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON> <ROLLBACK_TAG>
#
# Arguments:
#   ENVIRONMENT        - Target environment (dev/test/staging/prod)
#   DEMO_ID            - Demo instance identifier
#   DEPLOYMENT_TARGET  - Deployment mode: "aws" or "local"
#   AWS_PARAMS_JSON    - JSON with AWS parameters (for AWS mode)
#   SECRETS_JSON       - JSON with secret references (license, credentials)
#   ROLLBACK_TAG       - Liquibase tag to rollback to (e.g., v1.0.0)
#
# Exit Codes:
#   0 - Success
#   1 - Rollback failed or invalid arguments

set -e

# ===== Argument Parsing =====
if [ $# -ne 6 ]; then
  echo "Usage: $0 <ENVIRONMENT> <DEMO_ID> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON> <ROLLBACK_TAG>"
  echo "Example: $0 dev demo1 aws '{...}' '{...}' v1.0.0"
  exit 1
fi

ENVIRONMENT="$1"
DEMO_ID="$2"
DEPLOYMENT_TARGET="$3"
AWS_PARAMS_JSON="$4"
SECRETS_JSON="$5"
ROLLBACK_TAG="$6"

# ===== Validation =====
if [ -z "${ROLLBACK_TAG}" ]; then
  echo "ERROR: ROLLBACK_TAG is required but was empty"
  echo "Provide the version tag to rollback to (e.g., v1.0.0)"
  exit 1
fi

# ===== Configuration =====
VOLUME_NAME="harness-changelog-data"
LIQUIBASE_VERSION="5.0.1"

# ===== Main Logic =====
echo "=== Rolling Back Database with Liquibase ==="
echo "Environment: ${ENVIRONMENT}"
echo "Demo ID: ${DEMO_ID}"
echo "Deployment Target: ${DEPLOYMENT_TARGET}"
echo "Rollback Tag: ${ROLLBACK_TAG}"

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE - Use S3 Rollback Flow File =====

  # DEBUG: Show received JSON
  echo "DEBUG: AWS_PARAMS_JSON received:"
  echo "$AWS_PARAMS_JSON"
  echo ""
  echo "DEBUG: SECRETS_JSON received:"
  echo "$SECRETS_JSON" | sed 's/\(license_key\)":\s*"[^"]*"/\1":"***REDACTED***"/g'
  echo ""

  # Extract AWS parameters
  JDBC_URL=$(echo "$AWS_PARAMS_JSON" | jq -r '.jdbc_url')
  AWS_REGION=$(echo "$AWS_PARAMS_JSON" | jq -r '.aws_region')
  FLOWS_BUCKET=$(echo "$AWS_PARAMS_JSON" | jq -r '.liquibase_flows_bucket')
  RDS_ENDPOINT=$(echo "$AWS_PARAMS_JSON" | jq -r '.rds_endpoint')

  # Extract secrets
  LIQUIBASE_LICENSE_KEY=$(echo "$SECRETS_JSON" | jq -r '.liquibase_license_key')

  echo "Using AWS RDS endpoint: ${RDS_ENDPOINT}"
  echo "Rollback flow file: s3://${FLOWS_BUCKET}/rollback-flow.yaml"
  echo "Database credentials: Liquibase native AWS Secrets Manager (JSON secret: ${DEMO_ID}/rds/credentials)"
  echo "AWS authentication: IAM instance profile (EC2 delegate)"

  docker run --rm \
    -v "${VOLUME_NAME}:/liquibase/changelog" \
    -e ROLLBACK_TAG="${ROLLBACK_TAG}" \
    -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
    -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
    -e AWS_REGION="${AWS_REGION}" \
    -e AWS_DEFAULT_REGION="${AWS_REGION}" \
    -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
    -e LIQUIBASE_COMMAND_URL="${JDBC_URL}" \
    -e LIQUIBASE_COMMAND_USERNAME="aws-secrets,${DEMO_ID}/rds/credentials,username" \
    -e LIQUIBASE_COMMAND_PASSWORD="aws-secrets,${DEMO_ID}/rds/credentials,password" \
    -e LIQUIBASE_COMMAND_CHANGELOG_FILE=changelog-master.yaml \
    -w /liquibase/changelog \
    "liquibase/liquibase-secure:${LIQUIBASE_VERSION}" \
    flow \
    --flow-file="s3://${FLOWS_BUCKET}/rollback-flow.yaml"

else
  # ===== LOCAL MODE - Use Local Rollback Flow File =====

  # Extract secrets
  LIQUIBASE_LICENSE_KEY=$(echo "$SECRETS_JSON" | jq -r '.liquibase_license_key')

  echo "Using local PostgreSQL container: postgres-${ENVIRONMENT}"
  echo "Using local rollback flow file"

  # Determine the repo root for mounting flow files
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

  docker run --rm \
    --network harness-gha-bagelstore_bagel-network \
    -v "${VOLUME_NAME}:/liquibase/changelog" \
    -v "${REPO_ROOT}/liquibase-flows:/liquibase/flows" \
    -e ROLLBACK_TAG="${ROLLBACK_TAG}" \
    -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
    -w /liquibase/changelog \
    "liquibase/liquibase-secure:${LIQUIBASE_VERSION}" \
    --url="jdbc:postgresql://postgres-${ENVIRONMENT}:5432/${ENVIRONMENT}" \
    --username=postgres \
    --password=postgres \
    --changeLogFile=changelog-master.yaml \
    --log-level=INFO \
    flow \
    --flow-file=/liquibase/flows/rollback-flow.yaml
fi

echo "✅ Database rollback to tag '${ROLLBACK_TAG}' completed successfully"
