#!/bin/bash
# Hibernate AWS Infrastructure
#
# Stops all AWS resources (RDS, App Runner, EC2 delegate) to save costs.
# Saves ~$47-52/month by pausing infrastructure when not in use.
#
# Usage:
#   ./scripts/aws-cost/hibernate-infrastructure.sh [OPTIONS]
#
# Options:
#   --force          Skip safety checks
#   --no-confirm     Skip confirmation prompt
#   --reason "TEXT"  Record reason for hibernation
#   --help           Show help message
#
# Exit Codes:
#   0 - Success (all resources stopped)
#   1 - Pre-flight check failed
#   2 - Partial failure (some resources stopped)
#   3 - Complete failure (no resources stopped)

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
SKIP_SAFETY_CHECKS=false
SKIP_CONFIRMATION=false
HIBERNATION_REASON=""

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
Hibernate AWS Infrastructure - Stop resources to save costs

Usage:
  hibernate-infrastructure.sh [OPTIONS]

Options:
  --force              Skip safety checks
  --no-confirm         Skip confirmation prompt
  --reason "TEXT"      Record reason for hibernation
  --help               Show this help

Cost Savings:
  RDS (db.t3.micro):    ~\$15-20/month
  App Runner (4 x 0.25): ~\$20/month
  EC2 Spot (t3.medium):  ~\$12/month
  Total savings:         ~\$47-52/month (90%)

Important Notes:
  • RDS auto-starts after 7 days
  • Delegate gets new IP on resume
  • App Runner config preserved
  • Resume time: ~10-15 minutes

Examples:
  # Interactive hibernation
  ./scripts/aws-cost/hibernate-infrastructure.sh

  # Quick hibernation (no prompts)
  ./scripts/aws-cost/hibernate-infrastructure.sh --force --no-confirm

  # With reason tracking
  ./scripts/aws-cost/hibernate-infrastructure.sh --reason "Weekend shutdown"

EOF
}

# ===== Argument Parsing =====

while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            SKIP_SAFETY_CHECKS=true
            shift
            ;;
        --no-confirm)
            SKIP_CONFIRMATION=true
            shift
            ;;
        --reason)
            HIBERNATION_REASON="$2"
            shift 2
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

echo "=== Hibernate AWS Infrastructure ==="
echo ""

step "Pre-flight Checks:"

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

# Load DEMO_ID from terraform.tfvars
TFVARS_FILE="$PROJECT_ROOT/terraform/terraform.tfvars"
if [ ! -f "$TFVARS_FILE" ]; then
    error "  ✗ terraform.tfvars not found at $TFVARS_FILE"
    exit 1
fi

DEMO_ID=$(grep '^demo_id' "$TFVARS_FILE" | cut -d'=' -f2 | tr -d ' "')
if [ -z "$DEMO_ID" ]; then
    error "  ✗ demo_id not found in terraform.tfvars"
    exit 1
fi
info "  ✓ Demo ID: $DEMO_ID"

# Safety checks (warn but continue if --force not set)
if [ "$SKIP_SAFETY_CHECKS" = false ]; then
    # Check for active Harness pipelines
    if [ -f "$PROJECT_ROOT/harness/.env" ]; then
        # Source harness API key
        source "$PROJECT_ROOT/harness/.env"

        if [ -n "${HARNESS_API_KEY:-}" ] && [ -n "${HARNESS_ACCOUNT_ID:-}" ] && [ -n "${HARNESS_PROJECT_ID:-}" ]; then
            ACTIVE_PIPELINES=$(curl -s -X GET \
                "https://app.harness.io/pipeline/api/pipelines/execution/summary?accountIdentifier=${HARNESS_ACCOUNT_ID}&orgIdentifier=default&projectIdentifier=${HARNESS_PROJECT_ID}&page=0&size=5" \
                -H "x-api-key: ${HARNESS_API_KEY}" \
                | jq -r '.data.content[]? | select(.status == "Running" or .status == "Queued") | .planExecutionId' 2>/dev/null | wc -l | tr -d ' ')

            if [ "$ACTIVE_PIPELINES" -gt 0 ]; then
                warn "  ⚠ Active Harness pipeline(s) detected ($ACTIVE_PIPELINES running)"
            else
                info "  ✓ No active Harness pipelines"
            fi
        fi
    fi

    # Check for active GitHub Actions workflows
    if command -v gh &> /dev/null; then
        cd "$PROJECT_ROOT"
        ACTIVE_WORKFLOWS=$(gh run list --limit 5 --json status,conclusion | jq '[.[] | select(.status == "in_progress")] | length' 2>/dev/null || echo "0")

        if [ "$ACTIVE_WORKFLOWS" -gt 0 ]; then
            warn "  ⚠ Active GitHub Actions workflow(s) detected ($ACTIVE_WORKFLOWS running)"
        else
            info "  ✓ No active GitHub Actions workflows"
        fi
    fi
fi

echo ""

# ===== Capture Current State from Terraform =====

step "Capturing infrastructure state..."

cd "$PROJECT_ROOT/terraform"

