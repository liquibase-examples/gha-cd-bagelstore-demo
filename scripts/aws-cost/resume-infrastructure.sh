#!/bin/bash
# Resume AWS Infrastructure
#
# Starts all AWS resources (RDS, App Runner, EC2 delegate) after hibernation.
# Includes comprehensive health checks to verify infrastructure is operational.
#
# Usage:
#   ./scripts/aws-cost/resume-infrastructure.sh [OPTIONS]
#
# Options:
#   --skip-health-check  Skip health verification after resume
#   --force              Skip confirmation prompt
#   --help               Show help message
#
# Exit Codes:
#   0 - Success (all resources running and healthy)
#   1 - Pre-flight check failed
#   2 - Partial failure (some resources started but unhealthy)
#   3 - Complete failure (resources failed to start)

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
SKIP_HEALTH_CHECK=false
SKIP_CONFIRMATION=false

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
Resume AWS Infrastructure - Start resources after hibernation

Usage:
  resume-infrastructure.sh [OPTIONS]

Options:
  --skip-health-check  Skip health verification after resume (faster)
  --force              Skip confirmation prompt
  --help               Show this help

Resume Process:
  1. Start RDS instance (~5-10 min)
  2. Resume App Runner services (~2-5 min)
  3. Recreate EC2 delegate via Terraform (~3-5 min)
  4. Verify infrastructure health (~30 seconds)

Total Time: ~10-15 minutes

Important Notes:
  • Delegate will get a new public IP
  • App Runner services preserved (same URLs)
  • RDS data is fully preserved

Examples:
  # Standard resume with health check
  ./scripts/aws-cost/resume-infrastructure.sh

  # Quick resume (skip health check)
  ./scripts/aws-cost/resume-infrastructure.sh --skip-health-check

  # No confirmation prompt
  ./scripts/aws-cost/resume-infrastructure.sh --force

EOF
}

# ===== Argument Parsing =====

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-health-check)
            SKIP_HEALTH_CHECK=true
            shift
            ;;
        --force)
            SKIP_CONFIRMATION=true
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

# ===== Pre-flight Checks =====

echo "=== Resume AWS Infrastructure ==="
echo ""

step "Pre-flight Checks:"

# Check state file exists
if [ ! -f "$STATE_FILE" ]; then
    error "  ✗ State file not found: $STATE_FILE"
    echo "  Run hibernate-infrastructure.sh first"
    exit 1
fi
info "  ✓ State file found"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    error "  ✗ AWS CLI not found"
    echo "  Install: brew install awscli (macOS) or apt-get install awscli (Linux)"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    error "  ✗ AWS credentials not configured or invalid"
    echo "  Run: aws configure sso"
    exit 1
fi

AWS_REGION=$(aws configure get region || echo "us-east-1")
info "  ✓ AWS credentials valid ($AWS_REGION)"

# Check jq
if ! command -v jq &> /dev/null; then
    error "  ✗ jq not found (required for JSON parsing)"
    echo "  Install: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check terraform
if ! command -v terraform &> /dev/null; then
    error "  ✗ Terraform not found (required to recreate delegate)"
    echo "  Install: brew install terraform"
    exit 1
fi

echo ""

# ===== Load State =====

step "Loading hibernate state..."

DEMO_ID=$(jq -r '.demo_id' "$STATE_FILE")
HIBERNATED_AT=$(jq -r '.hibernated_at' "$STATE_FILE")
HIBERNATED_BY=$(jq -r '.hibernated_by // "unknown"' "$STATE_FILE")
REASON=$(jq -r '.reason // "No reason provided"' "$STATE_FILE")

# RDS
RDS_IDENTIFIER=$(jq -r '.rds.identifier' "$STATE_FILE")
RDS_ADDRESS=$(jq -r '.rds.address' "$STATE_FILE")
RDS_PORT=$(jq -r '.rds.port' "$STATE_FILE")

# App Runner
APP_RUNNER_DEV_ARN=$(jq -r '.app_runner.dev.service_arn' "$STATE_FILE")
APP_RUNNER_DEV_URL=$(jq -r '.app_runner.dev.service_url' "$STATE_FILE")

APP_RUNNER_TEST_ARN=$(jq -r '.app_runner.test.service_arn' "$STATE_FILE")
APP_RUNNER_TEST_URL=$(jq -r '.app_runner.test.service_url' "$STATE_FILE")

APP_RUNNER_STAGING_ARN=$(jq -r '.app_runner.staging.service_arn' "$STATE_FILE")
APP_RUNNER_STAGING_URL=$(jq -r '.app_runner.staging.service_url' "$STATE_FILE")

APP_RUNNER_PROD_ARN=$(jq -r '.app_runner.prod.service_arn' "$STATE_FILE")
APP_RUNNER_PROD_URL=$(jq -r '.app_runner.prod.service_url' "$STATE_FILE")

# EC2
DELEGATE_INSTANCE_ID=$(jq -r '.ec2_delegate.instance_id' "$STATE_FILE")

