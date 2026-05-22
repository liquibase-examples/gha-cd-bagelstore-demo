#!/bin/bash
# Rollback Application
#
# Rolls back the application to a previous version by updating the service
# to use the target version's Docker image. Mirrors deploy-application.sh
# structure for AWS (App Runner) and local (Docker Compose) modes.
#
# Usage:
#   rollback-application.sh <ENVIRONMENT> <ROLLBACK_TO_VERSION> <GITHUB_ORG> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
#
# Arguments:
#   ENVIRONMENT          - Target environment (dev/test/staging/prod)
#   ROLLBACK_TO_VERSION  - Version to rollback to (e.g., v1.0.0)
#   GITHUB_ORG           - GitHub organization name
#   DEPLOYMENT_TARGET    - Deployment mode: "aws" or "local"
#   AWS_PARAMS_JSON      - JSON with AWS parameters (for AWS mode)
#   SECRETS_JSON         - JSON with secret references (for AWS mode)
#
# Exit Codes:
#   0 - Success
#   1 - Rollback failed or invalid arguments

set -e

# ===== Argument Parsing =====
if [ $# -ne 6 ]; then
  echo "Usage: $0 <ENVIRONMENT> <ROLLBACK_TO_VERSION> <GITHUB_ORG> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>"
  echo "Example: $0 dev v1.0.0 liquibase-examples aws '{...}' '{...}'"
  exit 1
fi

ENVIRONMENT="$1"
ROLLBACK_TO_VERSION="$2"
GITHUB_ORG="$3"
DEPLOYMENT_TARGET="$4"
AWS_PARAMS_JSON="$5"
SECRETS_JSON="$6"

# ===== Validation =====
if [ -z "${ROLLBACK_TO_VERSION}" ]; then
  echo "ERROR: ROLLBACK_TO_VERSION is required but was empty"
  echo "Provide the version to rollback to (e.g., v1.0.0)"
  exit 1
fi

# ===== Main Logic =====
echo "=== Rolling Back Application ==="
echo "Environment: ${ENVIRONMENT}"
echo "Rollback to Version: ${ROLLBACK_TO_VERSION}"
echo "Deployment Target: ${DEPLOYMENT_TARGET}"

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE - App Runner =====

  # Extract AWS parameters
  SERVICE_ARN=$(echo "$AWS_PARAMS_JSON" | jq -r '.app_runner_service_arn')
  AWS_REGION=$(echo "$AWS_PARAMS_JSON" | jq -r '.aws_region')
  DEMO_ID=$(echo "$AWS_PARAMS_JSON" | jq -r '.demo_id')
  RDS_ADDRESS=$(echo "$AWS_PARAMS_JSON" | jq -r '.rds_address')
  RDS_PORT=$(echo "$AWS_PARAMS_JSON" | jq -r '.rds_port')
  DATABASE_NAME=$(echo "$AWS_PARAMS_JSON" | jq -r '.database_name')

  echo "Rolling back App Runner service: ${SERVICE_ARN}"
  echo "AWS authentication: IAM instance profile (EC2 delegate)"

  export AWS_DEFAULT_REGION="${AWS_REGION}"

  # Get Secrets Manager ARNs from AWS parameters
  SECRETS_USERNAME_ARN=$(echo "$AWS_PARAMS_JSON" | jq -r '.secrets_username_arn')
  SECRETS_PASSWORD_ARN=$(echo "$AWS_PARAMS_JSON" | jq -r '.secrets_password_arn')

  # Extract ECR alias from AWS parameters
  ECR_ALIAS=$(echo "$AWS_PARAMS_JSON" | jq -r '.ecr_public_alias')
  IMAGE_URL="public.ecr.aws/${ECR_ALIAS}/${DEMO_ID}-bagel-store:${ROLLBACK_TO_VERSION}"

  echo "Rolling back to Docker image: ${IMAGE_URL}"
  echo "Using AWS Secrets Manager for database credentials (native App Runner integration)"

  # Get current service configuration
  echo "Fetching current service configuration..."
  CURRENT_CONFIG=$(aws apprunner describe-service \
    --service-arn "${SERVICE_ARN}" \
    --region "${AWS_REGION}" \
    --query 'Service.SourceConfiguration' \
    --output json)

  # Extract current configuration values to preserve
  AUTO_DEPLOYMENTS=$(echo "$CURRENT_CONFIG" | jq -r '.AutoDeploymentsEnabled')

  # Update App Runner service with rollback version image
  echo "Updating App Runner service with rollback image..."
  aws apprunner update-service \
    --service-arn "${SERVICE_ARN}" \
    --source-configuration "{
      \"AutoDeploymentsEnabled\": ${AUTO_DEPLOYMENTS},
      \"ImageRepository\": {
        \"ImageIdentifier\": \"${IMAGE_URL}\",
        \"ImageRepositoryType\": \"ECR_PUBLIC\",
        \"ImageConfiguration\": {
          \"Port\": \"5000\",
          \"RuntimeEnvironmentVariables\": {
            \"FLASK_ENV\": \"production\",
            \"APP_VERSION\": \"${ROLLBACK_TO_VERSION}\",
            \"DB_HOST\": \"${RDS_ADDRESS}\",
            \"DB_PORT\": \"${RDS_PORT}\",
            \"DB_NAME\": \"${DATABASE_NAME}\",
            \"DEMO_ID\": \"${DEMO_ID}\",
            \"DEMO_USERNAME\": \"demo\",
            \"DEMO_PASSWORD\": \"bagels123\"
          },
          \"RuntimeEnvironmentSecrets\": {
            \"DB_USERNAME\": \"${SECRETS_USERNAME_ARN}\",
            \"DB_PASSWORD\": \"${SECRETS_PASSWORD_ARN}\"
          }
        }
      }
    }" \
    --region "${AWS_REGION}"

  echo "✅ App Runner service rollback initiated"

else
  # ===== LOCAL MODE - Docker Compose =====

  echo "Rolling back Docker Compose service"

  # Navigate to repository root
  REPO_ROOT="$HOME/workspace/harness-gha-bagelstore"
  cd "${REPO_ROOT}"

  # Ensure .env file exists
  if [ ! -f .env ]; then
    echo "Creating .env from template"
    cp .env.example .env
  fi

  # Update version in .env file
  ENV_UPPER=$(echo "${ENVIRONMENT}" | tr '[:lower:]' '[:upper:]')
  ENV_VAR="VERSION_${ENV_UPPER}"

  echo "Updating ${ENV_VAR}=${ROLLBACK_TO_VERSION} in .env"

  if grep -q "^${ENV_VAR}=" .env; then
    # Update existing line (macOS compatible)
    sed -i.bak "s/^${ENV_VAR}=.*/${ENV_VAR}=${ROLLBACK_TO_VERSION}/" .env
    rm -f .env.bak
  else
    # Add new line
    echo "${ENV_VAR}=${ROLLBACK_TO_VERSION}" >> .env
  fi

  # Show current .env state
  echo "Current .env configuration:"
  grep "^VERSION_" .env || echo "No VERSION variables found"

  # Pull rollback image version
  docker compose -f docker-compose-demo.yml pull "app-${ENVIRONMENT}"

  # Restart specific service with rollback version
  docker compose -f docker-compose-demo.yml up -d --no-deps "app-${ENVIRONMENT}"

  echo "✅ Docker Compose service rolled back"
fi

echo "✅ Application rollback to version '${ROLLBACK_TO_VERSION}' completed"
