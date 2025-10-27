#!/usr/bin/env bash
#
# rollback-rating-demo.sh - Rollback product rating feature from all environments
#
# Usage: ./scripts/demo/rollback-rating-demo.sh
#
# What it does:
# 1. Resets git working tree (discards uncommitted changes)
# 2. Rollbacks rating changeset from dev, test, staging, prod databases
# 3. Switches back to main branch and deletes PR branches
# 4. Handles missing changesets gracefully (not yet deployed)
#
# This resets the demo to baseline state, ready for next demonstration.
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get repository root (2 levels up from scripts/demo/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TERRAFORM_DIR="${REPO_ROOT}/terraform"
ROLLBACK_TAG="v1.0.0"
LIQUIBASE_IMAGE="liquibase/liquibase-secure:5.0.1"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rollback Product Rating Feature${NC}"
echo -e "${BLUE}  Reset Demo Environment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

#
# Part 1: Reset Git Working Tree
#
echo -e "${CYAN}Part 1: Reset Git Working Tree${NC}"
echo ""

echo -e "${YELLOW}→${NC} Checking git status..."
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Working tree is already clean"
else
    echo -e "${YELLOW}⚠${NC}  Uncommitted changes detected"
    echo ""
    echo "The following changes will be discarded:"
    git status --short
    echo ""

    read -p "Continue with git reset? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi

    echo -e "${YELLOW}→${NC} Discarding changes..."
    git checkout -- .
    git clean -fd
    echo -e "${GREEN}✓${NC} Working tree reset"
fi

echo ""

#
# Part 2: Rollback AWS RDS Databases
#
echo -e "${CYAN}Part 2: Rollback AWS RDS Databases${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}→${NC} Checking prerequisites..."

# Check terraform directory
if [[ ! -d "${TERRAFORM_DIR}" ]]; then
    echo -e "${RED}❌ Error: Terraform directory not found${NC}"
    echo "  Expected: ${TERRAFORM_DIR}"
    exit 1
fi

# Check terraform state
if [[ ! -f "${TERRAFORM_DIR}/terraform.tfstate" ]]; then
    echo -e "${RED}❌ Error: Terraform state not found${NC}"
    echo "  Run terraform apply first: cd terraform && terraform apply"
    exit 1
fi

# Check AWS Profile
if [[ -z "${AWS_PROFILE:-}" ]]; then
    echo -e "${RED}❌ Error: AWS_PROFILE not set${NC}"
    echo "  Export AWS profile: export AWS_PROFILE=liquibase-csteam-operator"
    exit 1
fi

# Verify AWS credentials
echo -e "${YELLOW}→${NC} Verifying AWS credentials (AWS_PROFILE=${AWS_PROFILE})..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}❌ Error: AWS credentials invalid or not configured${NC}"
    echo "  Configure AWS: aws configure --profile ${AWS_PROFILE}"
    exit 1
fi
echo -e "${GREEN}✓${NC} AWS credentials valid"
echo ""

# Get terraform outputs
echo -e "${YELLOW}→${NC} Getting terraform outputs..."
cd "${TERRAFORM_DIR}"

TERRAFORM_OUTPUT=$(terraform output -json 2>/dev/null)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Error: Failed to get terraform outputs${NC}"
    exit 1
fi

# Extract values
RDS_ADDRESS=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.rds_address.value')
RDS_PORT=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.rds_port.value')
DEMO_ID=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.deployment_summary.value.demo_id')
DEPLOYMENT_MODE=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.deployment_mode.value')

# Validate deployment mode
if [[ "${DEPLOYMENT_MODE}" != "aws" ]]; then
    echo -e "${RED}❌ Error: Deployment mode is '${DEPLOYMENT_MODE}' (expected 'aws')${NC}"
    echo "  This script only supports AWS deployment mode"
    echo "  Set deployment_mode = \"aws\" in terraform.tfvars"
    exit 1
fi

# Validate outputs
if [[ "${RDS_ADDRESS}" == "null" ]] || [[ "${RDS_ADDRESS}" == "local-mode-not-applicable" ]]; then
    echo -e "${RED}❌ Error: RDS not provisioned${NC}"
    echo "  Terraform is in local mode or RDS resources not created"
    exit 1
fi

echo -e "${GREEN}✓${NC} Terraform outputs retrieved"
echo "  RDS Endpoint: ${RDS_ADDRESS}:${RDS_PORT}"
echo "  Demo ID: ${DEMO_ID}"
echo ""

# Fetch AWS Secrets Manager credentials
echo -e "${YELLOW}→${NC} Fetching database credentials from AWS Secrets Manager..."

USERNAME_SECRET_ID="${DEMO_ID}/rds/username"
PASSWORD_SECRET_ID="${DEMO_ID}/rds/password"

DB_USERNAME=$(aws secretsmanager get-secret-value \
    --secret-id "${USERNAME_SECRET_ID}" \
    --query SecretString \
    --output text 2>/dev/null)

if [[ $? -ne 0 ]] || [[ -z "${DB_USERNAME}" ]]; then
    echo -e "${RED}❌ Error: Failed to fetch username from Secrets Manager${NC}"
    echo "  Secret ID: ${USERNAME_SECRET_ID}"
    exit 1
fi

DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "${PASSWORD_SECRET_ID}" \
    --query SecretString \
    --output text 2>/dev/null)

