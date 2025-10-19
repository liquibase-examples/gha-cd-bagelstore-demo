#!/bin/bash
# Validate template status and Git sync

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

echo "=== Validating Template ==="

RESPONSE=$(curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0' \
  -H "x-api-key: ${API_KEY}")

# Check if API call succeeded
STATUS=$(echo "$RESPONSE" | jq -r '.status')
if [ "$STATUS" != "SUCCESS" ]; then
  echo "❌ API call failed"
  echo "$RESPONSE" | jq .
  exit 1
fi

# Extract validation details
VALID=$(echo "$RESPONSE" | jq -r '.data.entityValidityDetails.valid')
INVALID_YAML=$(echo "$RESPONSE" | jq -r '.data.entityValidityDetails.invalidYaml')
STORE_TYPE=$(echo "$RESPONSE" | jq -r '.data.storeType')
CONNECTOR=$(echo "$RESPONSE" | jq -r '.data.connectorRef')
BRANCH=$(echo "$RESPONSE" | jq -r '.data.gitDetails.branch')
REPO=$(echo "$RESPONSE" | jq -r '.data.gitDetails.repoName')

echo "Template Status:"
echo "  Valid: $VALID"
echo "  Store Type: $STORE_TYPE"
echo "  Connector: $CONNECTOR"
echo "  Repository: $REPO"
echo "  Branch: $BRANCH"

if [ "$VALID" = "true" ]; then
  echo
  echo "✅ Template is VALID and ready to use"
else
  echo
  echo "❌ Template is INVALID"
  echo "Error: $INVALID_YAML"
  exit 1
fi
