# Harness API Workflows & Diagnostics

Complete API reference for monitoring, debugging, and managing Harness CD pipelines.

## Prerequisites

All API calls require authentication. Load API key from `harness/.env`:

```bash
source harness/.env
# Or extract directly:
HARNESS_API_KEY=$(grep '^HARNESS_API_KEY=' harness/.env | cut -d'=' -f2)
```

**Account Details:**
- Account ID: `_dYBmxlLQu61cFhvdkV4Jw`
- Organization: `default`
- Project: `bagel_store_demo`

## Pipeline Execution Monitoring

### Get Latest Pipeline Execution

```bash
curl -s -X POST \
  "https://app.harness.io/pipeline/api/pipelines/execution/summary?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"pipelineIdentifier":"Deploy_Bagel_Store","filterType":"PipelineExecution"}' | \
  jq '.data.content[0] | {planExecutionId, status, startTs, createdAt}'
```

**Output:**
```json
{
  "planExecutionId": "abc123...",
  "status": "Running",
  "startTs": 1760820344676,
  "createdAt": 1760820345549
}
```

### Get Full Execution Details

```bash
EXECUTION_ID="..."  # From above

curl -s \
  "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap'
```

### Find All Steps with Status

```bash
# Show all steps with their status
jq '.data.executionGraph.nodeMap | to_entries[] |
    {stepName: .value.name, status: .value.status, stepType: .value.stepType}' | \
    jq -s 'sort_by(.stepName)'
```

### Find Failed or Aborted Steps

```bash
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap | to_entries[] |
      select(.value.status == "Failed" or .value.status == "Aborted") |
      {stepName: .value.name, stepType: .value.stepType, error: .value.failureInfo.message}'
```

### Check Infrastructure Step Specifically

```bash
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap | to_entries[] |
      select(.value.stepType == "INFRASTRUCTURE_TASKSTEP_V2") |
      {status: .value.status, failureInfo: .value.failureInfo}'
```

**Common Issue:** `INVALID_REQUEST` at Infrastructure step
- **Cause:** Missing or invalid `customDeploymentRef.templateRef`
- **Solution:** See [HARNESS_CUSTOMDEPLOYMENT_GUIDE.md](HARNESS_CUSTOMDEPLOYMENT_GUIDE.md)

## Infrastructure Definition Management

### Get Infrastructure Definition

```bash
curl -s \
  "https://app.harness.io/gateway/ng/api/infrastructures/psr_dev_infra?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=psr_dev" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.infrastructure.yaml'
```

### Verify Template Reference

```bash
curl -s \
  "https://app.harness.io/gateway/ng/api/infrastructures/psr_dev_infra?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.infrastructure.yaml' | grep -A 2 "customDeploymentRef"
```

**Expected output:**
```yaml
customDeploymentRef:
  templateRef: Custom
  versionLabel: "1.0"
```

### List All Infrastructure Definitions in Environment

```bash
curl -s \
  "https://app.harness.io/gateway/ng/api/infrastructures?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=psr_dev" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.content[] | {name: .infrastructure.name, identifier: .infrastructure.identifier}'
```

## Triggering Pipelines

### Via GitHub Actions (Recommended)

```bash
# Retrigger last workflow run
gh run rerun $(gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')

# Watch progress
gh run watch {RUN_ID} --exit-status

# View logs
gh run view {RUN_ID} --log
```

### Via Direct Webhook

```bash
curl -X POST \
  "https://app.harness.io/gateway/pipeline/api/webhook/custom/lacCjzQLTeOL0QA0CBsGOA/v3?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&triggerIdentifier=GitHub_Actions_CI" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "dev-cd6477b",
    "github_org": "liquibase-examples",
    "deployment_target": "aws",
    "branch": "main",
    "commit_sha": "cd6477b209200fa28581c3577bce36a78c1b79e3",
    "triggered_by": "manual-test"
  }'
```

## Common Pipeline Errors

### Error: "Invalid request: INVALID_REQUEST" (Infrastructure Step)

**Diagnosis:**
```bash
# Check infrastructure definition templateRef
curl -s "https://app.harness.io/gateway/ng/api/infrastructures/psr_dev_infra?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.infrastructure.yaml' | grep templateRef
```

**Causes:**
- Empty `templateRef: ""`
- Non-existent template reference
- Missing CustomDeployment template

**Solution:** See [HARNESS_CUSTOMDEPLOYMENT_GUIDE.md](HARNESS_CUSTOMDEPLOYMENT_GUIDE.md)

### Error: "No eligible delegates available"

**Diagnosis:**
```bash
# Check delegate status
cd harness && docker compose ps
```

**Solution:**
```bash
cd harness && docker compose up -d
```

