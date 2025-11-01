#!/bin/bash
# Test deployment scripts on EC2 delegate via SSM Session Manager
#
# Usage: ./test-scripts-on-ec2.sh <script-name> [environment] [version]
#
# This script executes deployment scripts directly on the EC2 delegate
# where IAM instance profile provides credentials automatically.
#
# Examples:
#   ./test-scripts-on-ec2.sh update-database dev
#   ./test-scripts-on-ec2.sh deploy-application dev v1.0.0
#   ./test-scripts-on-ec2.sh health-check dev v1.0.0

set -e

SCRIPT_NAME="${1:-update-database}"
ENVIRONMENT="${2:-dev}"
VERSION="${3:-v1.0.0}"

echo "=== Testing Deployment Scripts on EC2 Delegate ==="
echo ""

# Change to terraform directory
cd "$(dirname "$0")/../../terraform"

# Get EC2 instance details
echo "Fetching EC2 instance details from Terraform..."
INSTANCE_ID=$(terraform output -raw delegate_instance_id 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$INSTANCE_ID" ]; then
  echo "❌ Failed to get delegate_instance_id from Terraform"
  echo "   Run: cd terraform && terraform apply"
  exit 1
fi

DEMO_ID=$(terraform output -json deployment_summary | jq -r '.demo_id')
AWS_REGION=$(terraform output -json deployment_summary | jq -r '.aws_region')

echo "Instance ID: $INSTANCE_ID"
echo "Demo ID: $DEMO_ID"
echo "Script: $SCRIPT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Version: $VERSION"
echo ""

# Verify instance is running
echo "Checking EC2 instance status..."
INSTANCE_STATE=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Reservations[0].Instances[0].State.Name' \
  --output text)

if [ "$INSTANCE_STATE" != "running" ]; then
  echo "❌ EC2 instance is not running (state: $INSTANCE_STATE)"
  echo "   Start instance: cd terraform && terraform apply"
  exit 1
fi
echo "✅ Instance is running"
echo ""

# Build AWS parameters JSON
echo "Building AWS parameters from Terraform outputs..."
AWS_PARAMS=$(terraform output -json | jq --arg env "$ENVIRONMENT" '{
  "jdbc_url": .jdbc_urls.value[$env],
  "aws_region": .deployment_summary.value.aws_region,
  "liquibase_flows_bucket": .liquibase_flows_bucket.value,
  "rds_endpoint": .rds_endpoint.value,
  "app_runner_service_arn": .app_runner_services.value[$env].service_arn,
  "demo_id": .deployment_summary.value.demo_id,
  "rds_address": .rds_address.value,
  "rds_port": .rds_port.value,
  "database_name": $env,
  "secrets_username_arn": .secrets_rds_username_arn.value,
  "secrets_password_arn": .secrets_rds_password_arn.value
}' | jq -c .)

# Get secrets (NO AWS credentials - only Liquibase license key!)
echo "Reading secrets from terraform.tfvars..."
LIQUIBASE_LICENSE_KEY=$(grep "^liquibase_license_key" terraform.tfvars | cut -d'"' -f2)
if [ -z "$LIQUIBASE_LICENSE_KEY" ]; then
  echo "❌ Failed to read liquibase_license_key from terraform.tfvars"
  exit 1
fi

# Build secrets JSON (minimal - NO AWS credentials!)
SECRETS=$(jq -n --arg key "$LIQUIBASE_LICENSE_KEY" '{
  "liquibase_license_key": $key
}' | jq -c .)

echo "✅ Parameters built successfully"
echo ""

# Escape JSON for shell command (replace single quotes with '\'' pattern)
AWS_PARAMS_ESCAPED=$(echo "$AWS_PARAMS" | sed "s/'/'\\\\''/g")
SECRETS_ESCAPED=$(echo "$SECRETS" | sed "s/'/'\\\\''/g")

# Build test command based on script name
case "$SCRIPT_NAME" in
  update-database)
    echo "Testing: update-database.sh"
    TEST_COMMAND="docker exec harness-delegate-${DEMO_ID} bash -c '/opt/harness-delegate/scripts/update-database.sh \"${ENVIRONMENT}\" \"${DEMO_ID}\" \"aws\" '\''${AWS_PARAMS_ESCAPED}'\'' '\''${SECRETS_ESCAPED}'\'''"
    ;;

  deploy-application)
    echo "Testing: deploy-application.sh (version: $VERSION)"
    # Deploy app doesn't need secrets (uses IAM instance profile for AWS)
    EMPTY_SECRETS='{}'
    TEST_COMMAND="docker exec harness-delegate-${DEMO_ID} bash -c '/opt/harness-delegate/scripts/deploy-application.sh \"${ENVIRONMENT}\" \"${VERSION}\" \"liquibase-examples\" \"aws\" '\''${AWS_PARAMS_ESCAPED}'\'' '\''${EMPTY_SECRETS}'\'''"
    ;;

  health-check)
    echo "Testing: health-check.sh"
    SERVICE_URL=$(terraform output -json | jq -r --arg env "$ENVIRONMENT" '.app_runner_services.value[$env].service_url')
    TEST_COMMAND="docker exec harness-delegate-${DEMO_ID} bash -c '/opt/harness-delegate/scripts/health-check.sh \"${ENVIRONMENT}\" \"${VERSION}\" \"aws\" \"${SERVICE_URL}\"'"
    ;;

  fetch-instances)
    echo "Testing: fetch-instances.sh"
    SERVICE_URL=$(terraform output -json | jq -r --arg env "$ENVIRONMENT" '.app_runner_services.value[$env].service_url')
    SERVICE_NAME="bagel-store-${DEMO_ID}-${ENVIRONMENT}"
    TEST_COMMAND="docker exec harness-delegate-${DEMO_ID} bash -c '/opt/harness-delegate/scripts/fetch-instances.sh \"${ENVIRONMENT}\" \"aws\" \"${SERVICE_NAME}\" \"${SERVICE_URL}\"'"
    ;;

  *)
    echo "❌ Unknown script: $SCRIPT_NAME"
    echo ""
    echo "Available scripts:"
    echo "  - update-database"
    echo "  - deploy-application"
    echo "  - health-check"
    echo "  - fetch-instances"
    exit 1
    ;;
