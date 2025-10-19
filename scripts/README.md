# Diagnostic and Helper Scripts

This directory contains scripts for diagnosing and managing the Bagel Store demo environment.

## Directory Structure

```
scripts/
├── harness/           # Harness API interaction and monitoring
├── templates/         # Harness template management and Git sync
├── deployment/        # Local deployment management
├── setup/             # Initial setup and diagnostics
└── README.md          # This file
```

---

## Harness API Scripts (`harness/`)

Scripts for interacting with the Harness API to monitor pipelines, executions, and resources.

### Trigger Pipeline via Webhook

```bash
./scripts/harness/trigger-pipeline-webhook.sh [VERSION] [DEPLOYMENT_TARGET] [GITHUB_ORG]
```

**Purpose:** Manually trigger the Harness pipeline using the webhook endpoint (same method as GitHub Actions).

**Arguments (all optional):**
- `VERSION`: Git version tag (default: auto-detected from current commit)
- `DEPLOYMENT_TARGET`: `aws` or `local` (default: `aws`)
- `GITHUB_ORG`: GitHub organization name (default: `liquibase-examples`)

**Requirements:**
- `HARNESS_WEBHOOK_URL` must be set in `harness/.env`
- Get webhook URL with: `./scripts/harness/get-webhook-url.sh`

**Output:**
- Version and deployment parameters
- Webhook payload (JSON)
- Webhook response with event correlation ID
- Trigger processing status
- Pipeline execution ID (if successful)
- Optional: Auto-monitoring of execution progress

**Examples:**
```bash
# Auto-detect version from current commit, deploy to AWS
./scripts/harness/trigger-pipeline-webhook.sh

# Specific version, deploy to AWS
./scripts/harness/trigger-pipeline-webhook.sh dev-abc123

# Specific version, deploy locally via Docker Compose
./scripts/harness/trigger-pipeline-webhook.sh dev-abc123 local

# Custom GitHub org
./scripts/harness/trigger-pipeline-webhook.sh v1.0.0 aws my-org
```

**Troubleshooting:**
- If webhook fails with `INVALID_RUNTIME_INPUT_YAML`, check template validation
- If trigger stays `QUEUED`, check Harness UI for pipeline/template sync issues
- View trigger details API endpoint shown in output

---

### List Pipeline Executions

```bash
./scripts/harness/get-pipeline-executions.sh [limit]
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
./scripts/harness/get-pipeline-executions.sh

# Get last 10 executions
./scripts/harness/get-pipeline-executions.sh 10
```

### Get Execution Details

```bash
./scripts/harness/get-execution-details.sh <execution_id>
```

Get detailed information about a specific pipeline execution.

### Get Execution Graph

```bash
./scripts/harness/get-execution-graph.sh <execution_id>
```

Get the complete execution graph with all nodes and dependencies.

### Get Stage Logs

```bash
./scripts/harness/get-stage-logs.sh <execution_id> <stage_name>
```

Get logs for a specific pipeline stage.

### Get Execution Logs

```bash
./scripts/harness/get-execution-logs.sh <execution_id>
```

Get all logs for a pipeline execution.

### Get Delegate Logs

```bash
./scripts/harness/get-delegate-logs.sh
```

Get logs from the Harness delegate.

### Verify Harness Entities

```bash
./scripts/harness/verify-harness-entities.sh
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

### Check Harness Resources

```bash
./scripts/harness/check-harness-resources.sh
```

Check the status of all Harness resources.

### Update Trigger Configuration

```bash
./scripts/harness/update-trigger.sh [--dry-run]
```

**Purpose:** Update the `GitHub_Actions_CI` trigger configuration via Harness API to ensure Input Set and Pipeline Reference Branch are properly configured.

**What it fixes:**
- Adds `webhook_default` Input Set if missing
- Sets Pipeline Reference Branch to `<+trigger.branch>` if missing
- Verifies the update was successful

**Usage:**
```bash
# Preview changes without applying
./scripts/harness/update-trigger.sh --dry-run

# Apply changes
./scripts/harness/update-trigger.sh
```

**When to use:**
- When `get-pipeline-executions.sh` shows missing Input Set or Pipeline Branch
- After importing a remote pipeline from Git
- When pipeline variables aren't resolving from webhook payload

### Get Trigger Configuration

```bash
./scripts/harness/get-trigger.sh
```

Get the current trigger configuration.

### Get Input Set

```bash
./scripts/harness/get-inputset.sh
```

Get the input set configuration.

### Get Webhook URL

```bash
./scripts/harness/get-webhook-url.sh
```

Retrieves the Harness webhook URL for the `GitHub_Actions_CI` trigger (used for GitHub Actions integration).

### Search Harness API

```bash
./scripts/harness/search-harness-api.py "<search_term>"
```

Search the Harness OpenAPI specification for endpoints and operations.

**Examples:**
```bash
./scripts/harness/search-harness-api.py "execution"
./scripts/harness/search-harness-api.py "trigger"
```

### Harness API Wrapper

```bash
./scripts/harness/harness-api.sh <METHOD> <endpoint> [jq_filter]
```

**Purpose:** Wrapper for making authenticated Harness API calls. Automatically loads API key from `harness/.env`.

**Examples:**
```bash
# GET request
./scripts/harness/harness-api.sh GET "https://app.harness.io/pipeline/api/pipelines/..."