**Verify in Harness UI:**
- Navigate to: Project Settings → Delegates
- Look for: "Connected" status + recent heartbeat (<1 min)

### Error: Trigger stays "QUEUED" forever

**Diagnosis:**
```bash
# Check trigger configuration
curl -s \
  "https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.yaml' | grep -i branch
```

**Common Cause:** Missing "Pipeline Reference Branch" in trigger configuration

**Solution:** See [HARNESS_MANUAL_SETUP.md](HARNESS_MANUAL_SETUP.md) for webhook trigger setup

## Diagnostic Scripts

This repository includes helper scripts in `scripts/`:

```bash
# Verify all Harness entities exist
./scripts/verify-harness-entities.sh

# Get pipeline execution history
./scripts/get-pipeline-executions.sh

# Update trigger configuration
./scripts/update-trigger.sh
```

See [scripts/README.md](../scripts/README.md) for complete documentation.

## Common Query Patterns

### Extract Error Messages from Failed Steps

```bash
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.executionGraph.nodeMap | to_entries[] |
         select(.value.failureInfo.message != "") |
         "\(.value.name): \(.value.failureInfo.message)"'
```

### Get Step Timeline

```bash
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap | to_entries[] |
      {step: .value.name, startTs: .value.startTs, endTs: .value.endTs, duration: (.value.endTs - .value.startTs)}' | \
  jq -s 'sort_by(.startTs)'
```

### Check Service Step (Artifact Resolution)

```bash
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap | to_entries[] |
      select(.value.stepType == "SERVICE_V3") |
      {status: .value.status, outcomes: .value.outcomes}'
```

## Getting Detailed Step Execution Information and Logs

### Method 1: Download Complete Execution Logs (Recommended)

The Harness Log Service API allows downloading all execution logs as a ZIP file.

#### API Endpoint

```
POST https://app.harness.io/gateway/log-service/blob/download
```

#### Prefix Structure

**For full pipeline logs:**
```
{accountID}/pipeline/{pipelineID}/{runSequence}/-{planExecutionId}
```

**For step-level logs:**
```
{accountID}/pipeline/{pipelineID}/{runSequence}/-{planExecutionId}/{stageIdentifier}/{stepGroupIdentifier}/{stepIdentifier}
```

#### Example: Download Full Pipeline Logs

```bash
source harness/.env

EXECUTION_ID="_Ij0EJgRRmWnSPtcJ7oaOQ"
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
PIPELINE_ID="Deploy_Bagel_Store"

# Get runSequence from execution details
RUN_SEQ=$(./scripts/get-execution-details.sh "$EXECUTION_ID" | \
  jq -r '.data.pipelineExecutionSummary.runSequence')

# Construct prefix
PREFIX="${ACCOUNT_ID}/pipeline/${PIPELINE_ID}/${RUN_SEQ}/-${EXEC_ID}"

# Request log download
curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST \
  -H "content-type: application/json" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq '.'
```

**Response:**
```json
{
  "link": "https://app.harness.io/storage/harness-download/prod-log-service/...",
  "status": "success",
  "expires": "2025-10-20T03:40:22.908347682Z"
}
```

#### Download and Extract Logs

```bash
# Get download link
RESPONSE=$(curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST -H "content-type: application/json" -H "x-api-key: ${HARNESS_API_KEY}")

LINK=$(echo "$RESPONSE" | jq -r '.link')

# Download the zip file
curl -L -o execution_logs.zip "$LINK"

# Extract and view structure
unzip -l execution_logs.zip
```

#### Log File Structure

```
_dYBmxlLQu61cFhvdkV4Jw/
└── _dYBmxlLQu61cFhvdkV4Jw/
    └── pipeline/
        └── Deploy_Bagel_Store/
            └── 13/
                └── -_Ij0EJgRRmWnSPtcJ7oaOQ/
                    └── Deploy_to_Dev/
                        ├── infrastructure-commandUnit:Execute
                        ├── service-commandUnit:Service Step
                        └── Coordinated_Deployment/
                            ├── Fetch_Changelog_Artifact-commandUnit:Execute
                            ├── Update_Database-commandUnit:Execute
                            ├── Deploy_Application-commandUnit:Execute
                            └── Health_Check-commandUnit:Execute
```

### Method 2: Download Specific Step Logs

```bash
# Construct prefix for specific step
STEP_PREFIX="${ACCOUNT_ID}/pipeline/${PIPELINE_ID}/${RUN_SEQ}/-${EXEC_ID}/Deploy_to_Dev/Coordinated_Deployment/Update_Database"

# Request step-specific logs
curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${STEP_PREFIX}" \
  -X POST \
  -H "content-type: application/json" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq '.'
```