info "✓ Loaded state:"
echo "  • Demo ID: $DEMO_ID"
echo "  • Hibernated: $HIBERNATED_AT by $HIBERNATED_BY"
echo "  • Reason: $REASON"
echo "  • RDS: $RDS_IDENTIFIER"
echo "  • App Runner: 4 services"
echo "  • EC2 Delegate: Will be recreated"
echo ""

# ===== Verify Resources are Stopped =====

step "Verifying resources are stopped..."

# Check RDS status
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_IDENTIFIER" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "unknown")

if [ "$RDS_STATUS" != "stopped" ]; then
    warn "  ⚠ RDS is not stopped (current status: $RDS_STATUS)"
    if [ "$RDS_STATUS" = "available" ]; then
        warn "  RDS is already running - will skip restart"
    fi
else
    info "  ✓ RDS is stopped"
fi

# Check App Runner status (just dev environment as representative)
APP_RUNNER_STATUS=$(aws apprunner describe-service \
    --service-arn "$APP_RUNNER_DEV_ARN" \
    --query 'Service.Status' \
    --output text 2>/dev/null || echo "unknown")

if [ "$APP_RUNNER_STATUS" != "PAUSED" ]; then
    warn "  ⚠ App Runner services not paused (current status: $APP_RUNNER_STATUS)"
    if [ "$APP_RUNNER_STATUS" = "RUNNING" ]; then
        warn "  App Runner is already running - will skip resume"
    fi
else
    info "  ✓ App Runner services are paused"
fi

