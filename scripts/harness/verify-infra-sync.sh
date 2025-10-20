#!/bin/bash
# Verify Infrastructure Definitions are Synced from Git
#
# Checks that all 4 infrastructure definitions are synced to the latest commit
# and have the correct variable overrides.
#
# Usage:
#   ./scripts/harness/verify-infra-sync.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Get latest commit for infra definitions
LATEST_COMMIT=$(cd "$PROJECT_ROOT" && git log -1 --format=%h -- .harness/orgs/default/projects/bagel_store_demo/envs/*/infras/*.yaml)

echo "=== Infrastructure Definition Sync Verification ==="
echo "Latest Git commit for infra definitions: $LATEST_COMMIT"
echo ""

ENVIRONMENTS="psr_dev psr_test psr_staging psr_prod"
ALL_SYNCED=true

for env in $ENVIRONMENTS; do
  echo "Checking $env..."
  
  # Get infrastructure definition from Harness
  RESPONSE=$("$SCRIPT_DIR/harness-api.sh" GET \
    "/ng/api/infrastructures/${env}_infra?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=$env" \
    2>/dev/null)
  
  # Extract commit ID
  HARNESS_COMMIT=$(echo "$RESPONSE" | jq -r '.data.infrastructure.entityGitDetails.commitId' | head -c 7)
  
  # Check if variables exist
  HAS_VARIABLES=$(echo "$RESPONSE" | jq -r '.data.infrastructure.yaml' | grep -c "value: <+env.variables" || echo "0")
  
  if [ "$HARNESS_COMMIT" = "$LATEST_COMMIT" ] && [ "$HAS_VARIABLES" -ge "4" ]; then
    echo "  ✅ Synced to $HARNESS_COMMIT with $HAS_VARIABLES variable overrides"
  else
    echo "  ❌ NOT SYNCED - Harness: $HARNESS_COMMIT, Git: $LATEST_COMMIT, Variables: $HAS_VARIABLES"
    ALL_SYNCED=false
  fi
  echo ""
done

if [ "$ALL_SYNCED" = "true" ]; then
  echo "✅ All infrastructure definitions are synced!"
  exit 0
else
  echo "❌ Some infrastructure definitions need manual refresh in Harness UI"
  echo ""
  echo "To refresh manually:"
  echo "1. Go to: Environments → Select environment → Infrastructure Definitions"
  echo "2. Click on infrastructure name"
  echo "3. Click Refresh icon (circular arrow)"
  exit 1
fi
