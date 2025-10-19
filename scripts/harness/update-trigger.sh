#!/bin/bash
# Update Harness Trigger Configuration via API
#
# This script updates the GitHub_Actions_CI trigger to ensure:
# 1. Input Set (webhook_default) is configured
# 2. Pipeline Reference Branch (<+trigger.branch>) is set
#
# Usage: ./scripts/harness/update-trigger.sh [--dry-run]

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
TRIGGER_ID="GitHub_Actions_CI"

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=true
  echo "🔍 DRY RUN MODE - No changes will be made"
  echo ""
fi

echo "========================================="
echo "Update Harness Trigger Configuration"
echo "========================================="
echo "Trigger: $TRIGGER_ID"
echo "Pipeline: $PIPELINE_ID"
echo ""

# Get current trigger configuration
echo "Fetching current trigger configuration..."
TRIGGER_RESPONSE=$(curl -s \
  "https://app.harness.io/pipeline/api/triggers/${TRIGGER_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}")

STATUS=$(echo "$TRIGGER_RESPONSE" | jq -r '.status // "UNKNOWN"')
if [ "$STATUS" = "ERROR" ]; then
  echo "❌ Error fetching trigger:"
  echo "$TRIGGER_RESPONSE" | jq '.message'
  exit 1
fi

CURRENT_YAML=$(echo "$TRIGGER_RESPONSE" | jq -r '.data.yaml // ""')

if [ -z "$CURRENT_YAML" ] || [ "$CURRENT_YAML" = "null" ]; then
  echo "❌ Error: Could not retrieve trigger YAML"
  echo "Response:"
  echo "$TRIGGER_RESPONSE" | jq '.'
  exit 1
fi

echo "✅ Current trigger configuration retrieved"
echo ""

# Parse current values
CURRENT_INPUT_SETS=$(echo "$CURRENT_YAML" | grep -A1 "inputSetRefs:" | grep "^  - " | sed 's/^  - //' | tr '\n' ',' | sed 's/,$//')
CURRENT_BRANCH=$(echo "$CURRENT_YAML" | grep "pipelineBranchName:" | sed 's/.*pipelineBranchName: *//' | tr -d '\n')

echo "Current Configuration:"
echo "  Input Sets: ${CURRENT_INPUT_SETS:-<not set>}"
echo "  Pipeline Branch: ${CURRENT_BRANCH:-<not set>}"
echo ""

# Determine what needs to be updated
NEEDS_UPDATE=false
MISSING_INPUT_SET=false
MISSING_BRANCH=false

if [ -z "$CURRENT_INPUT_SETS" ] || [ "$CURRENT_INPUT_SETS" != *"webhook_default"* ]; then
  echo "⚠️  Input Set 'webhook_default' is not configured"
  MISSING_INPUT_SET=true
  NEEDS_UPDATE=true
fi

if [ -z "$CURRENT_BRANCH" ]; then
  echo "⚠️  Pipeline Reference Branch is not configured"
  MISSING_BRANCH=true
  NEEDS_UPDATE=true
fi

if [ "$NEEDS_UPDATE" = "false" ]; then
  echo "✅ Trigger is already correctly configured!"
  echo "   No updates needed."
  exit 0
fi

echo ""
echo "========================================="
echo "Proposed Changes"
echo "========================================="

if [ "$MISSING_INPUT_SET" = "true" ]; then
  echo "➕ Add inputSetRefs: [webhook_default]"
fi

if [ "$MISSING_BRANCH" = "true" ]; then
  echo "➕ Set pipelineBranchName: <+trigger.branch>"
fi

echo ""

if [ "$DRY_RUN" = "true" ]; then
  echo "🔍 DRY RUN: Would update trigger with above changes"
  exit 0
fi

# Build updated YAML
# Strategy: Update the existing YAML to add missing fields
UPDATED_YAML="$CURRENT_YAML"

if [ "$MISSING_INPUT_SET" = "true" ]; then
  # Add inputSetRefs array after pipelineIdentifier
  if echo "$UPDATED_YAML" | grep -q "inputSetRefs:"; then
    # Replace existing inputSetRefs
    UPDATED_YAML=$(echo "$UPDATED_YAML" | sed '/inputSetRefs:/,/^  [a-z]/c\
  inputSetRefs:\
    - webhook_default')
  else
    # Add new inputSetRefs after pipelineIdentifier
    UPDATED_YAML=$(echo "$UPDATED_YAML" | sed "/pipelineIdentifier:/a\\
  inputSetRefs:\\
    - webhook_default")
  fi
fi

if [ "$MISSING_BRANCH" = "true" ]; then
  if echo "$UPDATED_YAML" | grep -q "pipelineBranchName:"; then
    # Update existing pipelineBranchName
    UPDATED_YAML=$(echo "$UPDATED_YAML" | sed 's/pipelineBranchName: .*/pipelineBranchName: <+trigger.branch>/')
  else
    # Add new pipelineBranchName after source block
    UPDATED_YAML=$(echo "$UPDATED_YAML" | sed "/spec:/a\\
  pipelineBranchName: <+trigger.branch>")
  fi
fi

echo "Updating trigger configuration..."
echo ""

# Create update request payload
UPDATE_PAYLOAD=$(jq -n \
  --arg yaml "$UPDATED_YAML" \
  '{
    identifier: "'"$TRIGGER_ID"'",
    yaml: $yaml
  }')

# Update trigger via PUT API
UPDATE_RESPONSE=$(curl -s -X PUT \
  "https://app.harness.io/pipeline/api/triggers/${TRIGGER_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD")

UPDATE_STATUS=$(echo "$UPDATE_RESPONSE" | jq -r '.status // "UNKNOWN"')

if [ "$UPDATE_STATUS" = "SUCCESS" ]; then
  echo "✅ Trigger updated successfully!"
  echo ""

  # Verify the update
  echo "Verifying update..."
  sleep 2

  VERIFY_RESPONSE=$(curl -s \
    "https://app.harness.io/pipeline/api/triggers/${TRIGGER_ID}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&targetIdentifier=${PIPELINE_ID}" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  VERIFY_YAML=$(echo "$VERIFY_RESPONSE" | jq -r '.data.yaml // ""')
  VERIFY_INPUT_SETS=$(echo "$VERIFY_YAML" | grep -A1 "inputSetRefs:" | grep "^  - " | sed 's/^  - //' | tr '\n' ',' | sed 's/,$//')
  VERIFY_BRANCH=$(echo "$VERIFY_YAML" | grep "pipelineBranchName:" | sed 's/.*pipelineBranchName: *//' | tr -d '\n')

  echo "Updated Configuration:"
  echo "  Input Sets: $VERIFY_INPUT_SETS"
  echo "  Pipeline Branch: $VERIFY_BRANCH"
  echo ""
  echo "========================================="
  echo "Next Steps"
  echo "========================================="
  echo "1. Trigger a new GitHub Actions workflow run:"
  echo "   gh workflow run main-ci.yml --ref main"
  echo ""
  echo "2. Verify the pipeline executes successfully:"
  echo "   ./scripts/harness/get-pipeline-executions.sh"
  echo ""
else
  echo "❌ Failed to update trigger"
  echo ""
  echo "Response:"
  echo "$UPDATE_RESPONSE" | jq '.'
  echo ""
  echo "Debug information:"
  echo "Payload sent:"
  echo "$UPDATE_PAYLOAD" | jq '.'
  exit 1
fi
