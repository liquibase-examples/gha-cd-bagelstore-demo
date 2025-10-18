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

## Reference

**API Documentation:** https://apidocs.harness.io/

**Harness Account:**
- URL: https://app.harness.io/
- Account ID: `_dYBmxlLQu61cFhvdkV4Jw`
- Organization: `default`
- Project: `bagel_store_demo`
