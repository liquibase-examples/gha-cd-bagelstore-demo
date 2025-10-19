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

echo "Fetching execution graph for: $EXECUTION_ID"
echo ""

curl -s -X POST \
  "https://app.harness.io/gateway/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"renderFullBottomGraph":true}' | jq .
