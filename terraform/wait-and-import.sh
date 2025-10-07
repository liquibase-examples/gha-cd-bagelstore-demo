#!/bin/bash
# Monitor App Runner services and import them once they're ready

set -e

export AWS_PROFILE=liquibase-sandbox-admin

echo "Monitoring App Runner services until they're ready..."
echo "This may take 5-10 minutes..."
echo ""

# Function to check if all services are RUNNING
check_services() {
    local status=$(aws apprunner list-services --region us-east-1 \
        --query 'ServiceSummaryList[?starts_with(ServiceName, `bagel-store-psr`)].Status' \
        --output text)

    # Check if all services are RUNNING
    if echo "$status" | grep -v "RUNNING" > /dev/null; then
        return 1  # Not all ready
    else
        return 0  # All ready
    fi
}

# Wait for services to be ready
attempt=1
max_attempts=60  # 60 attempts * 30 seconds = 30 minutes max

while [ $attempt -le $max_attempts ]; do
    echo "[Attempt $attempt/$max_attempts] Checking service status..."

    aws apprunner list-services --region us-east-1 \
        --query 'ServiceSummaryList[?starts_with(ServiceName, `bagel-store-psr`)].[ServiceName,Status]' \
        --output table

    if check_services; then
        echo ""
        echo "✓ All services are RUNNING!"
        echo ""
        echo "Starting import process..."
        ./import-services.sh
        exit 0
    fi

    echo "Services not ready yet. Waiting 30 seconds..."
    echo ""
    sleep 30
    ((attempt++))
done

echo "❌ Timeout: Services did not reach RUNNING state after 30 minutes"
exit 1