esac

# Return to repo root
cd ..

# Execute via SSM
echo "Executing script on EC2 via SSM..."
echo ""
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=['$TEST_COMMAND']" \
  --region "$AWS_REGION" \
  --query 'Command.CommandId' \
  --output text)

echo "Command ID: $COMMAND_ID"
echo "Waiting for execution to complete..."

# Poll for command completion
MAX_WAIT=60  # seconds
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
  STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'Status' \
    --output text 2>/dev/null || echo "Pending")

  if [ "$STATUS" = "Success" ] || [ "$STATUS" = "Failed" ]; then
    break
  fi

  sleep 2
  WAITED=$((WAITED + 2))
  echo -n "."
done
echo ""
echo ""

# Get command output
echo "=== Command Output ==="
echo ""
aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query '[StandardOutputContent, StandardErrorContent]' \
  --output text

echo ""
echo "=== Execution Summary ==="
FINAL_STATUS=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'Status' \
  --output text)

if [ "$FINAL_STATUS" = "Success" ]; then
  echo "✅ Test completed successfully on EC2"
  echo ""
  echo "Next steps:"
  echo "  1. Review output above for any warnings"
  echo "  2. Test other scripts if needed"
  echo "  3. Commit changes and deploy through Harness"
  exit 0
else
  echo "❌ Test failed with status: $FINAL_STATUS"
  echo ""
  echo "Debugging options:"
  echo "  1. Check delegate logs:"
  echo "     aws ssm start-session --target $INSTANCE_ID"
  echo "     docker logs harness-delegate-${DEMO_ID}"
  echo ""
  echo "  2. Verify IAM instance profile:"
  echo "     aws ssm start-session --target $INSTANCE_ID"
  echo "     docker exec harness-delegate-${DEMO_ID} aws sts get-caller-identity"
  echo ""
  echo "  3. Check script exists:"
  echo "     aws ssm start-session --target $INSTANCE_ID"
  echo "     docker exec harness-delegate-${DEMO_ID} ls -la /opt/harness-delegate/scripts/"
  exit 1
fi
