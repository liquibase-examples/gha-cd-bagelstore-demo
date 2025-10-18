# Pipeline Failure Analysis - 2025-10-18

## Executive Summary

**Status:** Webhook trigger working ✅ | Pipeline execution failing ❌

**Root Cause:** Trigger misconfiguration - missing Input Set and Pipeline Reference Branch

**Impact:** Pipeline variables not resolving from webhook payload, causing infrastructure resolution failure

---

## Investigation Timeline

### 1. Initial Diagnosis

**Symptom:** Harness pipeline triggered by GitHub Actions webhook but aborted after ~5 seconds

**Execution Details:**
- **Execution ID:** `aWd-ZRx8TN24Qf-FJKPAUQ`
- **Status:** Aborted by `systemUser`
- **Failed Stage:** Deploy to Dev
- **Duration:** 5 seconds
- **Error:** `Invalid request: INVALID_REQUEST` at Infrastructure step

### 2. Deep Dive Analysis

Used Harness API endpoint for detailed execution logs:
```bash
GET /pipeline/api/pipelines/execution/{executionId}
```

**Key Findings from Execution Graph:**

1. **Service Step:** ✅ Succeeded
2. **Infrastructure Step:** ❌ Failed with `INVALID_REQUEST`
3. **Pipeline Variables:** Unresolved expressions:
   ```json
   "variables": {
     "DEPLOYMENT_TARGET": "<+trigger.payload.deployment_target>",
     "GITHUB_ORG": "<+trigger.payload.github_org>",
     "VERSION": "<+trigger.payload.version>"
   }
   ```

These should have actual values (e.g., `"VERSION": "v1.0.0"`), but remained as unresolved expressions.

### 3. Webhook Payload Verification

**GitHub Actions Workflow** (`main-ci.yml` lines 243-254):

Sends correct payload structure:
```json
{
  "version": "v1.0.0",
  "github_org": "liquibase-examples",
  "deployment_target": "aws",
  "branch": "main",
  "commit_sha": "...",
  "commit_message": "...",
  "triggered_by": "...",
  "run_id": "..."
}
```

✅ Payload is correct

### 4. Input Set Verification

**Input Set File** (`harness/input-sets/webhook-default-2.yaml`):

Correctly maps webhook payload to pipeline variables:
```yaml
variables:
  - name: VERSION
    value: <+trigger.payload.version>
  - name: GITHUB_ORG
    value: <+trigger.payload.github_org>
  - name: DEPLOYMENT_TARGET
    value: <+trigger.payload.deployment_target>
```

✅ Input Set definition is correct

### 5. Trigger Configuration Check

Used Harness API to check actual trigger configuration:

```bash
GET /pipeline/api/triggers/GitHub_Actions_CI
```

**Result:**
```json
{
  "identifier": "GitHub_Actions_CI",
  "name": "GitHub_Actions_CI",
  "inputSetRefs": null,          // ❌ MISSING!
  "pipelineBranchName": null     // ❌ MISSING!
}
```

---

## Root Cause

The `GitHub_Actions_CI` trigger is **not configured to use the Input Set**, even though the Input Set file exists in Git.

**Impact Chain:**
1. Webhook payload arrives with correct data
2. Trigger has no Input Set configured
3. Pipeline variables remain as unresolved expressions
4. Infrastructure step tries to resolve environment with `null` values
5. Harness throws `INVALID_REQUEST` error
6. Pipeline aborted by system

---

## Solution

### Required Fix

Update the `GitHub_Actions_CI` trigger in Harness UI:

1. **Navigate to Trigger:**
   - Go to: Pipelines → Deploy Bagel Store → Triggers tab
   - Click: **Edit** on `GitHub_Actions_CI` trigger

2. **Configure Pipeline Input:**
   - Go to: **Pipeline Input** tab
   - Click: **+ Select Input Set(s)**
   - Select: `webhook_default` from dropdown
   - Verify variables show orange expressions (not `<+input>`)

3. **Set Pipeline Reference Branch:**
   - In same **Pipeline Input** tab
   - Find: **Pipeline Reference Branch** field
   - Enter: `<+trigger.branch>`
   - **Why:** Remote pipelines need to know which Git branch to fetch from

