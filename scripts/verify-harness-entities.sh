#!/bin/bash
# Harness Entity Verification Script
# Verifies all entities needed for Deploy_Bagel_Store pipeline

# Load API key
if [ -f "harness/.env" ]; then
  source harness/.env
elif [ -f "../harness/.env" ]; then
  source ../harness/.env
else
  echo "Error: harness/.env not found"
  echo "Please ensure you're running this from the repository root"
  exit 1
fi

if [ -z "$HARNESS_API_KEY" ]; then
  echo "Error: HARNESS_API_KEY not found in harness/.env"
  echo "Please set HARNESS_API_KEY in harness/.env"
  exit 1
fi

# Constants
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
ORG_ID="default"
PROJECT_ID="bagel_store_demo"

echo "========================================="
echo "Harness Entity Verification"
echo "========================================="
echo "Account: $ACCOUNT_ID"
echo "Organization: $ORG_ID"
echo "Project: $PROJECT_ID"
echo ""

# Function to check entity count
check_entity() {
  local entity_name=$1
  local endpoint=$2
  local jq_filter=$3

  echo "Checking ${entity_name}..."
  local result=$(curl -s ${endpoint} -H "x-api-key: ${HARNESS_API_KEY}")
  local count=$(echo "$result" | jq "${jq_filter}" 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$count" ]; then
    echo "  ⚠️  API Error or no entities found"
    echo "$result" | jq '.' 2>/dev/null || echo "$result"
  else
    echo "  ✅ Found: ${count} ${entity_name}"
  fi
  echo ""
}

# 1. Environments
echo "========================================="
echo "1. ENVIRONMENTS"
echo "========================================="
check_entity "Environments" \
  "https://app.harness.io/ng/api/environmentsV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  '.data.content | length'

echo "Environment Details:"
curl -s \
  "https://app.harness.io/ng/api/environmentsV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.content[] | "  - \(.environment.name) (\(.environment.identifier)) - \(.environment.type)"' 2>/dev/null || echo "  Error retrieving environment details"
echo ""

# 2. Infrastructure Definitions (check each environment)
echo "========================================="
echo "2. INFRASTRUCTURE DEFINITIONS"
echo "========================================="
for env in psr_dev psr_test psr_staging psr_prod; do
  echo "Environment: $env"
  result=$(curl -s \
    "https://app.harness.io/gateway/ng/api/infrastructures?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&environmentIdentifier=${env}" \
    -H "x-api-key: ${HARNESS_API_KEY}")

  count=$(echo "$result" | jq '.data.content | length' 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$count" ]; then
    echo "  ⚠️  API Error or no infrastructure definitions"
    echo "$result" | jq -r '.message // .status' 2>/dev/null || echo "  Error retrieving data"
  elif [ "$count" -eq 0 ]; then
    echo "  ❌ No infrastructure definitions found"
  else
    echo "  ✅ Found: ${count} infrastructure(s)"
    echo "$result" | jq -r '.data.content[] | "    - \(.infrastructure.name) (\(.infrastructure.identifier))"' 2>/dev/null
  fi
  echo ""
done

# 3. Services
echo "========================================="
echo "3. SERVICES"
echo "========================================="
check_entity "Services" \
  "https://app.harness.io/ng/api/servicesV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  '.data.content | length'

echo "Service Details:"
curl -s \
  "https://app.harness.io/ng/api/servicesV2?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.content[] | "  - \(.service.name) (\(.service.identifier))"' 2>/dev/null || echo "  Error retrieving service details"
echo ""

# 4. Templates
echo "========================================="
echo "4. TEMPLATES"
echo "========================================="
# IMPORTANT: Templates API requires /gateway prefix and templateListType=All parameter
result=$(curl -s -X POST \
  "https://app.harness.io/gateway/template/api/templates/list?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&page=0&size=100&templateListType=All" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"Template"}')

count=$(echo "$result" | jq '.data.content | length' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$count" ]; then
  echo "  ⚠️  API Error"
  echo "$result" | jq '.' 2>/dev/null || echo "$result"
else
  echo "  ✅ Found: ${count} templates"
  echo ""
  echo "Template Details:"
  echo "$result" | jq -r '.data.content[] | "  - \(.name) (\(.identifier)) - \(.templateEntityType) v\(.versionLabel)"' 2>/dev/null
fi
echo ""

# 5. Pipelines
echo "========================================="
echo "5. PIPELINES"
echo "========================================="
# IMPORTANT: Pipelines API requires POST method, not GET
result=$(curl -s -X POST \
  "https://app.harness.io/pipeline/api/pipelines/list?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&page=0&size=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineSetup"}')

count=$(echo "$result" | jq '.data.content | length' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$count" ]; then
  echo "  ⚠️  API Error"
  echo "$result" | jq '.' 2>/dev/null || echo "$result"
else
  echo "  ✅ Found: ${count} pipelines"
  echo ""
  echo "Pipeline Details:"
  echo "$result" | jq -r '.data.content[] | "  - \(.name) (\(.identifier)) - \(.storeType)"' 2>/dev/null
fi
echo ""

# 6. Connectors
echo "========================================="
echo "6. CONNECTORS"
echo "========================================="
check_entity "Connectors" \
  "https://app.harness.io/ng/api/connectors?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  '.data.content | length'

echo "Connector Details:"
curl -s \
  "https://app.harness.io/ng/api/connectors?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.content[] | "  - \(.connector.name) (\(.connector.identifier)) - \(.connector.type)"' 2>/dev/null || echo "  Error retrieving connector details"
echo ""

# 7. Secrets
echo "========================================="
echo "7. SECRETS"
echo "========================================="
check_entity "Secrets" \
  "https://app.harness.io/ng/api/v2/secrets?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  '.data.content | length'

echo "Secret Details:"
curl -s \
  "https://app.harness.io/ng/api/v2/secrets?accountIdentifier=${ACCOUNT_ID}&orgIdentifier=${ORG_ID}&projectIdentifier=${PROJECT_ID}&pageSize=100" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.content[] | "  - \(.secret.name) (\(.secret.identifier)) - \(.secret.type)"' 2>/dev/null || echo "  Error retrieving secret details"
echo ""

echo "========================================="
echo "VERIFICATION COMPLETE"
echo "========================================="
echo ""
echo "Expected entities for Deploy_Bagel_Store pipeline:"
echo ""
echo "✓ Environments: psr_dev, psr_test, psr_staging, psr_prod"
echo "✓ Infrastructure Definitions: psr_dev_infra, psr_test_infra, psr_staging_infra, psr_prod_infra"
echo "✓ Service: bagel_store"
echo "✓ Templates: Coordinated_DB_App_Deployment (StepGroup)"
echo "✓ Connectors: github_bagel_store, aws_* (for deployments)"
echo "✓ Secrets: github_pat, aws_access_key_id, aws_secret_access_key, liquibase_license_key"
echo ""
echo "Review the output above to identify any missing entities."
echo "========================================="