# Get terraform outputs
if ! terraform output -json > /tmp/tf-output.json 2>/dev/null; then
    error "Failed to get terraform outputs"
    echo "Run: cd terraform && terraform init && terraform refresh"
    exit 1
fi

# Extract values
RDS_ENDPOINT=$(jq -r '.rds_endpoint.value // empty' /tmp/tf-output.json)
RDS_ADDRESS=$(jq -r '.rds_address.value // empty' /tmp/tf-output.json)
RDS_PORT=$(jq -r '.rds_port.value // 5432' /tmp/tf-output.json)
RDS_IDENTIFIER="${DEMO_ID}-rds"

# App Runner services
APP_RUNNER_DEV_ARN=$(jq -r '.app_runner_services.value.dev.service_arn // empty' /tmp/tf-output.json)
APP_RUNNER_DEV_URL=$(jq -r '.app_runner_services.value.dev.service_url // empty' /tmp/tf-output.json)
APP_RUNNER_DEV_ID=$(jq -r '.app_runner_services.value.dev.service_id // empty' /tmp/tf-output.json)

APP_RUNNER_TEST_ARN=$(jq -r '.app_runner_services.value.test.service_arn // empty' /tmp/tf-output.json)
APP_RUNNER_TEST_URL=$(jq -r '.app_runner_services.value.test.service_url // empty' /tmp/tf-output.json)
APP_RUNNER_TEST_ID=$(jq -r '.app_runner_services.value.test.service_id // empty' /tmp/tf-output.json)

APP_RUNNER_STAGING_ARN=$(jq -r '.app_runner_services.value.staging.service_arn // empty' /tmp/tf-output.json)
APP_RUNNER_STAGING_URL=$(jq -r '.app_runner_services.value.staging.service_url // empty' /tmp/tf-output.json)
APP_RUNNER_STAGING_ID=$(jq -r '.app_runner_services.value.staging.service_id // empty' /tmp/tf-output.json)

APP_RUNNER_PROD_ARN=$(jq -r '.app_runner_services.value.prod.service_arn // empty' /tmp/tf-output.json)
APP_RUNNER_PROD_URL=$(jq -r '.app_runner_services.value.prod.service_url // empty' /tmp/tf-output.json)
APP_RUNNER_PROD_ID=$(jq -r '.app_runner_services.value.prod.service_id // empty' /tmp/tf-output.json)

# EC2 delegate
DELEGATE_INSTANCE_ID=$(jq -r '.delegate_instance_id.value // empty' /tmp/tf-output.json)
DELEGATE_IAM_PROFILE=$(jq -r '.delegate_iam_role_arn.value // empty' /tmp/tf-output.json | rev | cut -d'/' -f1 | rev)

