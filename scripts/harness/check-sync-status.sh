#!/bin/bash
# Check Git sync status for Harness Git Experience resources
#
# This script verifies if Git changes have been synced to Harness by comparing
# Git commit SHAs with Harness gitDetails.commitId for all Git Experience resources.
#
# Usage: ./scripts/harness/check-sync-status.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Load API key from harness/.env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/harness/.env" ]; then
  source "$PROJECT_ROOT/harness/.env"
elif [ -f "$SCRIPT_DIR/../harness/.env" ]; then
  source "$SCRIPT_DIR/../harness/.env"
else
  echo -e "${RED}Error: harness/.env not found${NC}"
  exit 1
fi

if [ -z "$HARNESS_API_KEY" ]; then
  echo -e "${RED}Error: HARNESS_API_KEY not set in harness/.env${NC}"
  exit 1
fi

# Constants
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"

# Counters
SYNCED_COUNT=0
OUT_OF_SYNC_COUNT=0
UNKNOWN_COUNT=0
OUT_OF_SYNC_RESOURCES=()

echo "========================================="
echo "Git Sync Status Check"
echo "========================================="
echo ""
echo "Checking sync status for Git Experience resources..."
echo ""

# Function to get Git commit SHA for a file
get_git_sha() {
  local file_path="$1"
  local full_path="$PROJECT_ROOT/$file_path"

  if [ ! -f "$full_path" ]; then
    echo "FILE_NOT_FOUND"
    return
  fi

  cd "$PROJECT_ROOT"
  git log -1 --format="%H" -- "$file_path" 2>/dev/null | cut -c1-7 || echo "GIT_ERROR"
}

