#!/bin/bash
# Script to compare template YAML in Harness with Git source

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
REPO_DIR="/Users/recampbell/workspace/harness-gha-bagelstore"

echo "=== Comparing Template YAML: Harness vs Git ==="
echo

# Get template from Harness API
echo "1. Fetching template from Harness API..."
curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0&loadFromCache=false' \
  -H "x-api-key: ${API_KEY}" | jq -r '.data.yaml' > /tmp/harness-template.yaml

echo "2. Reading template from Git..."
cp "${REPO_DIR}/.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml" /tmp/git-template.yaml

echo "3. Comparing files..."
if diff -u /tmp/git-template.yaml /tmp/harness-template.yaml; then
  echo
  echo "✅ Templates are IDENTICAL"
else
  echo
  echo "❌ Templates are DIFFERENT"
  echo
  echo "Git file: /tmp/git-template.yaml"
  echo "Harness file: /tmp/harness-template.yaml"
fi

echo
echo "4. Git details from Harness:"
curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0' \
  -H "x-api-key: ${API_KEY}" | jq -r '.data.gitDetails'

echo
echo "5. Validity details:"
curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0' \
  -H "x-api-key: ${API_KEY}" | jq -r '.data.entityValidityDetails'
