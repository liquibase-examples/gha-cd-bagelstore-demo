#!/usr/bin/env bash
#
# Get detailed error information for a specific pipeline step
#
# Usage:
#   ./get-step-error-details.sh <EXECUTION_ID> <STEP_NAME>
#
# Example:
#   ./get-step-error-details.sh mlbW9NRGTnyuCbXo1vyZVQ "Fetch Changelog Artifact"
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

EXECUTION_ID="${1:-}"
STEP_NAME="${2:-}"

if [ -z "$EXECUTION_ID" ] || [ -z "$STEP_NAME" ]; then
  echo "Usage: $0 <EXECUTION_ID> <STEP_NAME>"
  echo ""
  echo "Example:"
  echo "  $0 mlbW9NRGTnyuCbXo1vyZVQ \"Fetch Changelog Artifact\""
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "Step Error Details"
echo "========================================="
echo "Execution ID: $EXECUTION_ID"
echo "Step Name:    $STEP_NAME"
echo ""

echo -e "${BLUE}Fetching execution details...${NC}"

# Get execution details
EXEC_RESPONSE=$("$SCRIPT_DIR/harness-api.sh" GET \
  "/pipeline/api/pipelines/execution/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" 2>/dev/null)

if [ -z "$EXEC_RESPONSE" ]; then
  echo -e "${RED}❌ Failed to fetch execution details${NC}"
  exit 1
fi

# Find node by name
NODE_DATA=$(echo "$EXEC_RESPONSE" | jq -r \
  ".data.executionGraph.nodeMap | to_entries[] | select(.value.name == \"$STEP_NAME\") | .value" 2>/dev/null)

if [ -z "$NODE_DATA" ] || [ "$NODE_DATA" = "null" ]; then
  echo -e "${RED}❌ Step '$STEP_NAME' not found in execution${NC}"
  echo ""
  echo "Available steps:"
  echo "$EXEC_RESPONSE" | jq -r '.data.executionGraph.nodeMap | to_entries[] | "  - " + .value.name' 2>/dev/null || echo "  (none)"
  exit 1
fi

# Extract details
STATUS=$(echo "$NODE_DATA" | jq -r '.status')
EXIT_CODE=$(echo "$NODE_DATA" | jq -r '.outcomes.output.exitCode // "N/A"')
FAILURE_MSG=$(echo "$NODE_DATA" | jq -r '.failureInfo.message // "No failure message"')
LOG_URL=$(echo "$NODE_DATA" | jq -r '.outcomes.log.url // ""')

echo "========================================="
echo "Step Status"
echo "========================================="
echo -e "Status:    ${YELLOW}$STATUS${NC}"
echo "Exit Code: $EXIT_CODE"
echo ""

if [ "$STATUS" = "Failed" ] || [ "$STATUS" = "Aborted" ]; then
  echo "========================================="
  echo "Failure Information"
  echo "========================================="
  echo -e "${RED}Primary Error Message:${NC}"
  echo "$FAILURE_MSG"
  echo ""

  # Extract detailed error messages from responseMessages array
  DETAILED_ERRORS=$(echo "$NODE_DATA" | jq -r \
    '.failureInfo.responseMessages[]? | select(.level == "ERROR") | .message' 2>/dev/null)

  if [ -n "$DETAILED_ERRORS" ]; then
    echo -e "${RED}Detailed Error Messages:${NC}"
    echo "$DETAILED_ERRORS" | while IFS= read -r msg; do
      echo "  • $msg"
    done
    echo ""
  fi

  # Show log download URL
  if [ -n "$LOG_URL" ]; then
    echo "========================================="
    echo "Console Logs"
    echo "========================================="
    echo -e "${CYAN}Log Download URL:${NC}"
    echo "$LOG_URL"
    echo ""
    echo -e "${YELLOW}Note: Log download requires Harness UI session token${NC}"
    echo "To view logs:"
    echo "  1. Use get-execution-logs.sh to download full ZIP"
    echo "  2. Or view in Harness UI console"
    echo ""
  fi
else
  echo -e "${GREEN}✓ Step succeeded${NC}"
fi

# Show execution URL
PIPELINE_ID=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.pipelineIdentifier')
echo "========================================="
echo "View in Harness UI"
echo "========================================="
echo "https://app.harness.io/ng/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/${PIPELINE_ID}/executions/${EXECUTION_ID}/pipeline"
echo "========================================="
