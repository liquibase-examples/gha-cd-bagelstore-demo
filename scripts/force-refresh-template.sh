#!/bin/bash
# Force refresh template from Git (bypass cache)

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

echo "=== Force Refreshing Template from Git ==="

# GET with loadFromCache=false forces fresh load from Git
echo "Fetching fresh template from Git (bypass cache)..."
RESPONSE=$(curl -s -X GET \
  'https://app.harness.io/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0&loadFromCache=false' \
  -H "x-api-key: ${API_KEY}")

STATUS=$(echo "$RESPONSE" | jq -r '.status')
if [ "$STATUS" = "SUCCESS" ]; then
  echo "✅ Template refreshed from Git successfully"

  # Show last updated timestamp
  LAST_UPDATED=$(echo "$RESPONSE" | jq -r '.data.lastUpdatedAt')
  echo "Last Updated: $(date -r $((LAST_UPDATED / 1000)))"

  # Show Git commit
  COMMIT=$(echo "$RESPONSE" | jq -r '.data.gitDetails.commitId')
  echo "Git Commit: $COMMIT"
else
  echo "❌ Failed to refresh template"
  echo "$RESPONSE" | jq .
fi
