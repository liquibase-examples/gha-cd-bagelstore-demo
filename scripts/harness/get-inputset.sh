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

INPUTSET_ID="${1:-webhook_default}"

echo "Fetching Input Set: $INPUTSET_ID"
echo ""

curl -s -X GET \
  "https://app.harness.io/pipeline/api/inputSets/${INPUTSET_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq .
