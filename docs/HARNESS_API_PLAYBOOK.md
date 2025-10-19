# Harness API Playbook

**Purpose:** Reliable, battle-tested patterns for using Harness APIs. Stop trial-and-error, start succeeding.

**Last Updated:** 2025-01-19

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Common Operations](#common-operations)
3. [Monitoring & Diagnostics](#monitoring--diagnostics)
4. [Pipeline Failure Diagnosis](#pipeline-failure-diagnosis)
5. [Troubleshooting Decision Trees](#troubleshooting-decision-trees)
6. [API Reference](#api-reference)
7. [Known Issues & Workarounds](#known-issues--workarounds)

---

## Quick Start

### Prerequisites

```bash
# 1. Ensure harness/.env exists with HARNESS_API_KEY
cat harness/.env
# Should contain: HARNESS_API_KEY=pat.ACCOUNT_ID.RANDOM_ID.TOKEN

# 2. Use the wrapper script (handles auth automatically)
./scripts/harness/harness-api.sh GET <endpoint>
```

### Authentication Pattern

**✅ ALWAYS use the wrapper:**
```bash
./scripts/harness/harness-api.sh GET "/pipeline/api/pipelines/list?accountIdentifier=..."
```

**❌ NEVER source env and curl separately:**
```bash
# DON'T DO THIS - source doesn't persist across Bash tool calls
source harness/.env
curl ... -H "x-api-key: ${HARNESS_API_KEY}"  # HARNESS_API_KEY will be blank!
```

**Why:** The `harness-api.sh` wrapper:
- Loads API key from `harness/.env` in same process
- Validates key format
- Adds base URL if missing
- Provides colored error messages
- Handles HTTP status codes

---

## Common Operations

### 1. Execute Pipeline

**✅ CORRECT - Application/YAML Content-Type**

```bash
# Step 1: Create runtime input YAML
cat > /tmp/runtime-input.yaml << 'EOF'
pipeline:
  identifier: Deploy_Bagel_Store
  variables:
    - name: VERSION
      type: String
      value: dev-abc123
    - name: GITHUB_ORG
      type: String
      value: liquibase-examples
    - name: DEPLOYMENT_TARGET
      type: String
      value: aws
EOF

# Step 2: Trigger execution
./scripts/harness/harness-api.sh POST \
  "https://app.harness.io/gateway/pipeline/api/pipeline/execute/Deploy_Bagel_Store?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&branch=main" \
  "$(cat /tmp/runtime-input.yaml)" \
  "application/yaml"
```

**Important Notes:**
- Content-Type MUST be `application/yaml`
- Body is plain YAML string (not JSON)
- Variables go under `pipeline.variables` (not `pipeline.stages[].variables`)
- Indentation matters (2 spaces per level)

**❌ WRONG - Application/JSON with runtimeInputYaml field**

```bash
# This FAILS with: "Value not provided for required variable: VERSION"
./scripts/harness/harness-api.sh POST \
  ".../pipeline/execute/Deploy_Bagel_Store?..." \
  '{
    "runtimeInputYaml": "pipeline:\n  identifier: Deploy_Bagel_Store\n  variables:\n..."
  }'
```

**Why it fails:** The `/pipeline/api/pipeline/execute/{identifier}` endpoint expects:
- **Request body:** Plain YAML string
- **Content-Type:** `application/yaml`
- **NOT:** JSON object with `runtimeInputYaml` field

**API Endpoint:**
```
POST /pipeline/api/pipeline/execute/{identifier}
Content-Type: application/yaml

Query Parameters (all required):
  - accountIdentifier
  - orgIdentifier
  - projectIdentifier
  - branch (for Git-synced pipelines)
```

**Reference:** OpenAPI spec at `docs/harness-openapi-formatted.json`, path `/pipeline/api/pipeline/execute/{identifier}`

---

### 2. Get Pipeline Executions

**✅ WORKING PATTERN**

```bash
./scripts/harness/get-pipeline-executions.sh 5  # Get last 5 executions
```

**Manual API call:**
```bash
./scripts/harness/harness-api.sh POST \
  "/pipeline/api/pipelines/execution/summary?routingId=_dYBmxlLQu61cFhvdkV4Jw&accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&page=0&size=5" \
  '{"filterType":"PipelineExecution"}'
```

**Response Structure:**
```json
{
  "status": "SUCCESS",
  "data": {
    "content": [
      {
        "planExecutionId": "ABC123...",
        "runSequence": 15,
        "status": "Success",
        "startTs": 1234567890,
        "executionTriggerInfo": {
          "triggerType": "WEBHOOK_CUSTOM"
        }
      }
    ]
  }
}
```

---

### 3. Get Execution Details

**✅ WORKING PATTERN**

```bash
./scripts/harness/get-execution-details.sh <execution_id>
```

**Manual API call:**
```bash
EXEC_ID="ABC123..."
./scripts/harness/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo"
```

---

### 4. Get Template

**✅ WORKING PATTERN**

```bash
./scripts/templates/get-template.sh "Coordinated_DB_App_Deployment"
```

**Manual API call:**
```bash
TEMPLATE_ID="Coordinated_DB_App_Deployment"
./scripts/harness/harness-api.sh GET \
  "/template/api/templates/${TEMPLATE_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0&getDefaultFromOtherRepo=true"
```

**Response contains:**
- `.data.yaml` - The actual template YAML (as string)
- `.data.gitDetails.objectId` - Git commit hash
- `.data.gitDetails.branch` - Git branch

---

### 5. Get Input Set

**✅ WORKING PATTERN**

```bash
./scripts/get-inputset.sh
```

**Returns:**
- Input set YAML structure
- Trigger payload mappings (e.g., `<+trigger.payload.version>`)

---

### 6. List Pipelines

**✅ WORKING PATTERN**

```bash
./scripts/harness/harness-api.sh POST \
  "/pipeline/api/pipelines/list?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&page=0&size=10" \
  '{"filterType":"PipelineSetup"}'
```

**⚠️ IMPORTANT:** Use POST, not GET! The `/pipelines/list` endpoint requires POST with filter body.

---

## Monitoring & Diagnostics

### Using the harness-api.sh Wrapper

**The wrapper script handles authentication automatically** - no need to source `.env` files or manage API keys manually.

**Basic syntax:**
```bash
./scripts/harness/harness-api.sh <METHOD> <ENDPOINT> [JQ_FILTER]
```

**Arguments:**
- `METHOD`: GET or POST
- `ENDPOINT`: API endpoint (with or without `https://app.harness.io` prefix)
- `JQ_FILTER`: Optional jq filter (default: `.` for full response)

---

### Pattern 1: Monitor Execution Until Complete

**✅ WORKING PATTERN**

```bash
EXEC_ID="ABC123..."

while true; do
  STATUS=$(./scripts/harness/harness-api.sh GET \
    "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
    ".data.pipelineExecutionSummary.status")

  echo "Status: $STATUS"

  if [[ "$STATUS" == "Success" ]] || [[ "$STATUS" == "Failed" ]] || [[ "$STATUS" == "Aborted" ]]; then
    echo "✅ Pipeline finished: $STATUS"
    break
  fi

  sleep 10
done
```

**Use case:** Wait for pipeline to complete before proceeding with next step.

---

### Pattern 2: Get Latest Execution Status

**✅ WORKING PATTERN**

```bash
# Option A: Using dedicated script (recommended)
./scripts/harness/get-pipeline-executions.sh 1

# Option B: Manual API call
./scripts/harness/harness-api.sh POST \
  "/pipeline/api/pipelines/execution/summary?routingId=_dYBmxlLQu61cFhvdkV4Jw&accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&page=0&size=1" \
  '{"filterType":"PipelineExecution"}' \
  '.data.content[0] | {planExecutionId, status, startTs}'
```

**Output:**
```json
{
  "planExecutionId": "ABC123...",
  "status": "Success",
  "startTs": 1737324000000
}
```

---

### Pattern 3: Extract Failed Step Details

**✅ WORKING PATTERN**

```bash
EXEC_ID="ABC123..."

./scripts/harness/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  '.data.executionGraph.nodeMap | to_entries[] | select(.value.status == "Failed") | {name: .value.name, error: .value.failureInfo.message}'
```

**Use case:** Identify which step failed and why.

**Output:**
```json
{
  "name": "Deploy Application via Terraform",
  "error": "terraform apply failed with exit code 1"
}
```

---

### Pattern 4: Get Multiple Execution Details

**✅ WORKING PATTERN**

```bash
./scripts/harness/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/v2/${EXEC_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  ".data.pipelineExecutionSummary | {status, runSequence, duration: ((.endTs - .startTs)/1000)}"
```

**Output:**
```json
{
  "status": "Success",
  "runSequence": 42,
  "duration": 285.5
}
```

---

### Pattern 5: Check Environment Variables

**✅ WORKING PATTERN**

```bash
./scripts/harness/harness-api.sh GET \
  "/ng/api/environmentsV2/psr_dev?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  '.data.environment.variables[] | select(.name == "jdbc_url") | {name, value}'
```

**Use case:** Verify environment configuration.

---

### Pattern 6: Check Trigger Configuration

**✅ WORKING PATTERN**

```bash
./scripts/harness/harness-api.sh GET \
  "/pipeline/api/triggers/GitHub_Actions_CI?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&targetIdentifier=Deploy_Bagel_Store" \
  '.data | {name, identifier, type, enabled}'
```

**Output:**
```json
{
  "name": "GitHub Actions CI",
  "identifier": "GitHub_Actions_CI",
  "type": "Webhook",
  "enabled": true
}
```

---

### Pattern 7: Verify Template Exists

**✅ WORKING PATTERN**

```bash
./scripts/harness/harness-api.sh GET \
  "/template/api/templates/Coordinated_DB_App_Deployment?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&versionLabel=v1.0&getDefaultFromOtherRepo=true" \
  '.data.template | {name, versionLabel, storeType}'
```

---

### When to Use Wrapper vs Dedicated Scripts

**✅ Use dedicated scripts when available:**
```bash
./scripts/harness/get-pipeline-executions.sh <limit>
./scripts/harness/get-execution-details.sh <exec_id>
./scripts/get-stage-logs.sh <exec_id> "<stage_name>"
./scripts/templates/get-template.sh "<template_name>"
```

**✅ Use `harness-api.sh` wrapper for:**
- Ad-hoc API exploration
- Testing new endpoints
- Custom jq filtering needs
- Operations without dedicated script

**❌ Don't use manual curl:**
- API key doesn't persist across Bash tool calls
- No error handling
- No automatic base URL handling

---

## Pipeline Failure Diagnosis

**Complete script documentation:** See [scripts/README.md](../scripts/README.md#harness-api-scripts-harness) for detailed usage of all diagnostic scripts.

### 30-Second Diagnostic Checklist

When a pipeline execution fails or is aborted, follow this workflow:

**Step 1: Check latest execution status**
```bash
./scripts/harness/get-pipeline-executions.sh 1
```
- Shows: Run #, status, trigger type, execution ID
- Use execution ID for next steps

**Step 2: If webhook-triggered, check trigger processing** (NEW SCRIPT!)
```bash
# Use new check-webhook-trigger.sh script
./scripts/harness/check-webhook-trigger.sh <EVENT_CORRELATION_ID>

# Or manually:
curl -s "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/{EVENT_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw" | \
  jq '.data.webhookProcessingDetails | {status, exception, message}'
```
- Catches: `INVALID_RUNTIME_INPUT_YAML`, template validation errors, input set issues
- If `exceptionOccured: true`, fix template/trigger before proceeding

**Step 3: Diagnose execution failure** (FAST - API only, ENHANCED!)
```bash
./scripts/harness/diagnose-execution-failure.sh <EXECUTION_ID>
```
- Shows: Failed/aborted steps, detailed error messages, exit codes, log URLs
- **NEW:** Detects systemUser aborts and directs you to UI console
- **NEW:** Extracts detailed errors from responseMessages[] array
- Time: ~2 seconds
- **Use this first** for quick root cause identification

**For specific step details:**
```bash
./scripts/harness/get-step-error-details.sh <EXECUTION_ID> "Step Name"
```

**Step 4: Download full logs if needed** (SLOW - downloads ZIP)
```bash
./scripts/harness/get-execution-logs.sh <EXECUTION_ID>
```
- Downloads: Complete logs ZIP, extracts, searches for errors
- Time: ~10-30 seconds depending on log size
- **Use this second** for deep dive debugging

---

### Failure Pattern Recognition

Quickly identify the problem category based on symptoms:

| Symptom | Root Cause | Diagnostic Action |
|---------|------------|-------------------|
| Webhook returns `INVALID_RUNTIME_INPUT_YAML` | Template YAML validation failed | Check trigger event details API, force refresh template |
| Webhook returns `QUEUED` forever | Trigger configuration issue | Check Pipeline Reference Branch, verify Input Set |
| `executionGraph: null` + Status = Aborted | Aborted during stage initialization | Check delegate connectivity, infrastructure definitions, environment variables |
| `executionGraph` has Failed nodes | Step-level runtime failure | Run `diagnose-execution-failure.sh` → identify failed step |
| Status = Success but deployment didn't work | Health check passed but app broken | Check App Runner service status, application logs directly |
| All steps show Success but pipeline Aborted | Failure strategy triggered | Check abort info, review failure strategies in pipeline YAML |

---

### Decision Tree: Symptom → Action

```
Pipeline execution failed/aborted
│
├─ Did it start executing? (Check executionGraph)
│  │
│  ├─ No (executionGraph: null)
│  │  ├─ Check trigger processing details API
│  │  ├─ Common causes:
│  │  │  - Delegate offline/disconnected
│  │  │  - Infrastructure definition missing
│  │  │  - Environment variable resolution failed
│  │  │  - Service/artifact configuration invalid
│  │  └─ Action: Check Harness UI Infrastructure tab, verify delegate
│  │
│  └─ Yes (executionGraph has nodes)
│     ├─ Run: ./scripts/harness/diagnose-execution-failure.sh <EXEC_ID>
│     ├─ Identify failed step(s)
│     └─ If error message unclear:
│        └─ Run: ./scripts/harness/get-execution-logs.sh <EXEC_ID>
│
└─ Was it a webhook trigger?
   │
   ├─ Yes
   │  ├─ Check: Webhook event details API
   │  ├─ Common issues:
   │  │  - INVALID_RUNTIME_INPUT_YAML (template validation)
   │  │  - Input set payload mapping errors
   │  │  - Pipeline Reference Branch not set
   │  └─ Solution: See "Problem: Webhook Trigger Stays QUEUED" below
   │
   └─ No (Manual trigger)
      └─ Check runtime input YAML format matches pipeline variables
```

---

### Common Error Patterns and Solutions

#### Pattern: "No custom trigger found"

**Symptom:** Webhook call succeeds but pipeline doesn't trigger

**Root Cause:** Wrong webhook URL in GitHub variable

**Solution:**
```bash
# Get correct webhook URL
./scripts/harness/get-webhook-url.sh

# Update GitHub variable (NOT secret)
gh variable set HARNESS_WEBHOOK_URL --body "<URL>"
```

---

#### Pattern: Pipeline starts then immediately aborts

**Symptom:**
- `executionGraph: null`
- Status = Aborted
- Duration < 30 seconds
- Aborted by `systemUser`

**Root Cause:** Stage initialization failed (infrastructure, delegate, or environment issue)

**Diagnostic:**
```bash
# 1. Check delegate status
./scripts/harness/get-delegate-logs.sh

# 2. Verify Harness entities exist
./scripts/harness/verify-harness-entities.sh

# 3. Check infrastructure definition in Harness UI
# Navigate to: Environments → <env> → Infrastructure Definitions
```

**Common Causes:**
- Delegate disconnected or restarting
- Infrastructure definition references non-existent resources
- Environment variables have unresolvable Harness expressions
- CustomDeployment template not found or invalid

---

#### Pattern: systemUser Abort (Artifact/Resource Not Found)

**NEW:** Enhanced diagnostic script now detects this pattern automatically!

**Symptom:**
- Status = Aborted
- `abortedBy: "systemUser"` (not a human)
- `executionGraph` is empty or has no failed steps
- **API returns `failureInfo: null` and `executionErrorInfo: null`**

**Root Cause:** Pipeline aborted during stage initialization BEFORE any steps executed. Common triggers:
- **Artifact resolution failed** (GitHub artifact not found - most common!)
- Infrastructure definition validation failed
- Delegate task assignment failed
- Service definition invalid

**CRITICAL: API Cannot Provide Error Details!**

When execution aborts during initialization, the error message is ONLY visible in the Harness UI Console. The API will return `null` for all error fields because no steps were executed.

**Diagnostic Workflow:**

```bash
# 1. Run enhanced diagnostic script (detects pattern automatically)
./scripts/harness/diagnose-execution-failure.sh <EXEC_ID>

# If it shows "DETECTED: systemUser Abort During Stage Initialization":
# ⚠️  API cannot help - proceed to UI
```

**Output Example:**
```
⚠️  DETECTED: systemUser Abort During Stage Initialization

This typically means:
  • Artifact resolution failed (GitHub artifact not found)
  • Infrastructure definition missing/invalid
  • Delegate offline or unavailable
  • Environment variable resolution failed

API cannot provide error details for initialization failures.

ACTION REQUIRED: Check Harness UI Console
1. Go to: https://app.harness.io/...
2. Click 'Console View' tab
3. Expand the aborted stage
4. Read the console output for the actual error message
```

**In Harness UI Console, Look For:**
- `❌ Failed to find artifact: changelog-xyz` ← Artifact naming mismatch
- `Error: Infrastructure definition 'xxx' not found` ← Missing infrastructure
- `No delegate could be assigned` ← Delegate offline
- `Error resolving expression: <+env.variables.xyz>` ← Variable issue

**Common Solutions:**

| Error in UI Console | Solution |
|---------------------|----------|
| "Failed to find artifact: changelog-X" | Check artifact naming in GitHub Actions vs. pipeline VERSION variable |
| "Infrastructure definition not found" | Verify infrastructure YAML exists in `.harness/` and is synced |
| "No delegate could be assigned" | Check delegate status: `./scripts/harness/get-delegate-logs.sh` |
| "Error resolving expression" | Verify environment variable exists and is populated |

**Real Example from 2025-01-19:**

```
Console Output:
  ❌ Failed to find artifact: changelog-main-edde11c
  Available artifacts:
    changelog-dev-3df91b6
    changelog-dev-ab91d58
    ...

Root Cause: GitHub Actions created "changelog-dev-<sha>" but pipeline expected "changelog-main-<sha>"
Fix: Aligned version format between GitHub Actions and trigger script
```

**Key Takeaway:**
- ✅ **Use API** for step-level failures (after execution begins)
- ❌ **Use UI Console** for systemUser aborts (initialization failures)
- The enhanced `diagnose-execution-failure.sh` now **detects this pattern and directs you to UI**

---

#### Pattern: Step fails with detailed error in responseMessages array

**NEW:** Enhanced diagnostic script now extracts these automatically!

**Symptom:**
- Step status = Failed or Aborted
- Generic error: "Shell Script execution failed. Please check execution logs."
- API response has data, but error is buried

**Root Cause:** Detailed errors are in `.failureInfo.responseMessages[]`, not `.failureInfo.message`

**Solution:**

```bash
# Option 1: Use enhanced diagnostic script (extracts automatically)
./scripts/harness/diagnose-execution-failure.sh <EXEC_ID>

# Now shows "Detailed Diagnostics" section with:
#   • Detailed Error Messages (from responseMessages array)
#   • Exit Codes
#   • Console Log URLs

# Option 2: Get details for specific step
./scripts/harness/get-step-error-details.sh <EXEC_ID> "Step Name"
```

**Output Example:**
```
Detailed Diagnostics
=========================================

Detailed Error Messages:
  Fetch Changelog Artifact:
    • Failed to find artifact: changelog-main-edde11c
    • Artifact download returned 404 Not Found

Exit Codes:
  Fetch Changelog Artifact: exit code 1
```

**Manual API Extraction:**
```bash
EXEC_ID="abc123..."

./scripts/harness/harness-api.sh GET \
  "/pipeline/api/pipelines/execution/${EXEC_ID}?accountIdentifier=..." \
  '.data.executionGraph.nodeMap |
   to_entries[] |
   select(.value.status == "Failed" or .value.status == "Aborted") |
   {
     step: .value.name,
     genericError: .value.failureInfo.message,
     detailedErrors: [.value.failureInfo.responseMessages[]? | select(.level == "ERROR") | .message],
     exitCode: .value.outcomes.output.exitCode
   }'
```

**Key Fields to Check (In Order):**
1. `.failureInfo.responseMessages[]` - **Detailed errors array (check here FIRST!)**
2. `.failureInfo.message` - Generic summary (often unhelpful)
3. `.outcomes.output.exitCode` - Exit code (1 = failure)
4. `.outcomes.log.url` - Console log download URL (requires special token)

---

#### Pattern: Step fails with "Expression evaluation failed"

**Symptom:** Step shows error like `Error evaluating expression: <+env.variables.xyz>`

**Root Cause:** Harness variable doesn't exist or has wrong name

**Solution:**
```bash
# Check environment variables via API
./scripts/harness/harness-api.sh GET \
  "/ng/api/environmentsV2/<ENV_ID>?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  '.data.environment.variables[] | {name, value}'
```

---

### Quick Reference: Which Tool to Use When

| Goal | Tool | Speed | Detail Level |
|------|------|-------|--------------|
| "What's the latest execution status?" | `get-pipeline-executions.sh` | 1s | Summary table |
| "Why did it fail?" (first check) | `diagnose-execution-failure.sh` | 2s | Failed steps + error messages |
| "What exactly happened in this step?" | `get-execution-logs.sh` | 10-30s | Full logs, all steps |
| "Was the template YAML valid?" | Check trigger event details API | 1s | Validation errors |
| "Is the delegate working?" | `get-delegate-logs.sh` | 2s | Delegate connection status |
| "Do all Harness resources exist?" | `verify-harness-entities.sh` | 5s | Entity existence check |

---

### Integration with Existing Troubleshooting

The sections below provide detailed troubleshooting for specific error messages.

For general failure diagnosis workflow, **start with this section** and use the scripts above.

For specific error patterns (e.g., "Value not provided for required variable"), **see the Troubleshooting Decision Trees below**.

---

## Troubleshooting Decision Trees

### Problem: Pipeline Execution Returns 400 "Value not provided for required variable"

**Decision Tree:**

1. **Check Content-Type header**
   ```bash
   # ✅ Correct
   -H "Content-Type: application/yaml"

   # ❌ Wrong
   -H "Content-Type: application/json"
   ```

2. **Check request body format**
   ```yaml
   # ✅ Correct - Plain YAML string
   pipeline:
     identifier: Deploy_Bagel_Store
     variables:
       - name: VERSION
         type: String
         value: dev-abc123

   # ❌ Wrong - JSON object
   {
     "runtimeInputYaml": "pipeline:\n  identifier: ..."
   }
   ```

3. **Check variable placement**
   ```yaml
   # ✅ Correct - Pipeline-level variables
   pipeline:
     identifier: Deploy_Bagel_Store
     variables:
       - name: VERSION
         value: dev-abc123

   # ❌ Wrong - Stage-level variables
   pipeline:
     identifier: Deploy_Bagel_Store
     stages:
       - stage:
           variables:
             - name: VERSION  # Wrong location!
   ```

4. **Check YAML syntax**
   - Use 2-space indentation (not tabs)
   - Ensure array items use `- name:` format
   - Quote values with special characters

5. **Check query parameters**
   - Required: `accountIdentifier`, `orgIdentifier`, `projectIdentifier`
   - For Git-synced pipelines: Add `branch=main`

**If still failing:** Check OpenAPI spec example:
```bash
python3 scripts/search-harness-api.py "pipeline execute" --show-example
```

---

### Problem: Template Refresh Not Working

**Symptoms:**
- Manually clicked "Refresh" in Harness UI
- Git shows correct YAML
- But Harness still uses old version

**Diagnosis:**
```bash
# 1. Check Git commit hash Harness is using
./scripts/templates/get-template.sh "Coordinated_DB_App_Deployment" | jq -r '.data.gitDetails.objectId'

# 2. Check latest Git commit for template
git log -1 --oneline .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml

# 3. Compare - if different, refresh didn't work
```

**Workarounds:**

**Option A: Force refresh via API (if script exists)**
```bash
./scripts/force-refresh-template.sh "Coordinated_DB_App_Deployment"
```

**Option B: Delete and reimport template**
1. Go to Harness UI: Project Setup → Templates
2. Delete template
3. Re-import from Git

**Option C: Create new version**
1. Update `versionLabel` in Git (e.g., `v1.0` → `v1.1`)
2. Commit and push
3. Import as new template version

**Root Cause:** Harness Git Experience refresh button sometimes doesn't actually sync from Git (known issue, no ETA on fix).

---

### Problem: "Invalid yaml path [pipeline/stages/.../steps/[X]/step]"

**Meaning:** Template or pipeline YAML has invalid structure at specified step index.

**Common Causes:**

1. **Invalid `outputVariables` in ShellScript step**
   ```yaml
   # ❌ Wrong - ShellScript doesn't support this format
   - step:
       type: ShellScript
       spec:
         outputVariables:
           - name: SERVICE_URL
             type: String
             value: service_url  # Invalid!

   # ✅ Correct
   - step:
       type: ShellScript
       spec:
         outputVariables: []
   ```

2. **Missing required fields**
   - Every step needs: `type`, `name`, `identifier`, `spec`
   - ShellScript needs: `spec.shell`, `spec.source`

3. **Invalid step type**
   - Check step type spelling: `ShellScript` (not `Shell` or `Script`)

**Debug Process:**
1. Identify step index from error (e.g., `steps/[3]` = 4th step, 0-indexed)
2. Read template YAML: `./scripts/templates/get-template.sh <template_name> | jq -r '.data.yaml'`
3. Find step at that index
4. Compare with working examples in this playbook

---

### Problem: Webhook Trigger Stays QUEUED

**Symptoms:**
- GitHub Actions successfully calls webhook
- Returns `200 OK` with `eventCorrelationId`
- But pipeline never executes (stays QUEUED)

**Diagnosis:**
```bash
# Check trigger execution details
EVENT_ID="68f541df..."  # From webhook response
./scripts/harness/harness-api.sh GET \
  "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/${EVENT_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw"
```

**Common Causes:**

1. **Missing Pipeline Reference Branch**
   - Trigger configuration needs: `<+trigger.branch>` for Git-synced pipelines
   - Check: `./scripts/get-trigger.sh | grep -A 2 "pipelineBranchName"`

2. **Input Set payload mapping errors**
   - Input set expects `<+trigger.payload.version>`
   - But webhook sends different field name
   - Solution: Update input set or webhook payload

3. **YAML validation errors**
   - Same as "Invalid yaml path" above
   - Check `.data.webhookProcessingDetails.message` in trigger execution details

---

## API Reference

### Base URLs

- **Primary:** `https://app.harness.io`
- **Gateway:** `https://app.harness.io/gateway`

### Common Query Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `accountIdentifier` | Yes | Account ID (format: `_XXXXXXXXXXXXX`) |
| `orgIdentifier` | Yes (org-scoped) | Organization ID (usually `default`) |
| `projectIdentifier` | Yes (project-scoped) | Project ID |
| `branch` | For Git-synced | Git branch name (usually `main`) |

### Account Identifiers

For this project:
- **Account ID:** `_dYBmxlLQu61cFhvdkV4Jw`
- **Org ID:** `default`
- **Project ID:** `bagel_store_demo`

### API Endpoints We Use

| Operation | Method | Endpoint | Script |
|-----------|--------|----------|--------|
| Execute pipeline | POST | `/pipeline/api/pipeline/execute/{id}` | `harness-api.sh` + manual |
| List executions | POST | `/pipeline/api/pipelines/execution/summary` | `get-pipeline-executions.sh` |
| Get execution details | GET | `/pipeline/api/pipelines/execution/v2/{id}` | `get-execution-details.sh` |
| Get stage logs | GET | `/pipeline/api/pipelines/execution/{id}/logsToken/token` | `get-stage-logs.sh` |
| List pipelines | POST | `/pipeline/api/pipelines/list` | `harness-api.sh` |
| Get template | GET | `/template/api/templates/{id}` | `get-template.sh` |
| Get input set | GET | `/pipeline/api/inputSets/{id}` | `get-inputset.sh` |
| Get trigger | GET | `/pipeline/api/triggers/{id}` | `get-trigger.sh` |
| Webhook trigger | POST | `/pipeline/api/webhook/custom/{webhook_id}` | GitHub Actions |

### Content-Type Matrix

| Endpoint | Request Content-Type | Request Body Type |
|----------|---------------------|-------------------|
| `/pipeline/api/pipeline/execute/{id}` | `application/yaml` | Plain YAML string |
| `/pipeline/api/pipelines/execution/summary` | `application/json` | JSON object |
| `/pipeline/api/pipelines/list` | `application/json` | JSON object |
| `/pipeline/api/webhook/custom/*` | `application/json` | JSON object |
| All GET requests | N/A | N/A |

### Response Structure Pattern

Most Harness APIs return:
```json
{
  "status": "SUCCESS" | "FAILURE",
  "data": { ... },          // Actual response data
  "metaData": null,
  "correlationId": "..."
}
```

Success: `status === "SUCCESS"`
Failure: Check `.message` or `.data.message`

---

## Known Issues & Workarounds

### 1. Template Refresh Doesn't Sync from Git

**Issue:** Clicking "Refresh" button in Harness UI doesn't actually pull latest from Git.

**Impact:** Template changes in Git aren't reflected in Harness.

**Workaround:**
- Delete and reimport template
- OR create new version (change `versionLabel`)

**Status:** No ETA on fix from Harness.

---

### 2. API Error Messages Lack Context

**Issue:** Errors like "Value not provided for required variable: VERSION" don't specify:
- Which parameter is wrong
- Expected format
- Which part of YAML has the issue

**Workaround:**
- Use this playbook's troubleshooting decision trees
- Compare with working examples
- Check OpenAPI spec for exact format

**Prevention:** Always start with working example, modify incrementally.

---

### 3. Inconsistent Pagination Across Endpoints

**Issue:** Different endpoints use different pagination patterns:
- Some: `?page=0&size=10` with response headers
- Some: `?page=0&size=10` with response body metadata
- Some: `?pageIndex=0&pageSize=10`

**Workaround:** Check OpenAPI spec for specific endpoint's pagination style.

---

### 4. POST Required for "List" Endpoints

**Issue:** Endpoints like `/pipelines/list` require POST (not GET) with filter in body.

**Why:** Harness uses POST for filtering/search, even on read operations.

**Example:**
```bash
# ❌ Wrong - GET doesn't work
curl -X GET ".../pipelines/list?..."

# ✅ Correct - POST with filter body
curl -X POST ".../pipelines/list?..." -d '{"filterType":"PipelineSetup"}'
```

---

### 5. Variable Resolution in Runtime Input YAML

**Issue:** Pipeline variables defined as `value: <+input>` must be provided in runtime YAML.

**Format:**
```yaml
pipeline:
  identifier: Pipeline_Name
  variables:
    - name: VAR_NAME
      type: String
      value: actual_value_here  # NOT <+input>
```

**Common Mistake:** Copying pipeline definition YAML (which has `<+input>`) instead of creating runtime input YAML.

---

## How to Use This Playbook

### For AI Assistants

**BEFORE attempting Harness API call:**
1. Search this playbook for the operation
2. Use the exact working example
3. Only if not documented: Check OpenAPI spec at `docs/harness-openapi-formatted.json`

**AFTER solving new Harness API problem:**
1. Document the solution here
2. Add troubleshooting decision tree
3. Commit changes

### For Humans

**Quick lookup:**
```bash
# Search playbook
grep -i "pipeline execute" docs/HARNESS_API_PLAYBOOK.md

# Search OpenAPI spec
python3 scripts/search-harness-api.py "pipeline execute"
```

**When stuck:**
1. Check troubleshooting decision trees
2. Try working examples
3. Check `scripts/` for reference implementations

---

## Utility Scripts

### search-harness-api.py

Search the downloaded OpenAPI spec:

```bash
python3 scripts/search-harness-api.py "pipeline execute"
python3 scripts/search-harness-api.py "pipeline execute" --show-example
python3 scripts/search-harness-api.py --endpoint "/pipeline/api/pipeline/execute/{identifier}"
```

See `scripts/search-harness-api.py --help` for full usage.

---

## Contributing

**When you solve a new Harness API problem:**

1. Add working example to [Common Operations](#common-operations)
2. Add troubleshooting tree to [Troubleshooting](#troubleshooting-decision-trees)
3. Update [Known Issues](#known-issues--workarounds) if it's a Harness platform bug
4. Commit with message: `docs: Add Harness API pattern for [operation]`

**Format for new entries:**

```markdown
### X. Operation Name

**✅ WORKING PATTERN**

\`\`\`bash
# Working example here
\`\`\`

**❌ WRONG - Common Mistake**

\`\`\`bash
# What doesn't work and why
\`\`\`

**API Endpoint:**
\`\`\`
METHOD /path
Required params: ...
\`\`\`
```

---

## Appendix: OpenAPI Spec Location

- **Downloaded spec:** `docs/harness-openapi-formatted.json`
- **Source:** `https://apidocs.harness.io/page-data/shared/oas-index.yaml.json`
- **Web UI:** https://apidocs.harness.io/
- **Format:** OpenAPI 3.0.3

**Structure:**
```json
{
  "definition": {
    "openapi": "3.0.3",
    "paths": {
      "/pipeline/api/pipeline/execute/{identifier}": {
        "post": {
          "summary": "Execute a Pipeline with Runtime Input YAML",
          "requestBody": { ... },
          "responses": { ... }
        }
      }
    }
  }
}
```

**How to read:**
```bash
# Get all paths
jq '.definition.paths | keys' docs/harness-openapi-formatted.json

# Get specific endpoint
jq '.definition.paths["/pipeline/api/pipeline/execute/{identifier}"]' docs/harness-openapi-formatted.json
```

---

## Version History

- **2025-01-19:** Initial playbook created with pipeline execution, troubleshooting trees, known issues
- **Last updated by:** Claude Code AI Assistant

---

**Remember:** When in doubt, check this playbook first. Every hour spent here saves 10 hours of trial-and-error later.
