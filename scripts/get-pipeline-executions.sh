#!/bin/bash
# Get Recent Pipeline Executions and Details
# Usage: ./scripts/get-pipeline-executions.sh [limit]

# Load API key
if [ -f "harness/.env" ]; then
  source harness/.env
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
else
  echo "Error: harness/.env not found"
  exit 1
fi

if [ -z "$HARNESS_API_KEY" ]; then
  echo "Error: HARNESS_API_KEY not set in harness/.env"
  exit 1
fi

# Constants
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"
PIPELINE_ID="Deploy_Bagel_Store"
LIMIT="${1:-5}"

echo "========================================="
echo "Recent Pipeline Executions"
echo "========================================="
echo "Pipeline: Deploy_Bagel_Store"
echo "Limit: $LIMIT"
echo ""

# CORRECT ENDPOINT: POST to /pipelines/list (not GET /pipelines)
echo "Fetching pipeline list..."
PIPELINE_DATA=$(curl -s -X POST \
  "https://app.harness.io/pipeline/api/pipelines/list?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&page=0&size=10" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineSetup"}')

PIPELINE_EXISTS=$(echo "$PIPELINE_DATA" | jq -r ".data.content[] | select(.identifier == \"${PIPELINE_ID}\") | .identifier" 2>/dev/null)

if [ -z "$PIPELINE_EXISTS" ]; then
  echo "❌ Pipeline 'Deploy_Bagel_Store' not found!"
  echo ""
  echo "Available pipelines:"
  echo "$PIPELINE_DATA" | jq -r '.data.content[] | "  - \(.name) (\(.identifier))"' 2>/dev/null || echo "  Error parsing pipeline list"
  exit 1
fi

echo "✅ Pipeline found: Deploy_Bagel_Store"
echo ""

# Get recent executions
echo "Fetching last ${LIMIT} executions..."
echo ""

EXECUTIONS=$(curl -s -X POST \
  "https://app.harness.io/pipeline/api/pipelines/execution/summary?routingId=${ACCOUNT_ID}&accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pipelineIdentifier=${PIPELINE_ID}&page=0&size=${LIMIT}" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineExecution"}')

# Check for errors
STATUS=$(echo "$EXECUTIONS" | jq -r '.status // "UNKNOWN"')
if [ "$STATUS" != "SUCCESS" ]; then
  echo "❌ API Error:"
  echo "$EXECUTIONS" | jq '.'
  exit 1
fi

# Display executions in a table format
echo "RECENT EXECUTIONS:"
echo "------------------------------------------------------------------------------------------------------"
printf "%-8s | %-20s | %-12s | %-25s | %s\n" "RUN #" "STATUS" "TRIGGER" "START TIME" "EXECUTION ID"
echo "------------------------------------------------------------------------------------------------------"

echo "$EXECUTIONS" | jq -r '.data.content[] | 
  "\(.runSequence) | \(.status) | \(.executionTriggerInfo.triggerType) | \(.startTs) | \(.planExecutionId)"' | \
  while IFS='|' read -r run status trigger start_ts exec_id; do
    # Convert timestamp to readable date
    if [ "$(uname)" = "Darwin" ]; then
      # macOS
      start_date=$(date -r "$((start_ts / 1000))" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
    else
      # Linux
      start_date=$(date -d "@$((start_ts / 1000))" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "N/A")
    fi
    printf "%-8s | %-20s | %-12s | %-25s | %s\n" \
      "$run" "$status" "$trigger" "$start_date" "$exec_id"
  done

echo "------------------------------------------------------------------------------------------------------"
echo ""

# Get details of most recent execution
LATEST_EXEC_ID=$(echo "$EXECUTIONS" | jq -r '.data.content[0].planExecutionId')
LATEST_STATUS=$(echo "$EXECUTIONS" | jq -r '.data.content[0].status')

echo "========================================="
echo "Latest Execution Details"
echo "========================================="
echo "Execution ID: $LATEST_EXEC_ID"
echo "Status: $LATEST_STATUS"
echo ""

# Get full execution details
EXEC_DETAILS=$(curl -s \
  "https://app.harness.io/pipeline/api/pipelines/execution/v2/${LATEST_EXEC_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}")

echo "Trigger Info:"
echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.executionTriggerInfo | 
  "  Type: \(.triggerType)\n  Triggered By: \(.triggeredBy.identifier)"'
echo ""

echo "Stage Status:"
echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.layoutNodeMap | 
  to_entries[] | 
  select(.value.nodeGroup == "STAGE") | 
  "  - \(.value.name): \(.value.status)"'
echo ""

if [ "$LATEST_STATUS" = "Aborted" ]; then
  echo "Abort Info:"
  echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.abortedBy | 
    "  Aborted By: \(.userName)\n  Time: \(.createdAt)"'
  echo ""
fi

echo "Git Details:"
echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.gitDetails | 
  "  Branch: \(.branch)\n  File Path: \(.filePath)\n  Repo: \(.repoName)"'
echo ""

echo "========================================="
echo "Trigger Configuration Check"
echo "========================================="

# Get trigger configuration
TRIGGER_CONFIG=$(curl -s \
  "https://app.harness.io/pipeline/api/triggers/GitHub_Actions_CI?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}")

# IMPORTANT: inputSetRefs and pipelineBranchName are in YAML, not JSON fields
# Extract YAML and parse it
TRIGGER_YAML=$(echo "$TRIGGER_CONFIG" | jq -r '.data.yaml // ""')

# Parse inputSetRefs from YAML (array format: "- webhook_default" or "  - webhook_default")
INPUT_SET_REFS=$(echo "$TRIGGER_YAML" | grep -A5 "inputSetRefs:" | grep "^ *- " | sed 's/^ *- //' | tr '\n' ',' | sed 's/,$//')

# Parse pipelineBranchName from YAML
PIPELINE_BRANCH=$(echo "$TRIGGER_YAML" | grep "pipelineBranchName:" | sed 's/.*pipelineBranchName: *//' | tr -d '\n')

if [ -z "$INPUT_SET_REFS" ]; then
  echo "❌ WARNING: Trigger has NO Input Set configured!"
  echo "   Pipeline variables will not be resolved from webhook payload"
  echo "   Fix: Run ./scripts/update-trigger.sh or edit in UI"
else
  echo "✅ Input Set configured: $INPUT_SET_REFS"
fi

if [ -z "$PIPELINE_BRANCH" ]; then
  echo "❌ WARNING: Trigger has NO Pipeline Reference Branch configured!"
  echo "   Remote pipelines require this to fetch from Git"
  echo "   Fix: Run ./scripts/update-trigger.sh or edit in UI"
else
  echo "✅ Pipeline Branch configured: $PIPELINE_BRANCH"
fi
echo ""

echo "========================================="
echo "To view in Harness UI:"
echo "https://app.harness.io/ng/account/${ACCOUNT_ID}/cd/orgs/${ORG_ID}/projects/${PROJECT_ID}/pipelines/${PIPELINE_ID}/executions/${LATEST_EXEC_ID}/pipeline"
echo "========================================="
