#!/bin/bash
# Get Harness Trigger Configuration
# Usage: ./scripts/get-trigger.sh [trigger_id]

# Load API key
if [ -f "harness/.env" ]; then
  source harness/.env
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
else
  echo "Error: harness/.env not found"
  exit 1
fi

if [ -z "$HARNESS_API_KEY" ]; then
  echo "Error: HARNESS_API_KEY not set in harness/.env"
  exit 1
fi

# Constants
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"
PIPELINE_ID="Deploy_Bagel_Store"
TRIGGER_ID="${1:-GitHub_Actions_CI}"

echo "========================================="
echo "Harness Trigger Configuration"
echo "========================================="
echo "Trigger: $TRIGGER_ID"
echo "Pipeline: $PIPELINE_ID"
echo ""

# Get trigger configuration
TRIGGER_DATA=$(curl -s \
  "https://app.harness.io/pipeline/api/triggers/${TRIGGER_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}")

# Check for errors
STATUS=$(echo "$TRIGGER_DATA" | jq -r '.status // "UNKNOWN"')
if [ "$STATUS" != "SUCCESS" ]; then
  echo "❌ API Error:"
  echo "$TRIGGER_DATA" | jq '.'
  exit 1
fi

echo "✅ Trigger configuration retrieved"
echo ""

# Extract YAML
TRIGGER_YAML=$(echo "$TRIGGER_DATA" | jq -r '.data.yaml // ""')

if [ -z "$TRIGGER_YAML" ]; then
  echo "❌ No YAML found in trigger configuration"
  exit 1
fi

echo "========================================="
echo "Trigger YAML"
echo "========================================="
echo "$TRIGGER_YAML"
echo ""

echo "========================================="
echo "Configuration Analysis"
echo "========================================="

# Parse inputSetRefs from YAML (array format: "- webhook_default" or "  - webhook_default")
INPUT_SET_REFS=$(echo "$TRIGGER_YAML" | grep -A5 "inputSetRefs:" | grep "^ *- " | sed 's/^ *- //' | tr '\n' ',' | sed 's/,$//')

# Parse pipelineBranchName from YAML
PIPELINE_BRANCH=$(echo "$TRIGGER_YAML" | grep "pipelineBranchName:" | sed 's/.*pipelineBranchName: *//' | tr -d '\n')

# Parse enabled status
ENABLED=$(echo "$TRIGGER_YAML" | grep "enabled:" | sed 's/.*enabled: *//' | tr -d '\n')

# Parse trigger type
TRIGGER_TYPE=$(echo "$TRIGGER_YAML" | grep "type: Webhook" -A 3 | grep "type: " | tail -1 | sed 's/.*type: *//' | tr -d '\n')

echo "Enabled: ${ENABLED:-false}"
echo "Trigger Type: ${TRIGGER_TYPE:-Unknown}"
echo ""

if [ -z "$INPUT_SET_REFS" ]; then
  echo "❌ Input Set: NOT CONFIGURED"
  echo "   Pipeline variables will not be resolved from webhook payload"
  echo "   This causes deployment to fail with null variables"
else
  echo "✅ Input Set: $INPUT_SET_REFS"
fi

if [ -z "$PIPELINE_BRANCH" ]; then
  echo "❌ Pipeline Reference Branch: NOT CONFIGURED"
  echo "   Remote pipelines require this to fetch from Git"
else
  echo "✅ Pipeline Reference Branch: $PIPELINE_BRANCH"
fi

echo ""
echo "========================================="
echo "Git Details"
echo "========================================="
GIT_DETAILS=$(echo "$TRIGGER_DATA" | jq -r '.data.gitDetails')
echo "$GIT_DETAILS" | jq '{branch, filePath, repoName, storeType: .storeType // "INLINE"}'
echo ""

if [ -z "$INPUT_SET_REFS" ]; then
  echo "========================================="
  echo "⚠️  ACTION REQUIRED"
  echo "========================================="
  echo "Input Set is NOT configured on this trigger."
  echo ""
  echo "Without Input Set, pipeline variables are null and deployment fails."
  echo ""
  echo "To fix in Harness UI:"
  echo "1. Go to Pipeline: Deploy_Bagel_Store → Triggers"
  echo "2. Edit trigger: $TRIGGER_ID"
  echo "3. Go to 'Pipeline Input' tab"
  echo "4. Select Input Set: webhook_default"
  echo "5. Click 'Apply Changes' button"
  echo "6. Verify changes saved (no error toast)"
  echo ""
fi
