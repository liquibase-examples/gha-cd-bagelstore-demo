#!/bin/bash
# Get webhook URL for Harness trigger

# Load API key
if [ -f "harness/.env" ]; then
  source harness/.env
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
fi

ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"
PIPELINE_ID="Deploy_Bagel_Store"
TRIGGER_ID="GitHub_Actions_CI"

echo "Fetching webhook URL for trigger: $TRIGGER_ID"
echo ""

curl -s -X GET \
  "https://app.harness.io/pipeline/api/triggers/${TRIGGER_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.webhookUrl // "Webhook URL not found in response"'
