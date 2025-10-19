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

ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"

echo "========================================="
echo "Checking Harness Resources"
echo "========================================="
echo ""

# Check Connectors
echo "1. Checking Connectors..."
echo "-------------------------------------------"
curl -s -X GET \
  "https://app.harness.io/ng/api/connectors?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.content[] | "  - \(.connector.name) (\(.connector.identifier)) - \(.connector.type)"'
echo ""

# Check Secrets
echo "2. Checking Secrets..."
echo "-------------------------------------------"
curl -s -X GET \
  "https://app.harness.io/ng/api/v2/secrets?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.content[] | "  - \(.secret.name) (\(.secret.identifier)) - \(.secret.type)"'
echo ""

# Check Environments
echo "3. Checking Environments..."
echo "-------------------------------------------"
curl -s -X GET \
  "https://app.harness.io/ng/api/environmentsV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.content[] | "  - \(.environment.name) (\(.environment.identifier)) - \(.environment.type)"'
echo ""

# Check Service
echo "4. Checking Services..."
echo "-------------------------------------------"
curl -s -X GET \
  "https://app.harness.io/ng/api/servicesV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.content[] | "  - \(.service.name) (\(.service.identifier))"'
echo ""

# Check Templates
echo "5. Checking Templates..."
echo "-------------------------------------------"
curl -s -X POST \
  "https://app.harness.io/template/api/templates/list?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"Template"}' | jq -r '.data.content[] | "  - \(.name) (\(.identifier)) - v\(.versionLabel)"'
echo ""

echo "========================================="
echo "Resource Check Complete"
echo "========================================="
