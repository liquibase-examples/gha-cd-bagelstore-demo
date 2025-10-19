#!/usr/bin/env bash
#
# Trigger Harness pipeline via webhook (same as GitHub Actions does)
#
# Usage:
#   ./trigger-pipeline-webhook.sh [VERSION] [DEPLOYMENT_TARGET] [GITHUB_ORG]
#
# Arguments (all optional):
#   VERSION           - Git version tag (default: auto-detect from git)
#   DEPLOYMENT_TARGET - aws or local (default: aws)
#   GITHUB_ORG        - GitHub organization (default: liquibase-examples)
#
# Examples:
#   ./trigger-pipeline-webhook.sh                    # Auto-detect version, aws target
#   ./trigger-pipeline-webhook.sh dev-abc123         # Specific version
#   ./trigger-pipeline-webhook.sh dev-abc123 local   # Local deployment mode
#

set -euo pipefail

# Load Harness configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_ENV_FILE="$REPO_ROOT/harness/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
VERSION="${1:-}"
DEPLOYMENT_TARGET="${2:-aws}"
GITHUB_ORG="${3:-liquibase-examples}"

# Auto-detect version if not provided
if [ -z "$VERSION" ]; then
  echo -e "${BLUE}Auto-detecting version from git...${NC}"
  cd "$REPO_ROOT"

  # Get short commit hash
  COMMIT_SHA=$(git rev-parse HEAD)
  SHORT_SHA=$(git rev-parse --short HEAD)

  # Check if we're on a tag
  if git describe --exact-match --tags HEAD 2>/dev/null; then
    VERSION=$(git describe --exact-match --tags HEAD)
    echo -e "${GREEN}✓ Detected tag version: $VERSION${NC}"
  else
    # Use dev-commit format (MUST match GitHub Actions main-ci.yml line 149)
    # GitHub Actions always uses "dev-" prefix when no tag exists
    VERSION="dev-${SHORT_SHA}"
    echo -e "${GREEN}✓ Detected commit version: $VERSION${NC}"
    echo -e "${YELLOW}Note: GitHub Actions builds images as 'dev-<sha>' when no git tag exists${NC}"
  fi
else
  # Get commit SHA for provided version
  cd "$REPO_ROOT"
  COMMIT_SHA=$(git rev-parse HEAD)
  SHORT_SHA=$(git rev-parse --short HEAD)
fi

# Get triggered_by from git config
TRIGGERED_BY=$(git config user.name || echo "unknown")

echo ""
echo "========================================="
echo "Harness Pipeline Webhook Trigger"
echo "========================================="
echo "VERSION:           $VERSION"
echo "DEPLOYMENT_TARGET: $DEPLOYMENT_TARGET"
echo "GITHUB_ORG:        $GITHUB_ORG"
echo "COMMIT_SHA:        $COMMIT_SHA"
echo "TRIGGERED_BY:      $TRIGGERED_BY"
echo "========================================="
echo ""

# Load webhook URL from harness/.env
if [ ! -f "$HARNESS_ENV_FILE" ]; then
  echo -e "${RED}Error: $HARNESS_ENV_FILE not found${NC}"
  exit 1
fi

# Source the env file to get HARNESS_WEBHOOK_URL
set -a
source "$HARNESS_ENV_FILE"
set +a

if [ -z "${HARNESS_WEBHOOK_URL:-}" ]; then
  echo -e "${RED}Error: HARNESS_WEBHOOK_URL not set in $HARNESS_ENV_FILE${NC}"
  echo ""
  echo "To get webhook URL, run:"
  echo "  ./scripts/harness/get-webhook-url.sh"
  exit 1
fi

# Build webhook payload
PAYLOAD=$(cat <<EOF
{
  "version": "$VERSION",
  "github_org": "$GITHUB_ORG",
  "deployment_target": "$DEPLOYMENT_TARGET",
  "branch": "main",
  "commit_sha": "$COMMIT_SHA",
  "commit_message": "Manual trigger via webhook",
  "triggered_by": "$TRIGGERED_BY",
  "run_id": "manual-$(date +%s)"
}
EOF
)

echo -e "${BLUE}Webhook payload:${NC}"
echo "$PAYLOAD" | jq .
echo ""

