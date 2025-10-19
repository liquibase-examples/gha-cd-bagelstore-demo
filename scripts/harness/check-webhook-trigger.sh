#!/usr/bin/env bash
#
# Check webhook trigger processing status and diagnose trigger failures
#
# Usage:
#   ./check-webhook-trigger.sh <EVENT_CORRELATION_ID>
#
# Example:
#   ./check-webhook-trigger.sh 68f55ac4b8288970d2cb61d4
#
# Get EVENT_CORRELATION_ID from webhook response:
#   The "eventCorrelationId" field in the webhook POST response
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

EVENT_ID="${1:-}"

if [ -z "$EVENT_ID" ]; then
  echo "Usage: $0 <EVENT_CORRELATION_ID>"
  echo ""
  echo "Get EVENT_CORRELATION_ID from webhook response:"
  echo "  {\"eventCorrelationId\": \"abc123...\"}"
  echo ""
  echo "Example:"
  echo "  $0 68f55ac4b8288970d2cb61d4"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Webhook Trigger Diagnosis"
echo "========================================="
echo "Event ID: $EVENT_ID"
echo ""

echo -e "${BLUE}Fetching trigger processing details...${NC}"

RESPONSE=$("$SCRIPT_DIR/harness-api.sh" GET \
  "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/${EVENT_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw" \
  2>/dev/null)

# Check if response is valid
if ! echo "$RESPONSE" | jq -e '.data.webhookProcessingDetails' >/dev/null 2>&1; then
  echo -e "${RED}❌ Invalid response or event not found${NC}"
  echo "$RESPONSE" | jq .
  exit 1
fi

# Extract key fields
STATUS=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.status // "UNKNOWN"')
EXCEPTION=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.exceptionOccured // false')
MESSAGE=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.message // ""')
PIPELINE_EXEC_ID=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.pipelineExecutionId // ""')
TRIGGER_ID=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.triggerIdentifier // ""')
PIPELINE_ID=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.pipelineIdentifier // ""')

echo "========================================="
echo "Trigger Processing Status"
echo "========================================="

# Color-code status
case "$STATUS" in
  SUCCESS)
    echo -e "Status:    ${GREEN}$STATUS${NC}"
    ;;
  FAILED)
    echo -e "Status:    ${RED}$STATUS${NC}"
    ;;
  QUEUED)
    echo -e "Status:    ${YELLOW}$STATUS${NC}"
    ;;
  *)
    echo -e "Status:    $STATUS"
    ;;
esac

echo "Exception: $EXCEPTION"
echo "Trigger:   $TRIGGER_ID"
echo "Pipeline:  $PIPELINE_ID"

if [ -n "$PIPELINE_EXEC_ID" ]; then
  echo -e "Execution: ${CYAN}$PIPELINE_EXEC_ID${NC}"
fi

echo ""

# Show message
if [ -n "$MESSAGE" ]; then
  echo "========================================="
  echo "Message"
  echo "========================================="
  echo "$MESSAGE"
  echo ""
fi

# If exception occurred, show full details
if [ "$EXCEPTION" = "true" ]; then
  echo "========================================="
  echo "Error Details"
  echo "========================================="

  EXCEPTION_TYPE=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.exception // "Unknown"')
  echo -e "${RED}Exception Type: $EXCEPTION_TYPE${NC}"
  echo ""

  # Show payload that caused the error
  PAYLOAD=$(echo "$RESPONSE" | jq -r '.data.webhookProcessingDetails.payload // ""')
  if [ -n "$PAYLOAD" ]; then
    echo "Payload received:"
    echo "$PAYLOAD" | jq . 2>/dev/null || echo "$PAYLOAD"
  fi
  echo ""

  # Provide specific recommendations based on exception type
  case "$EXCEPTION_TYPE" in
    INVALID_RUNTIME_INPUT_YAML)
      echo -e "${YELLOW}Common causes:${NC}"
      echo "  • environmentVariables format error in template"
      echo "  • Invalid Harness expression in pipeline/template YAML"
      echo "  • Missing required pipeline variables"
      echo ""
      echo -e "${CYAN}Next steps:${NC}"
      echo "  1. Validate template YAML:"
      echo "     ./scripts/templates/validate-template.sh Coordinated_DB_App_Deployment"
      echo "  2. Force refresh template:"
      echo "     ./scripts/templates/force-refresh-template.sh Coordinated_DB_App_Deployment"
      echo "  3. Check input set configuration:"
      echo "     ./scripts/harness/get-inputset.sh webhook_default"
      ;;

    INVALID_REQUEST)
      echo -e "${YELLOW}Common causes:${NC}"
      echo "  • Trigger configuration mismatch"
      echo "  • Input set reference incorrect"
      echo "  • Pipeline branch reference missing"
      echo ""
      echo -e "${CYAN}Next steps:${NC}"
      echo "  1. Verify trigger configuration:"
      echo "     Check input set and pipeline branch in Harness UI"
      echo "  2. Update trigger:"
      echo "     ./scripts/harness/update-trigger.sh"
      ;;

    *)
      echo -e "${YELLOW}General troubleshooting:${NC}"
      echo "  1. Check webhook configuration in GitHub"
      echo "  2. Verify trigger settings in Harness UI"
      echo "  3. Review full error details in Harness UI"
      ;;
  esac
  echo ""
fi

# If successful, show execution details
if [ "$STATUS" = "SUCCESS" ] && [ -n "$PIPELINE_EXEC_ID" ]; then
  echo "========================================="
  echo "Pipeline Execution Triggered"
  echo "========================================="
  echo -e "${GREEN}✓ Webhook processed successfully${NC}"
  echo ""
  echo "Execution ID: $PIPELINE_EXEC_ID"
  echo ""
  echo "To monitor execution:"
  echo "  ${CYAN}./scripts/harness/diagnose-execution-failure.sh $PIPELINE_EXEC_ID${NC}"
  echo ""
  echo "View in Harness UI:"
  echo "  ${CYAN}https://app.harness.io/ng/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/$PIPELINE_ID/executions/$PIPELINE_EXEC_ID/pipeline${NC}"
  echo ""
fi

# If queued, provide guidance
if [ "$STATUS" = "QUEUED" ]; then
  echo "========================================="
  echo "Trigger Queued"
  echo "========================================="
  echo -e "${YELLOW}⚠ Trigger is still processing${NC}"
  echo ""
  echo "Wait a few seconds and check again:"
  echo "  ${CYAN}$0 $EVENT_ID${NC}"
  echo ""
  echo "Or check recent executions:"
  echo "  ${CYAN}./scripts/harness/get-pipeline-executions.sh 5${NC}"
  echo ""
fi

echo "========================================="
echo "Done"
echo "========================================="
