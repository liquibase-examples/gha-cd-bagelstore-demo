#!/bin/bash
# Script to test pipeline import and diagnose issues

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

echo "=== Testing Pipeline Import ==="

# Test importing the pipeline
echo "1. Attempting to import pipeline from Git..."
curl -s -X POST \
  'https://app.harness.io/pipeline/api/pipelines/import' \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "pipelineIdentifier": "Deploy_Bagel_Store",
    "pipelineName": "Deploy Bagel Store",
    "accountIdentifier": "_dYBmxlLQu61cFhvdkV4Jw",
    "orgIdentifier": "default",
    "projectIdentifier": "bagel_store_demo",
    "connectorRef": "account.githubpatharnessbaglestore",
    "repoName": "gha-cd-bagelstore-demo",
    "filePath": ".harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml",
    "branch": "main",
    "isForceImport": true
  }' | jq .

echo
echo "2. Checking if pipeline already exists..."
curl -s -X GET \
  'https://app.harness.io/pipeline/api/pipelines/Deploy_Bagel_Store?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo' \
  -H "x-api-key: ${API_KEY}" | jq -r '{exists: (.status == "SUCCESS"), gitDetails: .data.gitDetails}'

echo
echo "3. Checking template availability..."
curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0' \
  -H "x-api-key: ${API_KEY}" | jq -r '{templateExists: (.status == "SUCCESS"), valid: .data.entityValidityDetails.valid, storeType: .data.storeType}'