4. **Save Trigger**

### Verification Steps

After fixing the trigger:

```bash
# 1. Verify trigger configuration
./scripts/get-pipeline-executions.sh

# Should show:
# ✅ Input Set configured: ["webhook_default"]
# ✅ Pipeline Branch configured: <+trigger.branch>

# 2. Trigger a test run
gh workflow run main-ci.yml --ref main

# 3. Watch GitHub Actions
gh run watch

# 4. Check Harness pipeline execution
./scripts/get-pipeline-executions.sh 1
```

---

## Related Documentation

- **Manual Setup Guide:** [docs/HARNESS_MANUAL_SETUP.md](HARNESS_MANUAL_SETUP.md) (Step 4.4)
- **Troubleshooting:** [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **API Reference:** [scripts/README.md](../scripts/README.md) - API Endpoint Reference

---

## Tools Created During Investigation

### 1. `scripts/get-pipeline-executions.sh`

**Purpose:** Query recent pipeline executions with detailed logs and trigger configuration check

**Features:**
- Lists recent executions with status, trigger type, timestamps
- Shows detailed info for latest execution
- **NEW:** Automatically checks trigger configuration for common issues
- Provides direct link to Harness UI for execution

**Usage:**
```bash
./scripts/get-pipeline-executions.sh [limit]
```

### 2. Updated `scripts/verify-harness-entities.sh`

**Fix Applied:** Corrected Pipelines API endpoint from GET to POST

**Before:**
```bash
curl -X GET 'https://app.harness.io/pipeline/api/pipelines?...'  # ❌ Returns 0 pipelines
```

**After:**
```bash
curl -X POST 'https://app.harness.io/pipeline/api/pipelines/list?...' \
  -d '{"filterType":"PipelineSetup"}'  # ✅ Correct
```

### 3. `scripts/README.md`

**Added:** Complete API endpoint reference including:
- List Pipelines (correct POST method)
- List Pipeline Executions
- Get Execution Details (with logs)
- Get Trigger Configuration

**Reference:** https://apidocs.harness.io/

---

## Key Learnings

### Harness API Patterns

1. **Pipelines List API requires POST** (not GET as might be expected)
2. **Execution details API** (`/execution/{id}`) returns full execution graph with step-level logs
3. **Trigger configuration** can be queried via API to verify Input Set and Pipeline Branch settings

### Remote Pipeline Requirements

For remote pipelines (stored in Git), triggers **MUST** have:
1. ✅ Input Set selected (maps webhook payload to pipeline variables)
2. ✅ Pipeline Reference Branch set (tells Harness which Git branch to fetch from)

Without these, the pipeline will fail with `INVALID_REQUEST` or remain in `QUEUED` state.

### Diagnostic Workflow

When investigating pipeline failures:

1. **Get execution details** with full node graph
2. **Check for unresolved expressions** in variables
3. **Verify webhook payload** from GitHub Actions logs
4. **Check Input Set mapping** in Git repository
5. **Verify trigger configuration** via API
6. **Look for discrepancies** between what exists vs. what's configured

---

## Next Steps

1. ✅ Fix trigger configuration (add Input Set + Pipeline Branch)
2. ✅ Test with new workflow run
3. ✅ Verify all 4 stages execute successfully
4. ✅ Document working configuration

---

## Appendix: API Commands Used

### Get Pipeline Executions
```bash
curl -X POST \
  'https://app.harness.io/pipeline/api/pipelines/execution/summary?routingId=ACCOUNT&accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&pipelineIdentifier=PIPELINE&page=0&size=10' \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filterType":"PipelineExecution"}'
```

### Get Detailed Execution (with logs)
```bash
curl \
  'https://app.harness.io/pipeline/api/pipelines/execution/EXECUTION_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

### Get Trigger Configuration
```bash
curl \
  'https://app.harness.io/pipeline/api/triggers/TRIGGER_ID?accountIdentifier=ACCOUNT&orgIdentifier=ORG&projectIdentifier=PROJECT&targetIdentifier=PIPELINE_ID' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

**Reference:** https://apidocs.harness.io/pipeline-execution-details
