#!/usr/bin/env bash
#
# Diagnose Harness Pipeline Execution Failures
#
# Quickly identifies which steps failed/aborted and why by parsing the execution graph.
# For deep dive log analysis, use get-execution-logs.sh
#
# Usage:
#   ./diagnose-execution-failure.sh <EXECUTION_ID>
#
# Example:
#   ./diagnose-execution-failure.sh mlbW9NRGTnyuCbXo1vyZVQ
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

# Parse arguments
EXECUTION_ID="${1:-}"

if [ -z "$EXECUTION_ID" ]; then
  echo "Usage: $0 <EXECUTION_ID>"
  echo ""
  echo "Example:"
  echo "  $0 mlbW9NRGTnyuCbXo1vyZVQ"
  echo ""
  echo "To get recent execution IDs:"
  echo "  ./scripts/harness/get-pipeline-executions.sh 5"
  exit 1
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "========================================="
echo "Harness Execution Failure Diagnosis"
echo "========================================="
echo "Execution ID: $EXECUTION_ID"
echo ""

# Fetch execution details using our wrapper
echo -e "${BLUE}Fetching execution details...${NC}"
EXEC_RESPONSE=$("$SCRIPT_DIR/harness-api.sh" GET \
  "/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  2>/dev/null)

# Check if response is valid
if ! echo "$EXEC_RESPONSE" | jq -e '.data' >/dev/null 2>&1; then
  echo -e "${RED}Error: Invalid response from Harness API${NC}"
  echo "$EXEC_RESPONSE" | jq .
  exit 1
fi

# Extract summary info
PIPELINE_NAME=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.name')
STATUS=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.status')
RUN_SEQUENCE=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.runSequence')
START_TS=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.startTs')
END_TS=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.endTs // "null"')

# Calculate duration
if [ "$END_TS" != "null" ]; then
  DURATION_MS=$((END_TS - START_TS))
  DURATION_SEC=$((DURATION_MS / 1000))
  DURATION="${DURATION_SEC}s"
else
  DURATION="In Progress"
fi

# Convert timestamps to readable format
START_TIME=$(date -r $((START_TS / 1000)) "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")

echo "========================================="
echo "Execution Summary"
echo "========================================="
echo "Pipeline:     $PIPELINE_NAME"
echo "Run:          #$RUN_SEQUENCE"
echo "Status:       $STATUS"
echo "Started:      $START_TIME"
echo "Duration:     $DURATION"
echo ""

# Check for abort info
ABORTED_BY=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.executionErrorInfo.message // empty')
if [ -n "$ABORTED_BY" ]; then
  echo -e "${YELLOW}Abort/Error Message:${NC}"
  echo "$ABORTED_BY" | fold -w 80 -s
  echo ""
fi

# Parse execution graph for failed/aborted nodes
echo "========================================="
echo "Step Analysis"
echo "========================================="

# Extract all nodes with non-success status
PROBLEM_NODES=$(echo "$EXEC_RESPONSE" | jq -r '
  .data.executionGraph.nodeMap // {} |
  to_entries[] |
  select(.value.status != "Success" and .value.status != "NotStarted" and .value.status != "Skipped") |
  {
    uuid: .key,
    name: .value.name,
    status: .value.status,
    nodeType: .value.stepType // .value.nodeType // "Unknown",
    failureInfo: (.value.failureInfo.message // .value.failureInfo.responseMessages[0].message.message // "No failure message"),
    startTs: .value.startTs,
    endTs: .value.endTs
  }
' | jq -s '.')

PROBLEM_COUNT=$(echo "$PROBLEM_NODES" | jq 'length')

if [ "$PROBLEM_COUNT" -eq 0 ]; then
  echo -e "${GREEN}✓ No failed or aborted steps found${NC}"
  echo ""
  echo "All steps either succeeded, were not started, or were skipped."
  echo ""

  # Check for overall execution errors
  EXEC_ERROR=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.executionErrorInfo // empty')
  if [ -n "$EXEC_ERROR" ]; then
    echo -e "${YELLOW}However, execution has error info:${NC}"
    echo "$EXEC_ERROR" | jq .
  fi

  exit 0
fi

echo -e "${YELLOW}Found $PROBLEM_COUNT step(s) with issues:${NC}"
echo ""

# Display problem nodes in table format
printf "%-40s %-15s %-10s\n" "STEP NAME" "STATUS" "DURATION"
printf "%.s-" {1..70}
echo ""

echo "$PROBLEM_NODES" | jq -r '.[] |
  @json' | while read -r node; do
  NAME=$(echo "$node" | jq -r '.name')
  STATUS=$(echo "$node" | jq -r '.status')
  START=$(echo "$node" | jq -r '.startTs // "null"')
  END=$(echo "$node" | jq -r '.endTs // "null"')

  # Calculate duration
  if [ "$START" != "null" ] && [ "$END" != "null" ]; then
    DUR_MS=$((END - START))
    DUR_SEC=$((DUR_MS / 1000))
    DUR="${DUR_SEC}s"
  else
    DUR="N/A"
  fi

  # Color status
  case "$STATUS" in
    Failed)
      STATUS_COLORED="${RED}Failed${NC}"
      ;;
    Aborted)
      STATUS_COLORED="${YELLOW}Aborted${NC}"
      ;;
    *)
      STATUS_COLORED="$STATUS"
      ;;
  esac

  printf "%-40s %-25s %-10s\n" "$NAME" "$(echo -e $STATUS_COLORED)" "$DUR"
