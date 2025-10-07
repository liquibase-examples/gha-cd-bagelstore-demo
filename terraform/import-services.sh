#!/bin/bash
# Import all 4 App Runner services into Terraform state
# Workaround: Temporarily disable dashboard.tf to avoid evaluation errors

set -e

echo "Step 1: Temporarily disabling dashboard.tf to avoid evaluation errors..."
if [ -f "dashboard.tf" ]; then
    mv dashboard.tf dashboard.tf.disabled
    echo "✓ dashboard.tf disabled"
fi

echo ""
echo "Step 2: Importing App Runner services..."

terraform import 'aws_apprunner_service.bagel_store["dev"]' \
  'arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-dev/d7e9038e044947559883cf72ac0ac5e1'

terraform import 'aws_apprunner_service.bagel_store["test"]' \
  'arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-test/dbfd6475fe3f41309196c944ea0351aa'

terraform import 'aws_apprunner_service.bagel_store["staging"]' \
  'arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-staging/edad4a083fe046a6bdf50aaae00876d4'

terraform import 'aws_apprunner_service.bagel_store["prod"]' \
  'arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-prod/334e29a6fff5436eacc83234fa626194'

echo ""
echo "Step 3: Re-enabling dashboard.tf..."
if [ -f "dashboard.tf.disabled" ]; then
    mv dashboard.tf.disabled dashboard.tf
    echo "✓ dashboard.tf enabled"
fi

echo ""
echo "Step 4: Verifying imports..."
terraform state list | grep apprunner_service

echo ""
echo "Step 5: Running terraform apply to generate dashboard..."
terraform apply -auto-approve

echo ""
echo "✓ Done! Dashboard should be generated at ../demo-dashboard.html"