if [[ $? -ne 0 ]] || [[ -z "${DB_PASSWORD}" ]]; then
    echo -e "${RED}❌ Error: Failed to fetch password from Secrets Manager${NC}"
    echo "  Secret ID: ${PASSWORD_SECRET_ID}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Credentials retrieved"
echo ""

# Rollback each database
DATABASES=("dev" "test" "staging" "prod")
ROLLED_BACK=()
SKIPPED=()
FAILED=()

echo -e "${YELLOW}→${NC} Rolling back databases..."
echo ""

for DB_NAME in "${DATABASES[@]}"; do
    echo -e "${CYAN}  Database: ${DB_NAME}${NC}"

    JDBC_URL="jdbc:postgresql://${RDS_ADDRESS}:${RDS_PORT}/${DB_NAME}"

    # Check if changeset exists
    echo -e "    ${YELLOW}→${NC} Checking for changeset 008..."

    CHANGESET_EXISTS=$(docker run --rm \
        --network host \
        liquibase/liquibase-secure:5.0.1 \
        --url="${JDBC_URL}" \
        --username="${DB_USERNAME}" \
        --password="${DB_PASSWORD}" \
        --changelog-file=/dev/null \
        status --verbose 2>/dev/null | grep -c "008-add-product-ratings" || true)

    # Alternative check using SQL query
    if [[ "${CHANGESET_EXISTS}" -eq 0 ]]; then
        # Try direct database query
        CHANGESET_COUNT=$(docker run --rm \
            --network host \
            postgres:16 \
            psql "${JDBC_URL}" \
            --username="${DB_USERNAME}" \
            --no-password \
            -tAc "SELECT COUNT(*) FROM databasechangelog WHERE id = 'demo:008-add-product-ratings';" 2>/dev/null || echo "0")

        if [[ "${CHANGESET_COUNT}" == "0" ]]; then
            echo -e "    ${YELLOW}⊘${NC}  Changeset not found - skipping"
            SKIPPED+=("${DB_NAME}")
            echo ""
            continue
        fi
    fi

    echo -e "    ${GREEN}✓${NC} Changeset found"

    # Perform rollback
    echo -e "    ${YELLOW}→${NC} Rolling back to ${ROLLBACK_TAG}..."

    if docker run --rm \
        --network host \
        -v "${REPO_ROOT}/db/changelog:/liquibase/changelog" \
        "${LIQUIBASE_IMAGE}" \
        --url="${JDBC_URL}" \
        --username="${DB_USERNAME}" \
        --password="${DB_PASSWORD}" \
        --changelog-file=changelog-master.yaml \
        rollback "${ROLLBACK_TAG}" 2>&1 | grep -q "successfully"; then

        echo -e "    ${GREEN}✓${NC} Rollback successful"
        ROLLED_BACK+=("${DB_NAME}")
    else
        echo -e "    ${RED}✗${NC} Rollback failed"
        FAILED+=("${DB_NAME}")
    fi

    echo ""