done

echo ""
echo "========================================="
echo "Failure Details"
echo "========================================="

# Show detailed failure info for each problem node
echo "$PROBLEM_NODES" | jq -r '.[] | @json' | while read -r node; do
  NAME=$(echo "$node" | jq -r '.name')
  STATUS=$(echo "$node" | jq -r '.status')
  NODE_TYPE=$(echo "$node" | jq -r '.nodeType')
  FAILURE_MSG=$(echo "$node" | jq -r '.failureInfo')

  echo ""
  echo -e "${BOLD}Step: $NAME${NC}"
  echo -e "  Status:  ${YELLOW}$STATUS${NC}"
  echo -e "  Type:    $NODE_TYPE"

  if [ "$FAILURE_MSG" != "No failure message" ] && [ "$FAILURE_MSG" != "null" ]; then
    echo -e "  ${RED}Error:${NC}"
    echo "  $FAILURE_MSG" | fold -w 76 -s | sed 's/^/    /'
  fi
done

echo ""
echo "========================================="
echo "Next Steps"
echo "========================================="

# Provide recommendations based on status
if [ "$STATUS" = "Failed" ]; then
  echo "Pipeline execution FAILED. Recommended actions:"
  echo ""
  echo "1. Review error messages above"
  echo "2. Download full logs for detailed analysis:"
  echo "   ${CYAN}./scripts/harness/get-execution-logs.sh $EXECUTION_ID${NC}"
  echo ""
  echo "3. Check stage-specific logs:"
  echo "   ${CYAN}./scripts/harness/get-stage-logs.sh $EXECUTION_ID \"<stage_name>\"${NC}"
  echo ""
  echo "4. View execution in Harness UI:"
  echo "   ${CYAN}https://app.harness.io/ng/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/executions/$EXECUTION_ID/pipeline${NC}"

elif [ "$STATUS" = "Aborted" ]; then
  echo "Pipeline execution was ABORTED."
  echo ""

  # Check if it was user aborted or system aborted
  ABORT_USER=$(echo "$EXEC_RESPONSE" | jq -r '.data.pipelineExecutionSummary.executionErrorInfo.message // empty' | grep -i "aborted" || echo "")

  if [ -n "$ABORT_USER" ]; then
    echo "Abort reason: System aborted (likely due to failure)"
    echo ""
    echo "Recommended actions:"
    echo "1. Fix errors identified above"
    echo "2. Check template/pipeline YAML validation"
    echo "3. Force refresh template if recently changed:"
    echo "   ${CYAN}./scripts/templates/force-refresh-template.sh Coordinated_DB_App_Deployment${NC}"
  else
    echo "Abort reason: User aborted or timeout"
  fi

  echo ""
  echo "To retry:"
  echo "  ${CYAN}./scripts/harness/trigger-pipeline-webhook.sh${NC}"
fi

echo ""
echo "========================================="
echo "Done"
echo "========================================="