# Call webhook
echo -e "${BLUE}Calling Harness webhook...${NC}"
RESPONSE=$(curl -s -X POST "$HARNESS_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Parse response
STATUS=$(echo "$RESPONSE" | jq -r '.status')
EVENT_CORRELATION_ID=$(echo "$RESPONSE" | jq -r '.data.eventCorrelationId // empty')
API_URL=$(echo "$RESPONSE" | jq -r '.data.apiUrl // empty')
UI_URL=$(echo "$RESPONSE" | jq -r '.data.uiUrl // empty')

echo ""
echo "========================================="
echo "Webhook Response"
echo "========================================="
echo "Status:              $STATUS"
echo "Event Correlation ID: $EVENT_CORRELATION_ID"
echo ""

if [ "$STATUS" != "SUCCESS" ]; then
  echo -e "${RED}✗ Webhook call failed${NC}"
  echo "$RESPONSE" | jq .
  exit 1
fi

echo -e "${GREEN}✓ Webhook accepted${NC}"
echo ""

# Wait a moment for Harness to process the trigger
echo -e "${BLUE}Waiting for Harness to process trigger...${NC}"
sleep 3

# Check trigger execution status
echo ""
echo "========================================="
echo "Checking Trigger Execution Status"
echo "========================================="

TRIGGER_DETAILS=$(curl -s "$API_URL")
echo "$TRIGGER_DETAILS" | jq .

# Extract key fields
EXCEPTION_OCCURRED=$(echo "$TRIGGER_DETAILS" | jq -r '.data.webhookProcessingDetails.exceptionOccured')
TRIGGER_STATUS=$(echo "$TRIGGER_DETAILS" | jq -r '.data.webhookProcessingDetails.status')
TRIGGER_MESSAGE=$(echo "$TRIGGER_DETAILS" | jq -r '.data.webhookProcessingDetails.message // empty')
PIPELINE_EXECUTION_ID=$(echo "$TRIGGER_DETAILS" | jq -r '.data.webhookProcessingDetails.pipelineExecutionId // empty')

echo ""
echo "========================================="
echo "Trigger Processing Results"
echo "========================================="
echo "Status:       $TRIGGER_STATUS"
echo "Exception:    $EXCEPTION_OCCURRED"

if [ -n "$TRIGGER_MESSAGE" ]; then
  echo ""
  echo -e "${YELLOW}Message:${NC}"
  echo "$TRIGGER_MESSAGE" | fold -w 80 -s
fi

echo ""

if [ "$EXCEPTION_OCCURRED" == "true" ]; then
  echo -e "${RED}✗ Trigger execution failed${NC}"
  echo ""
  echo "Common issues:"
  echo "  - Template YAML validation errors"
  echo "  - Invalid runtime input values"
  echo "  - Template not refreshed in Harness UI"
  echo ""
  echo "Next steps:"
  echo "  1. Check template validation: ./scripts/templates/validate-template.sh Coordinated_DB_App_Deployment"
  echo "  2. Force refresh template: ./scripts/templates/force-refresh-template.sh Coordinated_DB_App_Deployment"
  echo "  3. View trigger details: $API_URL"
  echo "  4. Try manual UI trigger: ${UI_URL/deployments/pipelines\/Deploy_Bagel_Store\/pipeline-studio}"
  exit 1
fi

if [ -n "$PIPELINE_EXECUTION_ID" ]; then
  echo -e "${GREEN}✓ Pipeline execution started${NC}"
  echo ""
  echo "Execution ID: $PIPELINE_EXECUTION_ID"
  echo ""
  echo "To monitor execution:"
  echo "  ./scripts/harness/get-execution-details.sh $PIPELINE_EXECUTION_ID"
  echo ""
  echo "View in Harness UI:"
  echo "  $UI_URL"
  echo ""

  # Auto-monitor execution
  read -p "Monitor execution now? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Monitoring execution (Ctrl+C to stop)..."
    echo ""

    while true; do
      EXEC_DETAILS=$(./scripts/harness/harness-api.sh GET \
        "/pipeline/api/pipelines/execution/v2/${PIPELINE_EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" 2>/dev/null || echo '{}')

      EXEC_STATUS=$(echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.status // "Unknown"')

      echo -e "${BLUE}[$(date +%H:%M:%S)] Status: $EXEC_STATUS${NC}"

      # Check if execution is complete
      if [[ "$EXEC_STATUS" == "Success" ]]; then
        echo -e "${GREEN}✓ Pipeline execution succeeded${NC}"
        break
      elif [[ "$EXEC_STATUS" == "Failed" ]] || [[ "$EXEC_STATUS" == "Aborted" ]]; then
        echo -e "${RED}✗ Pipeline execution $EXEC_STATUS${NC}"
        echo ""
        echo "To view details:"
        echo "  ./scripts/harness/get-execution-details.sh $PIPELINE_EXECUTION_ID"
        break
      fi

      sleep 10
    done
  fi
else
  echo -e "${YELLOW}⚠ Pipeline execution not started yet (status: $TRIGGER_STATUS)${NC}"
  echo ""
  echo "The trigger may be queued or processing. Check status:"
  echo "  curl -s '$API_URL' | jq ."
fi

echo ""
echo "========================================="
echo "Done"
echo "========================================="