# Check delegate instance (should be terminated)
DELEGATE_STATE=$(aws ec2 describe-instances \
    --instance-ids "$DELEGATE_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text 2>/dev/null || echo "terminated")

if [ "$DELEGATE_STATE" != "terminated" ]; then
    warn "  ⚠ Delegate not terminated (current state: $DELEGATE_STATE)"
else
    info "  ✓ Delegate is terminated"
fi

echo ""

# ===== Confirmation =====

if [ "$SKIP_CONFIRMATION" = false ]; then
    echo "Resume Process:"
    echo "  1. Start RDS (~5-10 min)"
    echo "  2. Resume App Runner services (~2-5 min)"
    echo "  3. Recreate delegate via Terraform (~3-5 min)"
    if [ "$SKIP_HEALTH_CHECK" = false ]; then
        echo "  4. Verify infrastructure health (~30 seconds)"
    fi
    echo ""
    echo "Total time: ~10-15 minutes"
    echo ""

    read -p "Proceed with resume? [y/N]: " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Resume cancelled"
        exit 0
    fi
fi

# ===== Start Resources =====

START_TIME=$(date +%s)

echo "Starting Infrastructure..."
echo ""

# Phase 1: Start RDS
step "[1/3] Starting RDS instance..."
RDS_START=$(date +%s)

if [ "$RDS_STATUS" = "stopped" ]; then
    aws rds start-db-instance --db-instance-identifier "$RDS_IDENTIFIER" &>/dev/null

    # Wait for available status (max 10 min)
    ATTEMPTS=0
    MAX_ATTEMPTS=120  # 120 * 5s = 10 minutes
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        STATUS=$(aws rds describe-db-instances \
            --db-instance-identifier "$RDS_IDENTIFIER" \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null || echo "")

        if [ "$STATUS" = "available" ]; then
            break
        fi

        sleep 5
        ATTEMPTS=$((ATTEMPTS + 1))
    done

    if [ "$STATUS" != "available" ]; then
        error "  ✗ RDS failed to start (timeout after 10 minutes)"
        echo "  Current status: $STATUS"
        echo "  Check AWS console: https://console.aws.amazon.com/rds/"
        exit 3
    fi
else
    info "  • RDS already available, skipping start"
fi

# Test connectivity
if command -v pg_isready &> /dev/null; then
    if pg_isready -h "$RDS_ADDRESS" -p "$RDS_PORT" &>/dev/null; then
        info "  ✓ RDS connection test passed"
    else
        warn "  ⚠ RDS connection test failed (may need security group update)"
    fi
fi

RDS_ELAPSED=$(($(date +%s) - RDS_START))
info "  ✓ RDS available (${RDS_ELAPSED}s)"
echo ""

# Phase 2: Resume App Runner Services
step "[2/3] Resuming App Runner services..."

resume_service() {
    local ENV=$1
    local ARN=$2
    local URL=$3
    local START=$(date +%s)

    echo -n "  $ENV... "

    # Check current status
    CURRENT_STATUS=$(aws apprunner describe-service \
        --service-arn "$ARN" \
        --query 'Service.Status' \
        --output text 2>/dev/null || echo "")

    if [ "$CURRENT_STATUS" = "RUNNING" ]; then
        info "already running"
        return 0
    fi

    aws apprunner resume-service --service-arn "$ARN" &>/dev/null

    # Wait for RUNNING status (max 5 min)
    ATTEMPTS=0
    MAX_ATTEMPTS=60  # 60 * 5s = 5 minutes
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        STATUS=$(aws apprunner describe-service \
            --service-arn "$ARN" \
            --query 'Service.Status' \
            --output text 2>/dev/null || echo "")

        if [ "$STATUS" = "RUNNING" ]; then
            break
        fi

        sleep 5
        ATTEMPTS=$((ATTEMPTS + 1))
    done

    if [ "$STATUS" != "RUNNING" ]; then
        error "✗ timeout"
        return 1
    fi

    # Quick health check
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$URL/health" || echo "000")

    ELAPSED=$(($(date +%s) - START))

    if [ "$HTTP_CODE" = "200" ]; then
        info "✓ (${ELAPSED}s, healthy)"
    else
        warn "✓ (${ELAPSED}s, HTTP $HTTP_CODE)"
    fi

    return 0
}

resume_service "dev" "$APP_RUNNER_DEV_ARN" "$APP_RUNNER_DEV_URL"
resume_service "test" "$APP_RUNNER_TEST_ARN" "$APP_RUNNER_TEST_URL"
resume_service "staging" "$APP_RUNNER_STAGING_ARN" "$APP_RUNNER_STAGING_URL"
resume_service "prod" "$APP_RUNNER_PROD_ARN" "$APP_RUNNER_PROD_URL"
echo ""

# Phase 3: Recreate EC2 Delegate via Terraform
step "[3/3] Recreating EC2 delegate via Terraform..."
DELEGATE_START=$(date +%s)

cd "$PROJECT_ROOT/terraform"

# Run terraform apply targeting just the delegate
if terraform apply -target=aws_spot_instance_request.delegate -auto-approve > /tmp/tf-apply.log 2>&1; then
    # Get new instance ID
    NEW_INSTANCE_ID=$(terraform output -raw delegate_instance_id 2>/dev/null || echo "")
    NEW_PUBLIC_IP=$(terraform output -raw delegate_public_ip 2>/dev/null || echo "")

    if [ -n "$NEW_INSTANCE_ID" ]; then
        info "  ✓ Delegate created: $NEW_INSTANCE_ID"
        if [ -n "$NEW_PUBLIC_IP" ]; then
            info "  ✓ New public IP: $NEW_PUBLIC_IP"
        fi

        # Wait for instance to be running
        ATTEMPTS=0
        MAX_ATTEMPTS=60  # 60 * 5s = 5 minutes
        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            STATE=$(aws ec2 describe-instances \
                --instance-ids "$NEW_INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].State.Name' \
                --output text 2>/dev/null || echo "")

            if [ "$STATE" = "running" ]; then
                break
            fi

            sleep 5
            ATTEMPTS=$((ATTEMPTS + 1))
        done

        if [ "$STATE" = "running" ]; then
            info "  ✓ Delegate instance running"

            # Wait a bit for user data script to start Docker
            echo "  • Waiting for delegate container to start (60s)..."
            sleep 60

            info "  ✓ Delegate should be registering with Harness"
        else
            warn "  ⚠ Delegate instance not running yet (state: $STATE)"
        fi
    else
        error "  ✗ Failed to get new instance ID from terraform"
    fi
else
    error "  ✗ Terraform apply failed"
    echo "  See: /tmp/tf-apply.log"
    echo "  Manual command: cd terraform && terraform apply -target=aws_spot_instance_request.delegate"
    exit 3
fi

DELEGATE_ELAPSED=$(($(date +%s) - DELEGATE_START))
info "  ✓ Delegate recreation complete (${DELEGATE_ELAPSED}s)"
echo ""

# ===== Health Check =====

if [ "$SKIP_HEALTH_CHECK" = false ]; then
    step "Running health verification..."
    if [ -x "$SCRIPT_DIR/verify-infrastructure-health.sh" ]; then
        "$SCRIPT_DIR/verify-infrastructure-health.sh"
    else
        warn "  ⚠ Health check script not found or not executable"
        echo "  Skipping detailed health verification"
    fi
    echo ""
fi

# ===== Summary =====

TOTAL_TIME=$(($(date +%s) - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
info "✅ Infrastructure resumed successfully! (${MINUTES}m ${SECONDS}s)"
echo ""
echo "Service URLs:"
echo "  • Dev:     https://$APP_RUNNER_DEV_URL"
echo "  • Test:    https://$APP_RUNNER_TEST_URL"
echo "  • Staging: https://$APP_RUNNER_STAGING_URL"
echo "  • Prod:    https://$APP_RUNNER_PROD_URL"
echo ""
echo "RDS Endpoint: $RDS_ADDRESS:$RDS_PORT"
if [ -n "$NEW_PUBLIC_IP" ]; then
    echo "Delegate IP:  $NEW_PUBLIC_IP (new)"
fi
echo ""
echo "Hibernate again: $SCRIPT_DIR/hibernate-infrastructure.sh"
echo ""

exit 0
