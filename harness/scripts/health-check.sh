#!/bin/bash
# Health Check
#
# Verifies the deployed application is healthy and running the correct version.
# Waits up to 5 minutes for service to become ready.
#
# Usage:
#   health-check.sh <ENVIRONMENT> <VERSION> <DEPLOYMENT_TARGET> <SERVICE_URL>
#
# Arguments:
#   ENVIRONMENT        - Target environment (dev/test/staging/prod)
#   VERSION            - Expected version
#   DEPLOYMENT_TARGET  - Deployment mode: "aws" or "local"
#   SERVICE_URL        - Service URL (for AWS mode, empty for local)
#
# Exit Codes:
#   0 - Health check passed
#   1 - Health check failed

set -e

# ===== Argument Parsing =====
if [ $# -ne 4 ]; then
  echo "Usage: $0 <ENVIRONMENT> <VERSION> <DEPLOYMENT_TARGET> <SERVICE_URL>"
  echo "Example: $0 dev v1.0.0 aws myapp.us-east-1.awsapprunner.com"
  exit 1
fi

ENVIRONMENT="$1"
VERSION="$2"
DEPLOYMENT_TARGET="$3"
SERVICE_URL="$4"

# ===== Configuration =====
MAX_ATTEMPTS=30
RETRY_INTERVAL=10

# ===== Main Logic =====
echo "=== Performing Health Check ==="
echo "Environment: ${ENVIRONMENT}"
echo "Expected Version: ${VERSION}"
echo "Deployment Target: ${DEPLOYMENT_TARGET}"

# Determine URLs based on deployment mode
if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # ===== AWS MODE =====
  HEALTH_URL="https://${SERVICE_URL}/health"
  VERSION_URL="https://${SERVICE_URL}/version"
else
  # ===== LOCAL MODE =====
  case "${ENVIRONMENT}" in
    dev)     PORT=5001 ;;
    test)    PORT=5002 ;;
    staging) PORT=5003 ;;
    prod)    PORT=5004 ;;
    *)
      echo "❌ Unknown environment: ${ENVIRONMENT}"
      exit 1
      ;;
  esac
  HEALTH_URL="http://localhost:${PORT}/health"
  VERSION_URL="http://localhost:${PORT}/version"
fi

echo "Health check URL: ${HEALTH_URL}"

# Wait for service to be ready (max 5 minutes)
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  echo "Attempt $((ATTEMPT + 1))/${MAX_ATTEMPTS}..."

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_URL}" || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Health check passed!"

    # Verify version
    VERSION_RESPONSE=$(curl -s "${VERSION_URL}" || echo "{}")
    echo "Version info: ${VERSION_RESPONSE}"

    DEPLOYED_VERSION=$(echo "${VERSION_RESPONSE}" | jq -r '.version // "unknown"')

    if [ "$DEPLOYED_VERSION" = "$VERSION" ]; then
      echo "✅ Version verified: ${DEPLOYED_VERSION}"
      exit 0
    else
      echo "⚠️  Version mismatch: expected ${VERSION}, got ${DEPLOYED_VERSION}"
      echo "Deployment may still be in progress, will retry..."
    fi
  fi

  echo "Health check returned HTTP ${HTTP_CODE}, retrying in ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
  ATTEMPT=$((ATTEMPT + 1))
done

echo "❌ Health check failed after ${MAX_ATTEMPTS} attempts (${MAX_ATTEMPTS}0 seconds)"
echo "Last status: HTTP ${HTTP_CODE}"
if [ -n "$DEPLOYED_VERSION" ]; then
  echo "Last version seen: ${DEPLOYED_VERSION} (expected: ${VERSION})"
fi
echo "Deployment timed out - App Runner may still be deploying"
exit 1