### Log Format and Parsing

Logs are in JSON Lines format (one JSON object per line):

```json
{"level":"INFO","pos":0,"out":"Executing command ...","time":"2025-10-19T03:25:05.823Z","args":null}
{"level":"ERROR","pos":0,"out":"Error message","time":"2025-10-19T03:25:06.865Z","args":null}
```

#### Parse Step Logs

```bash
# Extract only ERROR level logs
cat step.log | jq -r 'select(.level == "ERROR") | .out'

# Extract all log messages with timestamps
cat step.log | jq -r '"\(.time) [\(.level)] \(.out)"'

# Extract logs from specific time range
cat step.log | jq -r 'select(.time > "2025-10-19T03:25:15Z") | .out'

# Count errors
cat step.log | jq 'select(.level == "ERROR")' | wc -l

# Extract environment info
cat step.log | jq -r 'select(.out | contains("Environment:")) | .out'
```

### Method 3: Get Execution Graph with All Steps

The `/execution/v2` endpoint includes a `layoutNodeMap` with stage-level information. For detailed step-level execution details within stages, use the log download method above.

```bash
EXECUTION_ID="_Ij0EJgRRmWnSPtcJ7oaOQ"

# Get execution with stage-level details
curl -s -X GET \
  "https://app.harness.io/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.pipelineExecutionSummary.layoutNodeMap'
```

#### Extract Stage Information

```bash
# Get all stage statuses with node execution IDs
./scripts/get-execution-details.sh "$EXEC_ID" | \
  jq -r '.data.pipelineExecutionSummary.layoutNodeMap | to_entries[] |
    "\(.value.nodeIdentifier): \(.value.status) (nodeExecutionId: \(.value.nodeExecutionId))"'

# Example output:
# Deploy_to_Dev: Aborted (nodeExecutionId: M-YGc2ZpThSIogjje6bbZA)
# Deploy_to_Test: NotStarted (nodeExecutionId: OskdtYlMSfKN4Qdg-UcWjw)
```

## Complete Debugging Workflow

### Workflow: Debug an Aborted Execution

```bash
#!/bin/bash
source harness/.env

EXEC_ID="_Ij0EJgRRmWnSPtcJ7oaOQ"

echo "=== 1. Get Execution Summary ==="
./scripts/get-execution-details.sh "$EXEC_ID" > /tmp/execution.json

echo ""
echo "=== 2. Check Execution Status ==="
jq -r '.data.pipelineExecutionSummary | {
  status,
  runSequence,
  abortedBy,
  startTs,
  endTs
}' /tmp/execution.json

echo ""
echo "=== 3. Get Stage Statuses ==="
jq -r '.data.pipelineExecutionSummary.layoutNodeMap | to_entries[] |
  "\(.value.name): \(.value.status) (nodeExecutionId: \(.value.nodeExecutionId))"' \
  /tmp/execution.json

echo ""
echo "=== 4. Download Logs ==="
RUN_SEQ=$(jq -r '.data.pipelineExecutionSummary.runSequence' /tmp/execution.json)
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
PIPELINE_ID="Deploy_Bagel_Store"
PREFIX="${ACCOUNT_ID}/pipeline/${PIPELINE_ID}/${RUN_SEQ}/-${EXEC_ID}"

RESPONSE=$(curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST -H "content-type: application/json" -H "x-api-key: ${HARNESS_API_KEY}")

LINK=$(echo "$RESPONSE" | jq -r '.link')
echo "Download link: $LINK"

curl -L -o /tmp/logs.zip "$LINK"
unzip -l /tmp/logs.zip

echo ""
echo "=== 5. Extract Specific Step Logs ==="
unzip -q /tmp/logs.zip -d /tmp/logs
find /tmp/logs -name "*Update_Database*" -type f | while read file; do
  echo "=== File: $file ==="
  cat "$file" | jq -r 'select(.level == "ERROR") | .out' | head -20
done
```

### Workflow: Find Which Step Failed

```bash
#!/bin/bash
source harness/.env

EXEC_ID="<execution_id>"

# 1. Get execution details
echo "Fetching execution details..."
./scripts/get-execution-details.sh "$EXEC_ID" > /tmp/exec.json

# 2. Check overall status
STATUS=$(jq -r '.data.pipelineExecutionSummary.status' /tmp/exec.json)
echo "Pipeline status: $STATUS"

# 3. Find failed/aborted stages
echo ""
echo "Stage statuses:"
jq -r '.data.pipelineExecutionSummary.layoutNodeMap |
  to_entries[] |
  "\(.value.name): \(.value.status)"' /tmp/exec.json

# 4. Download logs for detailed step analysis
RUN_SEQ=$(jq -r '.data.pipelineExecutionSummary.runSequence' /tmp/exec.json)
ACCOUNT_ID="_dYBmxlLQu61cFhvdkV4Jw"
PIPELINE_ID="Deploy_Bagel_Store"
PREFIX="${ACCOUNT_ID}/pipeline/${PIPELINE_ID}/${RUN_SEQ}/-${EXEC_ID}"

echo ""
echo "Downloading logs..."
RESPONSE=$(curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST -H "content-type: application/json" -H "x-api-key: ${HARNESS_API_KEY}")

LINK=$(echo "$RESPONSE" | jq -r '.link')
curl -L -o /tmp/execution_logs.zip "$LINK"

echo ""
echo "Extracting logs..."
unzip -q /tmp/execution_logs.zip -d /tmp/logs

# 5. Search for errors in all step logs
echo ""
echo "Searching for errors across all steps:"
find /tmp/logs -name "*-commandUnit:Execute" -type f | while read file; do
  STEP_NAME=$(basename "$(dirname "$file")")
  ERROR_COUNT=$(cat "$file" | jq -r 'select(.level == "ERROR") | .out' | wc -l | tr -d ' ')
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "=== $STEP_NAME: $ERROR_COUNT errors ==="
    cat "$file" | jq -r 'select(.level == "ERROR") | .out' | head -10
  fi
done
```

## Understanding Execution Identifiers

| Identifier | Description | Example | Where to Find |
|------------|-------------|---------|---------------|
| `planExecutionId` | Unique ID for pipeline execution | `_Ij0EJgRRmWnSPtcJ7oaOQ` | Execution details API |
| `runSequence` | Sequential execution number | `13` | Execution summary `.runSequence` |
| `nodeUuid` | Template/definition ID for stage | `TrRIW5X-SrGVrTvOPtDHHA` | `layoutNodeMap[].nodeUuid` |
| `nodeExecutionId` | Actual execution instance ID | `M-YGc2ZpThSIogjje6bbZA` | `layoutNodeMap[].nodeExecutionId` |
| `nodeIdentifier` | Human-readable stage name | `Deploy_to_Dev` | `layoutNodeMap[].nodeIdentifier` |

## Best Practices

1. **Always read harness/.env first** before using environment variables
   - Pattern: `Read harness/.env` → extract value → use in command
   - Don't rely on `source` and variable expansion

2. **Use API for diagnostics, not UI screenshots**
   - API provides structured data and exact error messages
   - Screenshots are temporary and hard to parse

3. **Check Infrastructure step first** when pipeline fails early
   - Most common failure point for configuration issues
   - Error: `INVALID_REQUEST` usually means template problem

4. **Verify delegate status in UI** not just logs
   - Delegate can show errors in logs while functioning correctly
   - "Connected" status + recent heartbeat = working

5. **Download logs for step-level debugging**
   - Log Service API provides complete execution logs
   - JSON format allows easy parsing and filtering
   - Logs expire after 24 hours

6. **Use `runSequence` for log downloads**
   - Required parameter for log service prefix
   - Available in execution summary response

## Troubleshooting

### Issue: "404 Not Found" on Node Logs Endpoint

**Cause:** The `/pipeline/api/pipelines/execution/v2/{executionId}/node/{nodeId}/logs` endpoint may not be available or has changed.

**Solution:** Use the log-service blob download API instead (documented above).

### Issue: Log Download Returns "queued"

**Cause:** Logs are being prepared asynchronously.

**Solution:** Wait a few seconds and retry:

```bash
sleep 5
curl -s "https://app.harness.io/gateway/log-service/blob/download?accountID=${ACCOUNT_ID}&prefix=${PREFIX}" \
  -X POST -H "content-type: application/json" -H "x-api-key: ${HARNESS_API_KEY}"
```

### Issue: Empty or Null `executionGraph`

**Cause:** The POST endpoint for execution graph may return errors in newer API versions.

**Solution:** Use the GET `/execution/v2` endpoint instead and access `layoutNodeMap` for stage-level information.

### Issue: Cannot Find Step-Level Execution Details

**Cause:** The v2 execution API only provides stage-level information in `layoutNodeMap`.

**Solution:** Download complete logs using the log-service API to get step-level details.

## Reference

**API Documentation:** https://apidocs.harness.io/

**Harness Developer Hub:**
- Execution Graph API: https://developer.harness.io/docs/platform/pipelines/pipeline-execution-graph/
- Download Logs: https://developer.harness.io/docs/platform/pipelines/download-logs/

**Harness Account:**
- URL: https://app.harness.io/
- Account ID: `_dYBmxlLQu61cFhvdkV4Jw`
- Organization: `default`
- Project: `bagel_store_demo`