done

cd "${REPO_ROOT}"

echo ""

#
# Part 3: Clean Up Branches
#
echo -e "${CYAN}Part 3: Clean Up Branches${NC}"
echo ""

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if we're on a demo branch
if [[ "${CURRENT_BRANCH}" == demo/rating-feature-* ]]; then
    echo -e "${YELLOW}→${NC} Currently on PR branch: ${CURRENT_BRANCH}"
    echo -e "${YELLOW}→${NC} Switching to main branch..."

    git checkout main
    echo -e "${GREEN}✓${NC} Switched to main"

    # Delete the PR branch
    echo -e "${YELLOW}→${NC} Deleting local PR branch: ${CURRENT_BRANCH}..."
    git branch -D "${CURRENT_BRANCH}"
    echo -e "${GREEN}✓${NC} Local branch deleted"

    # Try to delete remote branch if it exists
    if git ls-remote --exit-code --heads origin "${CURRENT_BRANCH}" >/dev/null 2>&1; then
        echo -e "${YELLOW}→${NC} Deleting remote PR branch: ${CURRENT_BRANCH}..."
        git push origin --delete "${CURRENT_BRANCH}" 2>/dev/null || echo -e "${YELLOW}⚠${NC}  Remote branch may already be deleted"
        echo -e "${GREEN}✓${NC} Remote branch deleted"
    else
        echo -e "${GREEN}✓${NC} Remote branch does not exist (already deleted or never pushed)"
    fi
elif [[ "${CURRENT_BRANCH}" == "main" ]]; then
    echo -e "${GREEN}✓${NC} Already on main branch"

    # Check for any leftover demo branches
    DEMO_BRANCHES=$(git branch --list 'demo/rating-feature-*' | sed 's/^[* ]*//')

    if [[ -n "${DEMO_BRANCHES}" ]]; then
        echo -e "${YELLOW}→${NC} Found leftover demo branches:"
        echo "${DEMO_BRANCHES}" | sed 's/^/    /'
        echo ""

        read -p "Delete these branches? [y/N] " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            while IFS= read -r branch; do
                echo -e "${YELLOW}→${NC} Deleting: ${branch}..."
                git branch -D "${branch}"

                # Try to delete remote if it exists
                if git ls-remote --exit-code --heads origin "${branch}" >/dev/null 2>&1; then
                    git push origin --delete "${branch}" 2>/dev/null || true
                fi
            done <<< "${DEMO_BRANCHES}"
            echo -e "${GREEN}✓${NC} Leftover branches deleted"
        else
            echo -e "${YELLOW}⊘${NC}  Branches not deleted (manual cleanup needed)"
        fi
    else
        echo -e "${GREEN}✓${NC} No leftover demo branches found"
    fi
else
    echo -e "${YELLOW}⚠${NC}  On unexpected branch: ${CURRENT_BRANCH}"
    echo "  Switching to main..."
    git checkout main
    echo -e "${GREEN}✓${NC} Switched to main"
fi

echo ""

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rollback Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}Git status:${NC}"
echo "  • Working tree: Reset to HEAD"
echo "  • Branch: main"
echo "  • Demo branches: Cleaned up"
echo ""

echo -e "${CYAN}Database rollbacks:${NC}"
if [[ ${#ROLLED_BACK[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}✓ Rolled back (${#ROLLED_BACK[@]}):${NC} ${ROLLED_BACK[*]}"
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}⊘ Skipped (${#SKIPPED[@]}):${NC} ${SKIPPED[*]} (changeset not applied)"
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "  ${RED}✗ Failed (${#FAILED[@]}):${NC} ${FAILED[*]}"
fi

echo ""

if [[ ${#FAILED[@]} -eq 0 ]]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ Demo Reset Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Ready for next demonstration:"
    echo "  ./scripts/demo/apply-rating-demo.sh"
    echo ""
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠ Rollback Completed with Errors${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "Some databases could not be rolled back."
    echo "Check database connectivity and Liquibase logs."
    echo ""
fi