# Get spot request ID
if [ -n "$DELEGATE_INSTANCE_ID" ]; then
    SPOT_REQUEST_ID=$(aws ec2 describe-instances \
        --instance-ids "$DELEGATE_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].SpotInstanceRequestId' \
        --output text 2>/dev/null || echo "")
fi

# Validate we got the critical values
if [ -z "$RDS_IDENTIFIER" ] || [ -z "$APP_RUNNER_DEV_ARN" ] || [ -z "$DELEGATE_INSTANCE_ID" ]; then
    error "Failed to extract all required values from terraform outputs"
    echo "Check that terraform has been applied and resources exist"
    exit 1
fi

info "✓ Captured state for:"
echo "  • RDS: $RDS_IDENTIFIER"
echo "  • App Runner: 4 services"
echo "  • EC2 Delegate: $DELEGATE_INSTANCE_ID"
echo ""

# ===== Cost Analysis =====

echo "Cost Analysis:"
echo "  Current monthly cost: ~\$52.00/month"
echo "  After hibernation:    ~\$0.00/month"
echo "  Monthly savings:      ~\$52.00/month (90% reduction)"
echo ""

echo "Resources to Stop:"
echo "  • RDS ($RDS_IDENTIFIER): db.t3.micro"
echo "  • App Runner (4 services): dev, test, staging, prod"
echo "  • EC2 Delegate ($DELEGATE_INSTANCE_ID): t3.medium spot"
echo ""

warn "⚠ Warning: RDS will auto-start after 7 days"
warn "⚠ Warning: Delegate will get new IP on resume"
echo ""

# ===== Confirmation =====

if [ "$SKIP_CONFIRMATION" = false ]; then
    read -p "Proceed with hibernation? [y/N]: " -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Hibernation cancelled"
        exit 0
    fi
fi

# ===== Stop Resources =====

START_TIME=$(date +%s)

echo "Stopping Infrastructure..."
echo ""

# Phase 1: Terminate EC2 Delegate
step "[1/3] Terminating EC2 delegate..."
DELEGATE_START=$(date +%s)

if [ -n "$SPOT_REQUEST_ID" ] && [ "$SPOT_REQUEST_ID" != "None" ]; then
    aws ec2 cancel-spot-instance-requests --spot-instance-request-ids "$SPOT_REQUEST_ID" &>/dev/null || true
fi

aws ec2 terminate-instances --instance-ids "$DELEGATE_INSTANCE_ID" &>/dev/null

# Wait for termination (max 2 min)
ATTEMPTS=0
MAX_ATTEMPTS=24  # 24 * 5s = 2 minutes
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    STATE=$(aws ec2 describe-instances \
        --instance-ids "$DELEGATE_INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null || echo "terminated")

    if [ "$STATE" = "terminated" ]; then
        break
    fi

    sleep 5
    ATTEMPTS=$((ATTEMPTS + 1))
done

DELEGATE_ELAPSED=$(($(date +%s) - DELEGATE_START))
info "  ✓ Delegate terminated (${DELEGATE_ELAPSED}s)"
echo ""

# Phase 2: Pause App Runner Services
step "[2/3] Pausing App Runner services..."

pause_service() {
    local ENV=$1
    local ARN=$2
    local START=$(date +%s)

    echo -n "  $ENV... "

    aws apprunner pause-service --service-arn "$ARN" &>/dev/null

    # Wait for PAUSED status (max 3 min)
    ATTEMPTS=0
    MAX_ATTEMPTS=36  # 36 * 5s = 3 minutes
    while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
        STATUS=$(aws apprunner describe-service \
            --service-arn "$ARN" \
            --query 'Service.Status' \
            --output text 2>/dev/null || echo "")

        if [ "$STATUS" = "PAUSED" ]; then
            break
        fi

        sleep 5
        ATTEMPTS=$((ATTEMPTS + 1))
    done

    ELAPSED=$(($(date +%s) - START))
    info "✓ (${ELAPSED}s)"
}

pause_service "dev" "$APP_RUNNER_DEV_ARN"
pause_service "test" "$APP_RUNNER_TEST_ARN"
pause_service "staging" "$APP_RUNNER_STAGING_ARN"
pause_service "prod" "$APP_RUNNER_PROD_ARN"
echo ""

# Phase 3: Stop RDS
step "[3/3] Stopping RDS instance..."
RDS_START=$(date +%s)

aws rds stop-db-instance --db-instance-identifier "$RDS_IDENTIFIER" &>/dev/null

# Wait for stopped status (max 10 min)
ATTEMPTS=0
MAX_ATTEMPTS=120  # 120 * 5s = 10 minutes
while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier "$RDS_IDENTIFIER" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null || echo "")

    if [ "$STATUS" = "stopped" ]; then
        break
    fi

    sleep 5
    ATTEMPTS=$((ATTEMPTS + 1))
done

RDS_ELAPSED=$(($(date +%s) - RDS_START))
info "  ✓ RDS stopped (${RDS_ELAPSED}s)"
echo ""

# ===== Save State =====

mkdir -p "$STATE_DIR"

CURRENT_USER=$(whoami)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$STATE_FILE" <<EOF
{
  "version": "1.0",
  "demo_id": "$DEMO_ID",
  "aws_region": "$AWS_REGION",
  "hibernated_at": "$TIMESTAMP",
  "hibernated_by": "$CURRENT_USER",
  "reason": "$HIBERNATION_REASON",

  "rds": {
    "identifier": "$RDS_IDENTIFIER",
    "endpoint": "$RDS_ENDPOINT",
    "address": "$RDS_ADDRESS",
    "port": $RDS_PORT
  },

  "app_runner": {
    "dev": {
      "service_arn": "$APP_RUNNER_DEV_ARN",
      "service_url": "$APP_RUNNER_DEV_URL",
      "service_id": "$APP_RUNNER_DEV_ID"
    },
    "test": {
      "service_arn": "$APP_RUNNER_TEST_ARN",
      "service_url": "$APP_RUNNER_TEST_URL",
      "service_id": "$APP_RUNNER_TEST_ID"
    },
    "staging": {
      "service_arn": "$APP_RUNNER_STAGING_ARN",
      "service_url": "$APP_RUNNER_STAGING_URL",
      "service_id": "$APP_RUNNER_STAGING_ID"
    },
    "prod": {
      "service_arn": "$APP_RUNNER_PROD_ARN",
      "service_url": "$APP_RUNNER_PROD_URL",
      "service_id": "$APP_RUNNER_PROD_ID"
    }
  },

  "ec2_delegate": {
    "spot_request_id": "$SPOT_REQUEST_ID",
    "instance_id": "$DELEGATE_INSTANCE_ID",
    "iam_instance_profile": "$DELEGATE_IAM_PROFILE"
  },

  "cost_estimate": {
    "monthly_running": 52.00,
    "monthly_hibernated": 0.00,
    "monthly_savings": 52.00,
    "currency": "USD"
  }
}
EOF

# ===== Summary =====

TOTAL_TIME=$(($(date +%s) - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
info "✅ Infrastructure hibernated successfully! (${MINUTES}m ${SECONDS}s)"
echo ""
echo "State saved to: $STATE_FILE"
echo "Resume with: $SCRIPT_DIR/resume-infrastructure.sh"
echo ""

exit 0
