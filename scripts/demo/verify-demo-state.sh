#!/usr/bin/env bash
#
# verify-demo-state.sh - Verify demo environment is ready for rating feature demo
#
# Usage: ./scripts/demo/verify-demo-state.sh
#
# Checks:
# 1. Git branch (should be main)
# 2. Git working tree (should be clean)
# 3. Demo branches (should be none)
# 4. Database state (rating column should not exist)
#
# Exit codes:
#   0 = Ready for demo
#   1 = Not ready (issues found)
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

# Tracking issues
ISSUES=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Demo Environment Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

#
# Git Status Checks
#
echo -e "${CYAN}Git Status${NC}"
echo ""

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo -e "${YELLOW}→${NC} Checking current branch..."
if [[ "${CURRENT_BRANCH}" == "main" ]]; then
    echo -e "  ${GREEN}✓${NC} On main branch"
else
    echo -e "  ${RED}✗${NC} On branch: ${CURRENT_BRANCH} (expected: main)"
    ISSUES+=("Not on main branch")
fi
echo ""

# Check for uncommitted changes
echo -e "${YELLOW}→${NC} Checking working tree..."
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} Working tree is clean"
else
    echo -e "  ${RED}✗${NC} Uncommitted changes detected"
    ISSUES+=("Working tree not clean")

    # Show what's changed
    echo "  Modified files:"
    git status --short | sed 's/^/    /'
fi
echo ""

# Check for demo branches
echo -e "${YELLOW}→${NC} Checking for demo branches..."
DEMO_BRANCHES=$(git branch --list 'demo/rating-feature-*' | sed 's/^[* ]*//' || echo "")

if [[ -z "${DEMO_BRANCHES}" ]]; then
    echo -e "  ${GREEN}✓${NC} No demo branches found"
else
    echo -e "  ${YELLOW}⚠${NC}  Found demo branches:"
    echo "${DEMO_BRANCHES}" | sed 's/^/    /'
    ISSUES+=("Demo branches exist")
fi
echo ""

#
# Database State Checks
#
echo -e "${CYAN}Database State${NC}"
echo ""

# Check if terraform is set up
if [[ ! -f "${TERRAFORM_DIR}/terraform.tfstate" ]]; then
    echo -e "  ${YELLOW}⚠${NC}  Terraform not applied - skipping database checks"
    echo ""