# POST request with data
./scripts/harness/harness-api.sh POST "https://app.harness.io/..." '{"key":"value"}'

# With jq filter
./scripts/harness/harness-api.sh GET "https://app.harness.io/..." '.data.status'
```

**Requirements (All Harness Scripts):**
- `harness/.env` file with `HARNESS_API_KEY` set
- `jq` installed
- `curl` installed

---

## Template Management Scripts (`templates/`)

Scripts for managing Harness templates and Git synchronization.

### Get Template

```bash
./scripts/templates/get-template.sh <template_name>
```

Get template YAML from Harness.

### Compare Template with Git

```bash
./scripts/templates/compare-template-with-git.sh
```

Compare Harness template with Git version.

### Refresh Template

```bash
./scripts/templates/refresh-template.sh
```

Manually sync template from Git (normal refresh).

### Force Refresh Template

```bash
./scripts/templates/force-refresh-template.sh
```

Force refresh template from Git (bypass cache).

### Validate Template

```bash
./scripts/templates/validate-template.sh
```

Validate template YAML syntax.

### Test Git Connector

```bash
./scripts/templates/test-git-connector.sh
```

Test GitHub connector connectivity.

### Test Pipeline Import

```bash
./scripts/templates/test-pipeline-import.sh
```

Test pipeline import from Git.

---

## Deployment Scripts (`deployment/`)

Scripts for managing local Docker Compose deployments.

### Show Deployment State

```bash
./scripts/deployment/show-deployment-state.sh
```

Show current deployment state (all environments).

**Output:**
- Current version deployed in each environment
- Container status
- Service URLs

### Reset Local Environments

```bash
./scripts/deployment/reset-local-environments.sh [version]
```

Reset local Docker environments.

**Examples:**
```bash
# Reset all environments to latest
./scripts/deployment/reset-local-environments.sh latest

# Reset to specific version
./scripts/deployment/reset-local-environments.sh v1.2.0
```

---

## Setup & Diagnostic Scripts (`setup/`)

Scripts for initial setup and system diagnostics.

### Check Dependencies

```bash
./scripts/setup/check-dependencies.sh
```

Verifies all required tools are installed (Docker, AWS CLI, `jq`, `curl`, etc.).

**When to run:**
- First-time setup
- After system updates
- When encountering "command not found" errors

### Diagnose AWS

```bash
./scripts/setup/diagnose-aws.sh
```

Checks AWS credentials, profile configuration, and connectivity.

**When to run:**
- AWS authentication errors
- Before terraform apply
- When App Runner deployments fail

### Create Harness AWS User

```bash
./scripts/setup/create-harness-aws-user.sh
```

Create AWS IAM user for Harness delegate with appropriate permissions.

---

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

---

## Common Workflows

### Diagnosing Pipeline Failures

1. **Get recent executions:**
   ```bash
   ./scripts/harness/get-pipeline-executions.sh
   ```

2. **Check which stage failed** (from script output)

3. **Get detailed logs for failed stage:**
   ```bash
   ./scripts/harness/get-stage-logs.sh <execution_id> "<stage_name>"
   ```

4. **Verify all entities exist:**
   ```bash
   ./scripts/harness/verify-harness-entities.sh
   ```

### After Terraform Changes

```bash
# 1. Verify Terraform-managed resources
./scripts/harness/verify-harness-entities.sh

# 2. Check if pipelines can see new environments
./scripts/harness/get-pipeline-executions.sh 1

# 3. If needed, trigger a test run
gh run list --limit 1  # Get latest GitHub Actions run
```

### Troubleshooting Webhook Integration

```bash
# 1. Get webhook URL from Harness
./scripts/harness/get-webhook-url.sh

# 2. Verify GitHub variable is set correctly
gh variable list --repo OWNER/REPO | grep HARNESS_WEBHOOK_URL

# 3. Check recent pipeline triggers
./scripts/harness/get-pipeline-executions.sh 5

# 4. If trigger configuration is wrong, update it
./scripts/harness/update-trigger.sh
```

### Template Sync Issues

```bash
# 1. Compare template in Harness vs Git
./scripts/templates/compare-template-with-git.sh

# 2. If out of sync, force refresh
./scripts/templates/force-refresh-template.sh

# 3. Verify template is valid
./scripts/templates/validate-template.sh
```

### First-Time Setup

```bash
# 1. Check all dependencies are installed
./scripts/setup/check-dependencies.sh

# 2. Verify AWS configuration
./scripts/setup/diagnose-aws.sh

# 3. Create AWS IAM user for Harness (if needed)
./scripts/setup/create-harness-aws-user.sh

# 4. Verify Harness entities exist
./scripts/harness/verify-harness-entities.sh
```

---

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

---

## Notes

- All scripts should be run from the repository root directory
- Scripts require `harness/.env` file with valid `HARNESS_API_KEY`
- Most scripts use `jq` for JSON parsing - install if missing
- Harness API endpoints may change - check [apidocs.harness.io](https://apidocs.harness.io/) for updates