# Function to check a template
check_template() {
  local template_name="$1"
  local version="$2"
  local file_path="$3"

  echo -e "${BOLD}Template: $template_name $version${NC}"

  # Get Git SHA
  local git_sha=$(get_git_sha "$file_path")

  if [ "$git_sha" = "FILE_NOT_FOUND" ]; then
    echo -e "  ${YELLOW}⚠️  Git file not found: $file_path${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  if [ "$git_sha" = "GIT_ERROR" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to get Git commit SHA${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  # Get template from Harness
  local response=$(curl -s -X GET \
    "https://app.harness.io/template/api/templates/${template_name}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&versionLabel=${version}&loadFromCache=false" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  local status=$(echo "$response" | jq -r '.status // "UNKNOWN"')

  if [ "$status" != "SUCCESS" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to fetch from Harness API${NC}"
    echo "     $(echo "$response" | jq -r '.message // "Unknown error"')"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  local harness_sha=$(echo "$response" | jq -r '.data.gitDetails.commitId // "unknown"' | cut -c1-7)

  echo "  Git SHA:     $git_sha"
  echo "  Harness SHA: $harness_sha"

  if [ "$harness_sha" = "unknown" ] || [ -z "$harness_sha" ]; then
    echo -e "  Status: ${YELLOW}⚠️  Unknown${NC} (no Git sync information from Harness)"
    ((UNKNOWN_COUNT++))
  elif [ "$git_sha" = "$harness_sha" ]; then
    echo -e "  Status: ${GREEN}✅ Synced${NC}"
    ((SYNCED_COUNT++))
  else
    echo -e "  Status: ${RED}❌ Out of Sync${NC}"
    echo -e "  ${YELLOW}Action: Refresh in Harness UI (Project Setup → Templates → $template_name → Refresh)${NC}"
    ((OUT_OF_SYNC_COUNT++))
    OUT_OF_SYNC_RESOURCES+=("Template: $template_name (Project Setup → Templates)")
  fi

  echo ""
}

# Function to check a pipeline
check_pipeline() {
  local pipeline_id="$1"
  local pipeline_name="$2"
  local file_path="$3"

  echo -e "${BOLD}Pipeline: $pipeline_name${NC}"

  # Get Git SHA
  local git_sha=$(get_git_sha "$file_path")

  if [ "$git_sha" = "FILE_NOT_FOUND" ]; then
    echo -e "  ${YELLOW}⚠️  Git file not found: $file_path${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  if [ "$git_sha" = "GIT_ERROR" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to get Git commit SHA${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  # Get pipeline from Harness
  local response=$(curl -s -X GET \
    "https://app.harness.io/pipeline/api/pipelines/${pipeline_id}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&loadFromCache=false" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  local status=$(echo "$response" | jq -r '.status // "UNKNOWN"')

  if [ "$status" != "SUCCESS" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to fetch from Harness API${NC}"
    echo "     $(echo "$response" | jq -r '.message // "Unknown error"')"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  local harness_sha=$(echo "$response" | jq -r '.data.gitDetails.commitId // "unknown"' | cut -c1-7)

  echo "  Git SHA:     $git_sha"
  echo "  Harness SHA: $harness_sha"

  if [ "$harness_sha" = "unknown" ] || [ -z "$harness_sha" ]; then
    echo -e "  Status: ${YELLOW}⚠️  Unknown${NC} (no Git sync information from Harness)"
    ((UNKNOWN_COUNT++))
  elif [ "$git_sha" = "$harness_sha" ]; then
    echo -e "  Status: ${GREEN}✅ Synced${NC}"
    ((SYNCED_COUNT++))
  else
    echo -e "  Status: ${RED}❌ Out of Sync${NC}"
    echo -e "  ${YELLOW}Action: Refresh in Harness UI (Pipelines → $pipeline_name → Refresh icon)${NC}"
    ((OUT_OF_SYNC_COUNT++))
    OUT_OF_SYNC_RESOURCES+=("Pipeline: $pipeline_name (Pipelines)")
  fi

  echo ""
}

# Function to check an infrastructure definition
check_infrastructure() {
  local infra_id="$1"
  local env_id="$2"
  local env_name="$3"
  local file_path="$4"

  echo -e "${BOLD}Infrastructure: $infra_id${NC}"

  # Get Git SHA
  local git_sha=$(get_git_sha "$file_path")

  if [ "$git_sha" = "FILE_NOT_FOUND" ]; then
    echo -e "  ${YELLOW}⚠️  Git file not found: $file_path${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  if [ "$git_sha" = "GIT_ERROR" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to get Git commit SHA${NC}"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  # Get infrastructure from Harness
  local response=$(curl -s -X GET \
    "https://app.harness.io/gateway/ng/api/infrastructures/${infra_id}?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&environmentIdentifier=${env_id}" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  local status=$(echo "$response" | jq -r '.status // "UNKNOWN"')

  if [ "$status" != "SUCCESS" ]; then
    echo -e "  ${YELLOW}⚠️  Unable to fetch from Harness API${NC}"
    echo "     $(echo "$response" | jq -r '.message // "Unknown error"')"
    ((UNKNOWN_COUNT++))
    echo ""
    return
  fi

  local harness_sha=$(echo "$response" | jq -r '.data.infrastructure.gitDetails.commitId // "unknown"' | cut -c1-7)

  echo "  Git SHA:     $git_sha"
  echo "  Harness SHA: $harness_sha"

  if [ "$harness_sha" = "unknown" ] || [ -z "$harness_sha" ]; then
    echo -e "  Status: ${YELLOW}⚠️  Unknown${NC} (no Git sync information from Harness)"
    ((UNKNOWN_COUNT++))
  elif [ "$git_sha" = "$harness_sha" ]; then
    echo -e "  Status: ${GREEN}✅ Synced${NC}"
    ((SYNCED_COUNT++))
  else
    echo -e "  Status: ${RED}❌ Out of Sync${NC}"
    echo -e "  ${YELLOW}Action: Refresh in Harness UI (Environments → $env_name → Infrastructure Definitions → $infra_id → Refresh)${NC}"
    ((OUT_OF_SYNC_COUNT++))
    OUT_OF_SYNC_RESOURCES+=("Infrastructure: $infra_id (Environment: $env_name)")
  fi

  echo ""
}

# Check all resources
check_template "Coordinated_DB_App_Deployment" "v1.0" ".harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml"

check_pipeline "Deploy_Bagel_Store" "Deploy Bagel Store" ".harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml"

check_infrastructure "psr_dev_infra" "psr_dev" "psr-dev" ".harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_dev/infras/psr_dev_infra.yaml"

check_infrastructure "psr_test_infra" "psr_test" "psr-test" ".harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_test/infras/psr_test_infra.yaml"

check_infrastructure "psr_staging_infra" "psr_staging" "psr-staging" ".harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_staging/infras/psr_staging_infra.yaml"

check_infrastructure "psr_prod_infra" "psr_prod" "psr-prod" ".harness/orgs/default/projects/bagel_store_demo/envs/Production/psr_prod/infras/psr_prod_infra.yaml"

# Display summary
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "${GREEN}✅ Synced:      $SYNCED_COUNT resources${NC}"
echo -e "${RED}❌ Out of Sync: $OUT_OF_SYNC_COUNT resources${NC}"
echo -e "${YELLOW}⚠️  Unknown:     $UNKNOWN_COUNT resources${NC}"
echo ""

# Show out-of-sync resources if any
if [ $OUT_OF_SYNC_COUNT -gt 0 ]; then
  echo "Resources needing refresh:"
  for resource in "${OUT_OF_SYNC_RESOURCES[@]}"; do
    echo "  - $resource"
  done
  echo ""
  echo "To refresh out-of-sync resources:"
  echo "  1. Go to Harness UI: https://app.harness.io/ng/account/${ACCOUNT_ID}/cd/orgs/${ORG_ID}/projects/${PROJECT_ID}"
  echo "  2. Navigate to the resource location (shown above)"
  echo "  3. Click 'Refresh' icon (circular arrow)"
  echo ""
  echo "Or use API refresh scripts:"
  echo "  ./scripts/templates/refresh-template.sh          # For templates"
  echo "  ./scripts/templates/force-refresh-template.sh    # Force refresh (bypass cache)"
  echo ""
  exit 1
elif [ $UNKNOWN_COUNT -gt 0 ]; then
  echo "Some resources could not be verified. Check errors above."
  echo ""
  exit 1
else
  echo -e "${GREEN}All resources are synced! ✅${NC}"
  echo ""
  exit 0
fi
