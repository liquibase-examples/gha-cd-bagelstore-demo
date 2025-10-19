#!/bin/bash
# Script to refresh a template from Git (reload from cache)

# Load API key from harness/.env
if [ -f "harness/.env" ]; then
  source harness/.env
  API_KEY="$HARNESS_API_KEY"
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
  API_KEY="$HARNESS_API_KEY"
else
  echo "Error: harness/.env not found"
  exit 1
fi

echo "=== Refreshing Template from Git ==="

# Try POST to refresh-template endpoint (mentioned in Context7 docs)
echo "Attempting to refresh template..."
curl -s -X POST \
  'https://app.harness.io/template/api/refresh-template/refreshed-yaml' \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "accountIdentifier": "_dYBmxlLQu61cFhvdkV4Jw",
    "orgIdentifier": "default",
    "projectIdentifier": "bagel_store_demo",
    "templateIdentifier": "Coordinated_DB_App_Deployment",
    "versionLabel": "v1.0"
  }' | jq .
