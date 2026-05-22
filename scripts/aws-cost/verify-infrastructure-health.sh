#!/bin/bash
# Verify Infrastructure Health
#
# Quick health check to verify all AWS resources are running and responding.
# Checks infrastructure status and basic connectivity (~30 seconds).
#
# Usage:
#   ./scripts/aws-cost/verify-infrastructure-health.sh [OPTIONS]
#
# Options:
#   --verbose  Show detailed output
#   --help     Show help message
#
# Exit Codes:
#   0 - All checks passed
#   1 - One or more checks failed

set -euo pipefail

# ===== Color Codes =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===== Configuration =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STATE_DIR="$SCRIPT_DIR/../aws-cost-state"
STATE_FILE="$STATE_DIR/hibernate-state.json"

# ===== Default Options =====
VERBOSE=false

# ===== Helper Functions =====

info() {
    echo -e "${GREEN}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}"
}

error() {
    echo -e "${RED}$1${NC}" >&2
}

step() {
    echo -e "${BLUE}$1${NC}"
}

show_help() {
    cat << EOF
Verify Infrastructure Health - Quick health check after resume

Usage:
  verify-infrastructure-health.sh [OPTIONS]

Options:
  --verbose  Show detailed output
  --help     Show this help

Health Checks:
  1. Infrastructure Status (AWS API)
     - RDS: status=available
     - App Runner: status=RUNNING (4 environments)
     - EC2 Delegate: instance running

  2. Service Connectivity (HTTP)
     - RDS: pg_isready test
     - App Runner: /health endpoint (200 OK)
     - Harness Delegate: Connected status

Duration: ~30 seconds

Examples:
  # Quick health check
  ./scripts/aws-cost/verify-infrastructure-health.sh

  # Detailed output
  ./scripts/aws-cost/verify-infrastructure-health.sh --verbose

EOF
}

