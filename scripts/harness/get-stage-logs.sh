#!/bin/bash

# Get Harness API key from harness/.env
if [ -f "harness/.env" ]; then
  source harness/.env
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
else
  echo "Error: harness/.env not found"
  exit 1
fi

if [ -z "$HARNESS_API_KEY" ]; then
  echo "Error: HARNESS_API_KEY not found in harness/.env"
  exit 1
fi

EXECUTION_ID="${1:-rnxCKmd0QP2q5RI0DQnFDg}"
STAGE_NODE_EXECUTION_ID="${2:-5M5OuKtWThane76Hkc74bA}"

echo "Fetching logs for execution: $EXECUTION_ID, stage: $STAGE_NODE_EXECUTION_ID"
echo ""

# Get node execution details
curl -s -X GET \
  "https://app.harness.io/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}/node/${STAGE_NODE_EXECUTION_ID}/logs?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq .
