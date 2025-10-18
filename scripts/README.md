# Diagnostic and Helper Scripts

This directory contains scripts for diagnosing and managing the Bagel Store demo environment.

## Harness API Scripts

### List Pipeline Executions

```bash
./scripts/get-pipeline-executions.sh [limit]
```

**Purpose:** Get recent pipeline execution history and details for the `Deploy_Bagel_Store` pipeline.

**Output:**
- Table of recent executions with status, trigger type, and execution ID
- Detailed information about the most recent execution
- Stage-level status
- Abort/failure information (if applicable)
- Direct link to view execution in Harness UI

**Examples:**
```bash
# Get last 5 executions (default)
./scripts/get-pipeline-executions.sh

# Get last 10 executions
./scripts/get-pipeline-executions.sh 10
```

**Requirements:**
- `harness/.env` file with `HARNESS_API_KEY` set
- `jq` installed
- `curl` installed

### Verify Harness Entities

```bash
./scripts/verify-harness-entities.sh
```

**Purpose:** Verify all Harness entities required for the `Deploy_Bagel_Store` pipeline exist and are configured correctly.

**Checks:**
1. **Environments** (4): psr_dev, psr_test, psr_staging, psr_prod
2. **Infrastructure Definitions** (4): One per environment
3. **Services** (1): bagel_store
4. **Templates** (1): Coordinated_DB_App_Deployment
5. **Pipelines** (1): Deploy_Bagel_Store
6. **Connectors** (2+): github_bagel_store, aws_bagel_store
7. **Secrets** (4): github_pat, aws_access_key_id, aws_secret_access_key, liquibase_license_key

**Output:** Summary of entity counts and details for each category.

**When to run:**
- After Terraform apply
- Before manual Harness setup
- When diagnosing pipeline import/execution issues

### Update Trigger Configuration

```bash
./scripts/update-trigger.sh [--dry-run]
```

**Purpose:** Update the `GitHub_Actions_CI` trigger configuration via Harness API to ensure Input Set and Pipeline Reference Branch are properly configured.

**What it fixes:**
- Adds `webhook_default` Input Set if missing
- Sets Pipeline Reference Branch to `<+trigger.branch>` if missing
- Verifies the update was successful

**Usage:**
```bash
# Preview changes without applying
./scripts/update-trigger.sh --dry-run

# Apply changes
./scripts/update-trigger.sh
```

**When to use:**
- When `get-pipeline-executions.sh` shows missing Input Set or Pipeline Branch
- After importing a remote pipeline from Git
- When pipeline variables aren't resolving from webhook payload

**Requirements:**
- `harness/.env` file with `HARNESS_API_KEY` set
- `jq` installed
- `curl` installed

**Output:**
- Current trigger configuration
- Proposed changes
- Update result and verification
- Next steps for testing

## API Endpoint Reference

**Official Docs:** https://apidocs.harness.io/

### List Pipelines (CORRECT)

```bash
# IMPORTANT: Use POST, not GET
curl -X POST \
  'https://app.harness.io/pipeline/api/pipelines/list?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&page=0&size=100' \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineSetup"}'
```

### List Pipeline Executions

```bash
curl -X POST \
  'https://app.harness.io/pipeline/api/pipelines/execution/summary?routingId=ACCOUNT&accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&pipelineIdentifier=PIPELINE&page=0&size=10' \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineExecution"}'
```

### Get Execution Summary (v2)

```bash
curl \
  'https://app.harness.io/pipeline/api/pipelines/execution/v2/EXECUTION_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

**Returns:** Pipeline execution summary with stage statuses, trigger info, Git details, abort info

### Get Detailed Execution with Logs (BEST for debugging)

```bash
curl \
  'https://app.harness.io/pipeline/api/pipelines/execution/EXECUTION_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

**Returns:** Complete execution graph with:
- `executionGraph.nodeMap` - All steps with status, failureInfo, logs
- `executionGraph.nodeAdjacencyListMap` - Step dependencies
- Detailed error messages in `failureInfo.message`
- Interrupt histories (aborts, timeouts, etc.)

**Reference:** https://apidocs.harness.io/pipeline-execution-details

### Get Trigger Configuration

```bash
curl \
  'https://app.harness.io/pipeline/api/triggers/TRIGGER_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&targetIdentifier=PIPELINE_ID' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

**Returns:** Trigger configuration including:
- `.data.yaml` - **IMPORTANT:** inputSetRefs and pipelineBranchName are in YAML, not JSON fields
- Webhook conditions and configuration

**Critical Note:** The JSON response fields `.data.inputSetRefs` and `.data.pipelineBranchName` return `null`. You MUST parse the `.data.yaml` field to get these values.

### Update Trigger Configuration

```bash
curl -X PUT \
  'https://app.harness.io/pipeline/api/triggers/TRIGGER_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&targetIdentifier=PIPELINE_ID' \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "TRIGGER_ID",
    "yaml": "trigger:\n  name: TRIGGER_NAME\n  identifier: TRIGGER_ID\n  ...\n  inputSetRefs:\n    - webhook_default\n  pipelineBranchName: <+trigger.branch>"
  }'
```

**Use Case:** Update trigger to add Input Set or Pipeline Reference Branch

**Parameters:**
- `identifier` - Trigger identifier
- `yaml` - Complete trigger YAML (get from GET endpoint, modify, then PUT back)

**Strategy:**
1. GET current trigger configuration
2. Parse `.data.yaml` field
3. Modify YAML to add/update `inputSetRefs` and `pipelineBranchName`
4. PUT updated YAML back via this endpoint

**Reference:** https://apidocs.harness.io/tag/Webhook-Triggers/

## Other Diagnostic Scripts

### Check Dependencies

```bash
./scripts/check-dependencies.sh
```

Verifies all required tools are installed (Docker, AWS CLI, `jq`, `curl`, etc.).

### Diagnose AWS

```bash
./scripts/diagnose-aws.sh
```

Checks AWS credentials, profile configuration, and connectivity.

### Get Webhook URL

```bash
./scripts/get-webhook-url.sh
```

Retrieves the Harness webhook URL for the `GitHub_Actions_CI` trigger (used for GitHub Actions integration).

## Harness API Authentication

All Harness API scripts require an API key stored in `harness/.env`:

```bash
HARNESS_API_KEY=pat.ACCOUNT_ID.TOKEN_ID.TOKEN_VALUE
```

**To create a new API token:**

1. Harness UI → Profile icon (top right) → **My Profile**
2. **My API Keys** → **+ API Key**
3. Name it (e.g., "debug-api-key") → **Save**
4. **+ Token** → Name it → Set expiration (30 days recommended)
5. **Generate Token** → **Copy immediately** (shown only once!)
6. Add to `harness/.env`: `HARNESS_API_KEY=pat.xxxxx.yyyyy.zzzzz`

## Common Workflows

### Diagnosing Pipeline Failures

1. **Get recent executions:**
   ```bash
   ./scripts/get-pipeline-executions.sh
   ```

2. **Check which stage failed** (from script output)

3. **View detailed logs** in Harness UI (link provided by script)

4. **Verify all entities exist:**
   ```bash
   ./scripts/verify-harness-entities.sh
   ```

### After Terraform Changes

```bash
# 1. Verify Terraform-managed resources
./scripts/verify-harness-entities.sh

# 2. Check if pipelines can see new environments
./scripts/get-pipeline-executions.sh 1

# 3. If needed, trigger a test run
gh run list --limit 1  # Get latest GitHub Actions run
```

### Troubleshooting Webhook Integration

```bash
# 1. Get webhook URL from Harness
./scripts/get-webhook-url.sh

# 2. Verify GitHub variable is set correctly
gh variable list --repo OWNER/REPO | grep HARNESS_WEBHOOK_URL

# 3. Check recent pipeline triggers
./scripts/get-pipeline-executions.sh 5
```

## Notes

- All scripts should be run from the repository root directory
- Scripts require `harness/.env` file with valid `HARNESS_API_KEY`
- Most scripts use `jq` for JSON parsing - install if missing
- Harness API endpoints may change - check [apidocs.harness.io](https://apidocs.harness.io/) for updates
