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
# CRITICAL: All logging must go to stderr >&2
# Harness expects ONLY valid JSON on stdout

echo "=== Fetching Instance Information ===" >&2
echo "DEBUG: ENVIRONMENT='${ENVIRONMENT}'" >&2
echo "DEBUG: DEPLOYMENT_TARGET='${DEPLOYMENT_TARGET}'" >&2
echo "DEBUG: SERVICE_NAME='${SERVICE_NAME}'" >&2
echo "DEBUG: SERVICE_URL='${SERVICE_URL}'" >&2

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE - App Runner Instance =====
  echo "Instance Name: ${SERVICE_NAME}" >&2
  echo "Instance URL: ${SERVICE_URL}" >&2

  # Output instance in Harness format (JSON)
  # When called from CustomDeployment fetchInstancesScript: write to $INSTANCE_OUTPUT_PATH
  # When called from regular step: write to stdout
  JSON_OUTPUT="{\"instances\": [{\"instanceName\": \"${SERVICE_NAME}\", \"instanceUrl\": \"${SERVICE_URL}\"}]}"

  if [ -n "$INSTANCE_OUTPUT_PATH" ]; then
    echo "$JSON_OUTPUT" > "$INSTANCE_OUTPUT_PATH"
    echo "Wrote instance info to: $INSTANCE_OUTPUT_PATH" >&2
  else
    echo "$JSON_OUTPUT"
  fi

else
  # ===== LOCAL MODE - Docker Compose Container =====
  CONTAINER_NAME="app-${ENVIRONMENT}"

  # Get container ID if running
  CONTAINER_ID=$(docker ps -q -f "name=${CONTAINER_NAME}" || echo "unknown")

  echo "Container Name: ${CONTAINER_NAME}" >&2
  echo "Container ID: ${CONTAINER_ID}" >&2

  # Output instance in Harness format (JSON)
  # When called from CustomDeployment fetchInstancesScript: write to $INSTANCE_OUTPUT_PATH
  # When called from regular step: write to stdout
  JSON_OUTPUT="{\"instances\": [{\"instanceName\": \"${CONTAINER_NAME}\", \"instanceId\": \"${CONTAINER_ID}\"}]}"

  if [ -n "$INSTANCE_OUTPUT_PATH" ]; then
    echo "$JSON_OUTPUT" > "$INSTANCE_OUTPUT_PATH"
    echo "Wrote instance info to: $INSTANCE_OUTPUT_PATH" >&2
  else
    echo "$JSON_OUTPUT"
  fi
fi
