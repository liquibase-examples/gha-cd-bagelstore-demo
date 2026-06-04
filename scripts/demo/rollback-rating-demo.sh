#!/usr/bin/env bash
#
# rollback-rating-demo.sh - Rollback product rating feature from all environments
#
# Usage: ./scripts/demo/rollback-rating-demo.sh
#
# What it does:
# 1. Resets git working tree (discards uncommitted changes)
# 2. Connects to AWS RDS databases via terraform outputs
# 3. Rollbacks rating changeset from dev, test, staging, prod
# 4. Rolls back App Runner services to the baseline Docker image
# 5. Handles missing changesets gracefully (not yet deployed)
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
BASELINE_APP_IMAGE="public.ecr.aws/l1v5b6d6/psr-bagel-store:main-b5660a6"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rollback Product Rating Feature${NC}"
echo -e "${BLUE}  Reset Demo Environment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

#
# Part 1: Reset Git (revert ratings commit + discard uncommitted changes)
#
echo -e "${CYAN}Part 1: Reset Git${NC}"
echo ""

# Discard any uncommitted changes first
echo -e "${YELLOW}→${NC} Checking for uncommitted changes..."
if ! git -C "${REPO_ROOT}" diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${YELLOW}→${NC} Discarding uncommitted changes..."
    git -C "${REPO_ROOT}" checkout -- .
    git -C "${REPO_ROOT}" clean -fd
    echo -e "${GREEN}✓${NC} Working tree cleaned"
else
    echo -e "${GREEN}✓${NC} Working tree is clean"
fi

# Check if the ratings commit needs to be reverted
echo -e "${YELLOW}→${NC} Checking for ratings feature commit..."
RATINGS_COMMIT=$(git -C "${REPO_ROOT}" log --oneline --grep="Add ratings feature" -1 --format="%H")

