#!/bin/bash
# Fetch Instances
#
# Reports instance information to Harness for deployment tracking.
# Required for CustomDeployment templates.
#
# Usage:
#   fetch-instances.sh <ENVIRONMENT> <DEPLOYMENT_TARGET> <SERVICE_NAME> <SERVICE_URL>
#
# Arguments:
#   ENVIRONMENT        - Target environment (dev/test/staging/prod)
#   DEPLOYMENT_TARGET  - Deployment mode: "aws" or "local"
#   SERVICE_NAME       - Service name (for AWS mode)
#   SERVICE_URL        - Service URL (for AWS mode)
#
# Exit Codes:
#   0 - Success

set -e

# ===== Argument Parsing =====
if [ $# -ne 4 ]; then
  echo "Usage: $0 <ENVIRONMENT> <DEPLOYMENT_TARGET> <SERVICE_NAME> <SERVICE_URL>"
  echo "Example: $0 dev aws demo1-bagel-dev myapp.us-east-1.awsapprunner.com"
  exit 1
fi

ENVIRONMENT="$1"
DEPLOYMENT_TARGET="$2"
SERVICE_NAME="$3"
SERVICE_URL="$4"

# ===== Main Logic =====
echo "=== Fetching Instance Information ==="

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE - App Runner Instance =====
  echo "Instance Name: ${SERVICE_NAME}"
  echo "Instance URL: ${SERVICE_URL}"

  # Output instance in Harness format (JSON)
  echo "{\"instances\": [{\"instanceName\": \"${SERVICE_NAME}\", \"instanceUrl\": \"${SERVICE_URL}\"}]}"

else
  # ===== LOCAL MODE - Docker Compose Container =====
  CONTAINER_NAME="app-${ENVIRONMENT}"

  # Get container ID if running
  CONTAINER_ID=$(docker ps -q -f "name=${CONTAINER_NAME}" || echo "unknown")

  echo "Container Name: ${CONTAINER_NAME}"
  echo "Container ID: ${CONTAINER_ID}"

  # Output instance in Harness format (JSON)
  echo "{\"instances\": [{\"instanceName\": \"${CONTAINER_NAME}\", \"instanceId\": \"${CONTAINER_ID}\"}]}"
fi