# Retry helper with backoff
retry_with_backoff() {
    local max_attempts=3
    local delay=5
    local attempt=1
    local command="$@"

    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        fi

        if [ $attempt -lt $max_attempts ]; then
            if [ "$VERBOSE" = true ]; then
                echo "    Retry $attempt/$max_attempts (waiting ${delay}s)..."
            fi
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# ===== Argument Parsing =====

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ===== Initialize =====

HEALTH_CHECK_START=$(date +%s)
FAILED_CHECKS=0

echo "=== Infrastructure Health Check ==="
echo ""

# Check if state file exists
if [ -f "$STATE_FILE" ]; then
    # Load from state file
    DEMO_ID=$(jq -r '.demo_id' "$STATE_FILE")
    AWS_REGION=$(jq -r '.aws_region' "$STATE_FILE")
    RDS_IDENTIFIER=$(jq -r '.rds.identifier' "$STATE_FILE")
    RDS_ADDRESS=$(jq -r '.rds.address' "$STATE_FILE")
    RDS_PORT=$(jq -r '.rds.port' "$STATE_FILE")

    APP_RUNNER_DEV_URL=$(jq -r '.app_runner.dev.service_url' "$STATE_FILE")
    APP_RUNNER_TEST_URL=$(jq -r '.app_runner.test.service_url' "$STATE_FILE")
    APP_RUNNER_STAGING_URL=$(jq -r '.app_runner.staging.service_url' "$STATE_FILE")
    APP_RUNNER_PROD_URL=$(jq -r '.app_runner.prod.service_url' "$STATE_FILE")

    APP_RUNNER_DEV_ARN=$(jq -r '.app_runner.dev.service_arn' "$STATE_FILE")
    APP_RUNNER_TEST_ARN=$(jq -r '.app_runner.test.service_arn' "$STATE_FILE")
    APP_RUNNER_STAGING_ARN=$(jq -r '.app_runner.staging.service_arn' "$STATE_FILE")
    APP_RUNNER_PROD_ARN=$(jq -r '.app_runner.prod.service_arn' "$STATE_FILE")
else
    # Try to load from terraform outputs
    if [ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]; then
        cd "$PROJECT_ROOT/terraform"

        TFVARS_FILE="$PROJECT_ROOT/terraform/terraform.tfvars"
        DEMO_ID=$(grep '^demo_id' "$TFVARS_FILE" | cut -d'=' -f2 | tr -d ' "')
        AWS_REGION=$(terraform output -raw deployment_summary 2>/dev/null | jq -r '.aws_region' || aws configure get region || echo "us-east-1")

        RDS_IDENTIFIER="${DEMO_ID}-rds"
        RDS_ADDRESS=$(terraform output -raw rds_address 2>/dev/null || echo "")
        RDS_PORT=$(terraform output -raw rds_port 2>/dev/null || echo "5432")

        # Get App Runner URLs from terraform
        APP_RUNNER_DEV_URL=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.dev.service_url // empty')
        APP_RUNNER_TEST_URL=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.test.service_url // empty')
        APP_RUNNER_STAGING_URL=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.staging.service_url // empty')
        APP_RUNNER_PROD_URL=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.prod.service_url // empty')

        APP_RUNNER_DEV_ARN=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.dev.service_arn // empty')
        APP_RUNNER_TEST_ARN=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.test.service_arn // empty')
        APP_RUNNER_STAGING_ARN=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.staging.service_arn // empty')
        APP_RUNNER_PROD_ARN=$(terraform output -json app_runner_services 2>/dev/null | jq -r '.prod.service_arn // empty')
    else
        error "Cannot find state file or terraform state"
        echo "Run resume-infrastructure.sh first or ensure terraform is initialized"
        exit 1
    fi
fi

echo "Region: $AWS_REGION"
echo "Demo ID: $DEMO_ID"
echo ""

# ===== Level 1: Infrastructure Status =====

step "[1/2] Infrastructure Status..."
LEVEL1_START=$(date +%s)

# Check RDS
echo -n "  RDS ($RDS_IDENTIFIER)... "
CHECK_START=$(date +%s)

RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

CHECK_ELAPSED=$(($(date +%s) - CHECK_START))

if [ "$RDS_STATUS" = "available" ]; then
    info "✓ available (${CHECK_ELAPSED}s)"
else
    error "✗ $RDS_STATUS"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check App Runner services
check_app_runner_status() {
    local ENV=$1
    local ARN=$2

    echo -n "  App Runner $ENV... "
    CHECK_START=$(date +%s)

    STATUS=$(aws apprunner describe-service \
        --service-arn "$ARN" \
        --query 'Service.Status' \
        --output text 2>/dev/null || echo "not-found")

    CHECK_ELAPSED=$(($(date +%s) - CHECK_START))

    if [ "$STATUS" = "RUNNING" ]; then
        info "✓ RUNNING (${CHECK_ELAPSED}s)"
        return 0
    else
        error "✗ $STATUS"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_app_runner_status "dev" "$APP_RUNNER_DEV_ARN"
check_app_runner_status "test" "$APP_RUNNER_TEST_ARN"
check_app_runner_status "staging" "$APP_RUNNER_STAGING_ARN"
check_app_runner_status "prod" "$APP_RUNNER_PROD_ARN"

# Check EC2 Delegate
if [ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]; then
    cd "$PROJECT_ROOT/terraform"
    DELEGATE_INSTANCE_ID=$(terraform output -raw delegate_instance_id 2>/dev/null || echo "")

    if [ -n "$DELEGATE_INSTANCE_ID" ]; then
        echo -n "  EC2 Delegate ($DELEGATE_INSTANCE_ID)... "
        CHECK_START=$(date +%s)

        DELEGATE_STATE=$(aws ec2 describe-instances \
            --instance-ids "$DELEGATE_INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text 2>/dev/null || echo "not-found")

        CHECK_ELAPSED=$(($(date +%s) - CHECK_START))

        if [ "$DELEGATE_STATE" = "running" ]; then
            info "✓ running (${CHECK_ELAPSED}s)"
        else
            error "✗ $DELEGATE_STATE"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
fi

LEVEL1_ELAPSED=$(($(date +%s) - LEVEL1_START))
echo ""

# ===== Level 2: Service Connectivity =====

step "[2/2] Service Connectivity..."
LEVEL2_START=$(date +%s)

# Check RDS connectivity
if [ -n "$RDS_ADDRESS" ]; then
    echo -n "  RDS endpoint ($RDS_ADDRESS:$RDS_PORT)... "
    CHECK_START=$(date +%s)

    if command -v pg_isready &> /dev/null; then
        if retry_with_backoff "pg_isready -h $RDS_ADDRESS -p $RDS_PORT &>/dev/null"; then
            CHECK_ELAPSED=$(($(date +%s) - CHECK_START))
            info "✓ responding (${CHECK_ELAPSED}s)"
        else
            error "✗ not responding"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    else
        warn "⚠ pg_isready not installed, skipping"
    fi
fi

# Check App Runner health endpoints
check_app_runner_health() {
    local ENV=$1
    local URL=$2

    echo -n "  App $ENV (https://$URL)... "
    CHECK_START=$(date +%s)

    HTTP_CODE=$(retry_with_backoff "curl -s -o /dev/null -w '%{http_code}' 'https://$URL/health'" || echo "000")

    CHECK_ELAPSED=$(($(date +%s) - CHECK_START))

    if [ "$HTTP_CODE" = "200" ]; then
        info "✓ 200 OK (${CHECK_ELAPSED}s)"
        return 0
    else
        error "✗ HTTP $HTTP_CODE"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

check_app_runner_health "dev" "$APP_RUNNER_DEV_URL"
check_app_runner_health "test" "$APP_RUNNER_TEST_URL"
check_app_runner_health "staging" "$APP_RUNNER_STAGING_URL"
check_app_runner_health "prod" "$APP_RUNNER_PROD_URL"

# Check Harness Delegate connectivity
if [ -f "$PROJECT_ROOT/harness/.env" ]; then
    echo -n "  Harness delegate... "
    CHECK_START=$(date +%s)

    source "$PROJECT_ROOT/harness/.env"

    if [ -n "${HARNESS_API_KEY:-}" ] && [ -n "${HARNESS_ACCOUNT_ID:-}" ] && [ -n "${HARNESS_PROJECT_ID:-}" ]; then
        DELEGATE_STATUS=$(curl -s -X GET \
            "https://app.harness.io/ng/api/delegate-token-ng/delegate-groups?accountId=${HARNESS_ACCOUNT_ID}&orgId=default&projectId=${HARNESS_PROJECT_ID}" \
            -H "x-api-key: ${HARNESS_API_KEY}" \
            | jq -r ".resource.delegateGroupDetails[] | select(.groupName == \"${DEMO_ID}-harness-delegate\") | .activelyConnected" 2>/dev/null || echo "false")

        CHECK_ELAPSED=$(($(date +%s) - CHECK_START))

        if [ "$DELEGATE_STATUS" = "true" ]; then
            info "✓ Connected (${CHECK_ELAPSED}s)"
        else
            warn "⚠ Not connected yet (may still be registering)"
            if [ "$VERBOSE" = true ]; then
                echo "    Note: Delegate may take 1-2 minutes after EC2 instance starts"
            fi
        fi
    else
        warn "⚠ Harness credentials not configured, skipping"
    fi
fi

LEVEL2_ELAPSED=$(($(date +%s) - LEVEL2_START))
echo ""

# ===== Summary =====

TOTAL_TIME=$(($(date +%s) - HEALTH_CHECK_START))

step "[Summary]"
if [ $FAILED_CHECKS -eq 0 ]; then
    info "  ✓ All checks passed (${TOTAL_TIME}s total)"
    info "  ✓ Infrastructure fully operational"
    echo ""
    exit 0
else
    error "  ✗ $FAILED_CHECKS check(s) failed"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check AWS Console for resource status"
    echo "  • Verify security groups allow traffic"
    echo "  • Wait a few minutes for services to stabilize"
    echo "  • Run with --verbose for detailed output"
    echo ""
    exit 1
fi
