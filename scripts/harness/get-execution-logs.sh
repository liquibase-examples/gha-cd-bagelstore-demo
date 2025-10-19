#!/bin/bash
# Get Execution Logs from Harness
#
# Downloads all logs for a pipeline execution and extracts step-level details
#
# Usage:
#   get-execution-logs.sh <EXECUTION_ID> [RUN_SEQUENCE]
#
# Arguments:
#   EXECUTION_ID  - Harness execution ID (e.g., _Ij0EJgRRmWnSPtcJ7oaOQ)
#   RUN_SEQUENCE  - Optional run number (defaults to fetching from execution details)

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/harness/.env" ]; then
  source "$PROJECT_ROOT/harness/.env"
else
  echo "Error: harness/.env not found"
  exit 1
fi

# Parse arguments
EXECUTION_ID="${1}"
RUN_SEQUENCE="${2}"

if [ -z "$EXECUTION_ID" ]; then
  echo "Usage: $0 <EXECUTION_ID> [RUN_SEQUENCE]"
  echo "Example: $0 _Ij0EJgRRmWnSPtcJ7oaOQ 13"
  exit 1
fi

# Get run sequence if not provided
if [ -z "$RUN_SEQUENCE" ]; then
  echo "Fetching execution details to get run sequence..."
  EXEC_DETAILS=$(curl -s "https://app.harness.io/gateway/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  RUN_SEQUENCE=$(echo "$EXEC_DETAILS" | jq -r '.data.pipelineExecutionSummary.runSequence')

  if [ "$RUN_SEQUENCE" = "null" ] || [ -z "$RUN_SEQUENCE" ]; then
    echo "Error: Could not determine run sequence"
    exit 1
  fi

  echo "Run Sequence: ${RUN_SEQUENCE}"
fi

# Build log prefix
PREFIX="${HARNESS_ACCOUNT_ID}/pipeline/Deploy_Bagel_Store/${RUN_SEQUENCE}/-${EXECUTION_ID}"

echo "=========================================="
echo "Harness Execution Logs"
echo "=========================================="
echo "Execution ID: ${EXECUTION_ID}"
echo "Run Sequence: ${RUN_SEQUENCE}"
echo "Log Prefix: ${PREFIX}"
echo ""

# Request log download
echo "Requesting log download from Harness Log Service..."
LOG_RESPONSE=$(curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${HARNESS_ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST \
  -H "content-type: application/json" \
  -H "x-api-key: ${HARNESS_API_KEY}")

# Check for errors
if echo "$LOG_RESPONSE" | jq -e '.status == "ERROR"' >/dev/null 2>&1; then
  echo "Error from Harness API:"
  echo "$LOG_RESPONSE" | jq .
  exit 1
fi

# Extract download URL (try both response formats)
DOWNLOAD_URL=$(echo "$LOG_RESPONSE" | jq -r '.resource.links[0].url // .link // empty')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "Error: No download URL in response"
  echo "Response:"
  echo "$LOG_RESPONSE" | jq .
  exit 1
fi

echo "Download URL obtained (expires in 24 hours)"
echo ""

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Download logs
echo "Downloading logs..."
curl -s -o "$TMP_DIR/logs.zip" "$DOWNLOAD_URL"

# Extract logs
echo "Extracting logs..."
cd "$TMP_DIR"
unzip -q logs.zip

# Find the execution directory
EXEC_DIR=$(find . -type d -name "-${EXECUTION_ID}" | head -1)

if [ -z "$EXEC_DIR" ]; then
  echo "Warning: Could not find execution directory in downloaded logs"
  echo "Contents:"
  find . -type f
  exit 1
fi

echo "=========================================="
echo "Log Files:"
echo "=========================================="
find "$EXEC_DIR" -type f | sed "s|$EXEC_DIR/||" | sort

echo ""
echo "=========================================="
echo "Checking for Errors"
echo "=========================================="

# Search for error logs in each file
ERROR_FOUND=false

for LOG_FILE in $(find "$EXEC_DIR" -type f); do
  STEP_NAME=$(basename "$(dirname "$LOG_FILE")")/$(basename "$LOG_FILE")

  # Parse log file (JSON Lines format)
  ERRORS=$(cat "$LOG_FILE" | jq -r 'select(.level == "ERROR") | .out' 2>/dev/null || true)

  if [ -n "$ERRORS" ]; then
    ERROR_FOUND=true
    echo ""
    echo "--- Errors in: $STEP_NAME ---"
    echo "$ERRORS"
  fi
done

if [ "$ERROR_FOUND" = "false" ]; then
  echo "No ERROR-level messages found in logs"
fi

echo ""
echo "=========================================="
echo "Last 50 Lines of Each Step"
echo "=========================================="

for LOG_FILE in $(find "$EXEC_DIR" -type f | sort); do
  STEP_NAME=$(basename "$(dirname "$LOG_FILE")")/$(basename "$LOG_FILE")

  echo ""
  echo "--- $STEP_NAME ---"
  cat "$LOG_FILE" | jq -r '.out // empty' 2>/dev/null | tail -50 || cat "$LOG_FILE" | tail -50
done

echo ""
echo "=========================================="
echo "Logs saved to: $TMP_DIR"
echo "To keep logs, copy before this script exits"
echo "=========================================="