if [[ -n "${RATINGS_COMMIT}" ]]; then
    echo -e "${YELLOW}→${NC} Reverting ratings commit: $(git -C "${REPO_ROOT}" log --oneline -1 "${RATINGS_COMMIT}")"
    if git -C "${REPO_ROOT}" revert --no-edit "${RATINGS_COMMIT}"; then
        echo -e "${GREEN}✓${NC} Ratings commit reverted"
    else
        echo -e "${RED}❌ Error: Failed to revert ratings commit${NC}"
        echo "  You may need to resolve conflicts manually"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} No ratings commit found - already at baseline"
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
    echo "  Export AWS profile: export AWS_PROFILE=liquibase-sandbox-owner"
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

    PSQL_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${RDS_ADDRESS}:${RDS_PORT}/${DB_NAME}"

    # Check if changeset 008 exists in DATABASECHANGELOG
    echo -e "    ${YELLOW}→${NC} Checking for changeset 008..."
    CHANGESET_COUNT=$(docker run --rm \
        --network host \
        postgres:16 \
        psql "${PSQL_URL}" \
        -tAc "SELECT COUNT(*) FROM databasechangelog WHERE id = '008-add-product-ratings';" 2>/dev/null | tr -d '[:space:]' || echo "0")

    if [[ "${CHANGESET_COUNT}" == "0" ]]; then
        echo -e "    ${YELLOW}⊘${NC}  Changeset not found - skipping"
        SKIPPED+=("${DB_NAME}")
        echo ""
        continue
    fi

    echo -e "    ${GREEN}✓${NC} Changeset found"

    # Roll back via direct SQL (reliable regardless of changelog file order)
    echo -e "    ${YELLOW}→${NC} Dropping rating column and cleaning DATABASECHANGELOG..."

    ROLLBACK_OUTPUT=$(docker run --rm \
        --network host \
        postgres:16 \
        psql "${PSQL_URL}" \
        -c "ALTER TABLE products DROP COLUMN IF EXISTS rating;
            DELETE FROM databasechangelog WHERE id = '008-add-product-ratings';
            DELETE FROM databasechangelog WHERE id = 'tag-v1.0.0';" 2>&1)

    if echo "${ROLLBACK_OUTPUT}" | grep -q "ALTER TABLE"; then
        echo -e "    ${GREEN}✓${NC} Rollback successful"
        ROLLED_BACK+=("${DB_NAME}")
    else
        echo -e "    ${RED}✗${NC} Rollback failed: ${ROLLBACK_OUTPUT}"
        FAILED+=("${DB_NAME}")
    fi

    echo ""
done

cd "${REPO_ROOT}"

#
# Part 3: Rollback App Runner Services to Baseline Image
#
echo ""
echo -e "${CYAN}Part 3: Rollback App Runner Services${NC}"
echo ""

APP_RUNNER_UPDATED=()
APP_RUNNER_SKIPPED=()
APP_RUNNER_FAILED=()

echo -e "${YELLOW}→${NC} Rolling back App Runner services to baseline image: ${BASELINE_APP_IMAGE}..."
echo ""

for ENV_NAME in "${DATABASES[@]}"; do
    SERVICE_ARN=$(echo "${TERRAFORM_OUTPUT}" | jq -r ".app_runner_services.value.${ENV_NAME}.service_arn")

    if [[ "${SERVICE_ARN}" == "null" ]] || [[ -z "${SERVICE_ARN}" ]]; then
        echo -e "${CYAN}  ${ENV_NAME}:${NC}"
        echo -e "    ${YELLOW}⊘${NC}  No App Runner service found - skipping"
        APP_RUNNER_SKIPPED+=("${ENV_NAME}")
        echo ""
        continue
    fi

    echo -e "${CYAN}  ${ENV_NAME}:${NC}"
    echo -e "    ${YELLOW}→${NC} Deploying baseline image..."

    UPDATE_OUTPUT=$(aws apprunner update-service \
        --service-arn "${SERVICE_ARN}" \
        --region us-east-1 \
        --source-configuration "{\"ImageRepository\":{\"ImageIdentifier\":\"${BASELINE_APP_IMAGE}\",\"ImageRepositoryType\":\"ECR_PUBLIC\",\"ImageConfiguration\":{\"Port\":\"5000\"}}}" \
        --query 'Service.Status' \
        --output text 2>&1) || UPDATE_OUTPUT="${UPDATE_OUTPUT}"

    if [[ "${UPDATE_OUTPUT}" == "OPERATION_IN_PROGRESS" ]]; then
        echo -e "    ${GREEN}✓${NC} Update started (OPERATION_IN_PROGRESS)"
        APP_RUNNER_UPDATED+=("${ENV_NAME}")
    elif [[ "${UPDATE_OUTPUT}" == "RUNNING" ]]; then
        echo -e "    ${GREEN}✓${NC} Already running correct image"
        APP_RUNNER_UPDATED+=("${ENV_NAME}")
    elif echo "${UPDATE_OUTPUT}" | grep -q "OPERATION_IN_PROGRESS"; then
        echo -e "    ${GREEN}✓${NC} Update already in progress"
        APP_RUNNER_UPDATED+=("${ENV_NAME}")
    else
        echo -e "    ${RED}✗${NC} Update failed: ${UPDATE_OUTPUT}"
        APP_RUNNER_FAILED+=("${ENV_NAME}")
    fi

    echo ""
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Rollback Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${CYAN}Git working tree:${NC} Reset to HEAD"
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

echo -e "${CYAN}App Runner rollbacks:${NC}"
if [[ ${#APP_RUNNER_UPDATED[@]} -gt 0 ]]; then
    echo -e "  ${GREEN}✓ Updated (${#APP_RUNNER_UPDATED[@]}):${NC} ${APP_RUNNER_UPDATED[*]}"
fi

if [[ ${#APP_RUNNER_SKIPPED[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}⊘ Skipped (${#APP_RUNNER_SKIPPED[@]}):${NC} ${APP_RUNNER_SKIPPED[*]}"
fi

if [[ ${#APP_RUNNER_FAILED[@]} -gt 0 ]]; then
    echo -e "  ${RED}✗ Failed (${#APP_RUNNER_FAILED[@]}):${NC} ${APP_RUNNER_FAILED[*]}"
fi

echo ""

HAS_FAILURES=false
if [[ ${#FAILED[@]} -gt 0 ]] || [[ ${#APP_RUNNER_FAILED[@]} -gt 0 ]]; then
    HAS_FAILURES=true
fi

if [[ "${HAS_FAILURES}" == "false" ]]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ Demo Reset Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Ready for next demonstration:"
    echo "  ./scripts/demo/apply-rating-demo.sh"
    echo ""
    if [[ ${#APP_RUNNER_UPDATED[@]} -gt 0 ]]; then
        echo "Note: App Runner deployments take a few minutes to complete."
        echo ""
    fi
else
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}  ⚠ Rollback Completed with Errors${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    echo "Some rollbacks had issues. Check logs above for details."
    echo ""
fi
