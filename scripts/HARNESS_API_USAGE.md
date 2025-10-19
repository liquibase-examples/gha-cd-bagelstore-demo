# Harness API Wrapper - Usage Guide

## Overview

`scripts/harness-api.sh` is a wrapper script that automatically loads `HARNESS_API_KEY` from `harness/.env` and makes authenticated API calls to Harness.

**Key Features:**
- ✅ Automatic API key loading from `harness/.env`
- ✅ API key validation (checks format, ensures not empty)
- ✅ HTTP status code checking with error messages
- ✅ Built-in jq filtering support
- ✅ Colored output for better readability
- ✅ Works from any directory (finds harness/.env automatically)

## Basic Usage

```bash
./scripts/harness-api.sh <METHOD> <ENDPOINT> [JQ_FILTER]
```

### Arguments

1. **METHOD**: `GET` or `POST`
2. **ENDPOINT**: API endpoint (with or without `https://app.harness.io` prefix)
3. **JQ_FILTER** (optional): jq filter to apply to response (default: `.`)

## Examples

### Example 1: Get Execution Status (Simple)

```bash
./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/LpMDt6PiSEWxlvrf0A4MhA?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  ".data.pipelineExecutionSummary.status"
```

**Output:**
```
Aborted
```

### Example 2: Get Multiple Fields (Complex jq Filter)

```bash
./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/LpMDt6PiSEWxlvrf0A4MhA?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  ".data.pipelineExecutionSummary | {status, runSequence, duration: ((.endTs - .startTs)/1000)}"
```

**Output:**
```json
{
  "status": "Aborted",
  "runSequence": 15,
  "duration": 639.978
}
```

### Example 3: Get Full JSON Response

```bash
./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/LpMDt6PiSEWxlvrf0A4MhA?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo"
```

**Output:** Full JSON response, pretty-printed

### Example 4: List Pipeline Executions

```bash
# Get last 5 executions with status and trigger info
./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/summary?routingId=_dYBmxlLQu61cFhvdkV4Jw&accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&size=5" \
  '.data.content[] | {runSequence, status: .status, trigger: .executionTriggerInfo.triggerType}'
```

### Example 5: Trigger Webhook (POST Request)

```bash
./scripts/harness-api.sh POST \
  "https://app.harness.io/gateway/pipeline/api/webhook/custom/lacCjzQLTeOL0QA0CBsGOA/v3?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&triggerIdentifier=GitHub_Actions_CI" \
  '{"version": "dev-3142ffc", "github_org": "liquibase-examples", "deployment_target": "aws", "branch": "main"}' \
  ".data.eventCorrelationId"
```

**Output:**
```
68f4624eb8288970d2c9c683
```

### Example 6: Get Trigger Configuration

```bash
./scripts/harness-api.sh GET \
  "/pipeline/api/triggers/GitHub_Actions_CI?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&targetIdentifier=Deploy_Bagel_Store" \
  '.data | {name, identifier, type, enabled}'
```

### Example 7: Check Template Exists

```bash
./scripts/harness-api.sh GET \
  "/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=1.0" \
  '.data.template | {name, versionLabel, storeType}'
```

### Example 8: Get Environment Variables

```bash
./scripts/harness-api.sh GET \
  "/ng/api/environmentsV2/psr_dev?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  '.data.environment.variables[] | select(.name == "secrets_username_arn") | {name, value}'
```

## Common Patterns

### Pattern 1: Check Latest Execution Status

```bash
# Get status of most recent execution
LATEST_EXEC_ID=$(./scripts/get-pipeline-executions.sh 1 | grep -A 1 "RECENT EXECUTIONS" | tail -1 | awk '{print $NF}')

./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/${LATEST_EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  ".data.pipelineExecutionSummary.status"
```

### Pattern 2: Monitor Execution Until Complete

```bash
EXEC_ID="LpMDt6PiSEWxlvrf0A4MhA"

while true; do
  STATUS=$(./scripts/harness-api.sh GET \
    "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
    ".data.pipelineExecutionSummary.status")
  
  echo "Status: $STATUS"
  
  if [[ "$STATUS" == "Success" ]] || [[ "$STATUS" == "Failed" ]] || [[ "$STATUS" == "Aborted" ]]; then
    break
  fi
  
  sleep 10
done
```

### Pattern 3: Extract Specific Error Messages

```bash
./scripts/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  '.data.executionGraph.nodeMap | to_entries[] | select(.value.status == "Failed") | {name: .value.name, error: .value.failureInfo.message}'
```

## Error Handling

The wrapper script automatically handles:

1. **Missing API Key**: Exits with error if `HARNESS_API_KEY` not found in `harness/.env`
2. **Invalid API Key Format**: Validates key starts with `pat.`
3. **HTTP Errors**: Shows HTTP status code and error message from API response
4. **Missing .env File**: Searches multiple locations and provides helpful error

## Integration with Existing Scripts

The wrapper script is designed to complement existing scripts:

```bash
# Use existing scripts for common operations
./scripts/get-pipeline-executions.sh 5       # List executions
./scripts/get-execution-details.sh <exec_id>  # Get details
./scripts/get-execution-logs.sh <exec_id>    # Get logs

# Use harness-api.sh for ad-hoc API calls
./scripts/harness-api.sh GET <endpoint> [filter]
```

## Troubleshooting

### Issue: "Cannot find harness/.env file"

**Solution**: Run from project root directory or ensure `harness/.env` exists

```bash
cd /Users/recampbell/workspace/harness-gha-bagelstore
./scripts/harness-api.sh GET <endpoint>
```

### Issue: "HARNESS_API_KEY not found in harness/.env"

**Solution**: Verify `harness/.env` contains `HARNESS_API_KEY` variable

```bash
grep HARNESS_API_KEY harness/.env
```

### Issue: "HARNESS_API_KEY has invalid format"

**Solution**: API key should start with `pat.` - regenerate in Harness UI if needed

## API Endpoint Reference

Common Harness API endpoints:

- **Executions**: `/pipeline/api/pipelines/execution/v2/<exec_id>`
- **Pipeline List**: `/pipeline/api/pipelines/list`
- **Trigger**: `/pipeline/api/triggers/<trigger_id>`
- **Template**: `/template/api/templates/<template_id>`
- **Environment**: `/ng/api/environmentsV2/<env_id>`
- **Service**: `/ng/api/servicesV2/<service_id>`

Full API documentation: https://apidocs.harness.io/

## When to Use This Wrapper

**✅ Use `harness-api.sh` when:**
- Making ad-hoc API calls
- Testing new API endpoints
- Debugging API responses
- Need custom jq filtering
- Exploring API behavior

**❌ Don't use when:**
- Existing script already exists (`get-pipeline-executions.sh`, etc.)
- Need complex multi-step logic (write a dedicated script instead)

## Contributing

When adding new Harness API functionality:

1. Check if wrapper can handle it (usually yes)
2. Add example to this document
3. If complex, create dedicated script that uses wrapper internally