else
    # Check AWS Profile
    if [[ -z "${AWS_PROFILE:-}" ]]; then
        echo -e "  ${YELLOW}⚠${NC}  AWS_PROFILE not set - skipping database checks"
        echo "  Set with: export AWS_PROFILE=liquibase-sandbox-owner"
        echo ""
    else
        # Get terraform outputs
        cd "${TERRAFORM_DIR}"
        TERRAFORM_OUTPUT=$(terraform output -json 2>/dev/null)

        if [[ $? -ne 0 ]]; then
            echo -e "  ${YELLOW}⚠${NC}  Failed to get terraform outputs - skipping database checks"
            echo ""
        else
            # Extract values
            RDS_ADDRESS=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.rds_address.value')
            RDS_PORT=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.rds_port.value')
            DEMO_ID=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.deployment_summary.value.demo_id')
            DEPLOYMENT_MODE=$(echo "${TERRAFORM_OUTPUT}" | jq -r '.deployment_mode.value')

            if [[ "${DEPLOYMENT_MODE}" != "aws" ]]; then
                echo -e "  ${YELLOW}⚠${NC}  Deployment mode is '${DEPLOYMENT_MODE}' - skipping database checks"
                echo ""
            elif [[ "${RDS_ADDRESS}" == "null" ]] || [[ "${RDS_ADDRESS}" == "local-mode-not-applicable" ]]; then
                echo -e "  ${YELLOW}⚠${NC}  RDS not provisioned - skipping database checks"
                echo ""
            else
                # Fetch credentials
                USERNAME_SECRET_ID="${DEMO_ID}/rds/username"
                PASSWORD_SECRET_ID="${DEMO_ID}/rds/password"

                DB_USERNAME=$(aws secretsmanager get-secret-value \
                    --secret-id "${USERNAME_SECRET_ID}" \
                    --query SecretString \
                    --output text 2>/dev/null || echo "")

                DB_PASSWORD=$(aws secretsmanager get-secret-value \
                    --secret-id "${PASSWORD_SECRET_ID}" \
                    --query SecretString \
                    --output text 2>/dev/null || echo "")

                if [[ -z "${DB_USERNAME}" ]] || [[ -z "${DB_PASSWORD}" ]]; then
                    echo -e "  ${YELLOW}⚠${NC}  Failed to fetch AWS Secrets Manager credentials"
                    echo ""
                else
                    # Check each database
                    DATABASES=("dev" "test" "staging" "prod")

                    for DB_NAME in "${DATABASES[@]}"; do
                        echo -e "${YELLOW}→${NC} Checking ${DB_NAME} database..."

                        JDBC_URL="jdbc:postgresql://${RDS_ADDRESS}:${RDS_PORT}/${DB_NAME}"

                        # Check if changeset 008 exists
                        CHANGESET_EXISTS=$(docker run --rm \
                            --network host \
                            postgres:16 \
                            psql "${JDBC_URL}" \
                            --username="${DB_USERNAME}" \
                            --no-password \
                            -tAc "SELECT COUNT(*) FROM databasechangelog WHERE id = 'demo:008-add-product-ratings';" 2>/dev/null || echo "error")

                        # Check if rating column exists
                        RATING_COLUMN_EXISTS=$(docker run --rm \
                            --network host \
                            postgres:16 \
                            psql "${JDBC_URL}" \
                            --username="${DB_USERNAME}" \
                            --no-password \
                            -tAc "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='products' AND column_name='rating';" 2>/dev/null || echo "error")

                        if [[ "${CHANGESET_EXISTS}" == "error" ]] || [[ "${RATING_COLUMN_EXISTS}" == "error" ]]; then
                            echo -e "  ${RED}✗${NC} ${DB_NAME}: Connection error"
                            ISSUES+=("${DB_NAME} database not accessible")
                        elif [[ "${CHANGESET_EXISTS}" == "0" ]] && [[ "${RATING_COLUMN_EXISTS}" == "0" ]]; then
                            echo -e "  ${GREEN}✓${NC} ${DB_NAME}: Clean (no rating feature)"
                        elif [[ "${CHANGESET_EXISTS}" != "0" ]] || [[ "${RATING_COLUMN_EXISTS}" != "0" ]]; then
                            echo -e "  ${RED}✗${NC} ${DB_NAME}: Rating feature exists (changeset: ${CHANGESET_EXISTS}, column: ${RATING_COLUMN_EXISTS})"
                            ISSUES+=("${DB_NAME} has rating feature")
                        else
                            echo -e "  ${YELLOW}⚠${NC}  ${DB_NAME}: Unknown state"
                            ISSUES+=("${DB_NAME} unknown state")
                        fi
                    done

                    echo ""
                fi
            fi
        fi

        cd "${REPO_ROOT}"
    fi
fi

#
# Summary
#
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verification Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ Ready for Demo${NC}"
    echo ""
    echo "All checks passed. You can run:"
    echo "  ./scripts/demo/apply-rating-demo.sh"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Not Ready for Demo${NC}"
    echo ""
    echo "Issues found:"
    for issue in "${ISSUES[@]}"; do
        echo "  • ${issue}"
    done
    echo ""
    echo "To fix:"
    echo "  1. Switch to main: git checkout main"
    echo "  2. Clean working tree: git checkout -- . && git clean -fd"
    echo "  3. Rollback databases: ./scripts/demo/rollback-rating-demo.sh"
    echo ""
    exit 1
fi
