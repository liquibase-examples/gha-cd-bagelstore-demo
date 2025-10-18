#!/bin/bash
# Script to test Git connector and check Git Experience status

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

echo "=== Testing Git Connector ==="

# Get connector details
echo "1. Git Connector Details:"
curl -s -X GET \
  'https://app.harness.io/ng/api/connectors/account.githubpatharnessbaglestore?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw' \
  -H "x-api-key: ${API_KEY}" | jq .

echo
echo "2. Testing connector connectivity:"
curl -s -X GET \
  'https://app.harness.io/ng/api/connectors/testConnection/account.githubpatharnessbaglestore?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw' \
  -H "x-api-key: ${API_KEY}" | jq .

echo
echo "3. Template Git Details (connector reference):"
curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0' \
  -H "x-api-key: ${API_KEY}" | jq -r '{connectorRef: .data.connectorRef, storeType: .data.storeType, repoName: .data.gitDetails.repoName, branch: .data.gitDetails.branch}'
