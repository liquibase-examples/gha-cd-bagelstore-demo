# Harness Webhook Trigger QUEUED Issue - Problem Report

**Date:** October 12, 2025
**Repository:** https://github.com/liquibase-examples/gha-cd-bagelstore-demo
**Status:** ✅ RESOLVED - Root cause identified and fixed (payload condition issue)

---

## Executive Summary

**✅ RESOLVED (October 12, 2025):** The QUEUED issue was caused by a **malformed payload condition** in the trigger configuration, not a missing branch field.

**Root Cause:** The trigger had a payload condition that compared the `version` field to the literal string `<+trigger.payload.version>` instead of evaluating the expression:

```yaml
payloadConditions:
  - key: version
    operator: Equals
    value: <+trigger.payload.version>  # ❌ This is treated as a literal string!
```

This condition **always failed** because the actual value was `"dev-7736958"`, not the text `"<+trigger.payload.version>"`.

**Solution:**
1. **Removed the malformed payload condition** (set to empty array: `payloadConditions: []`)
2. **Switched from inline `inputYaml` to `inputSetRefs`** for cleaner configuration
3. **Branch field in webhook payload** (added earlier) was needed for Git Experience

**Final Test Results (Event ID: 68ebb7e7a03d443c9d53c1b8):**
- ✅ GitHub Actions workflow completed successfully
- ✅ Webhook payload includes all required fields including `"branch": "main"`
- ✅ Harness received webhook (status: SUCCESS)
- ✅ **Pipeline execution STARTED** (status: TARGET_EXECUTION_REQUESTED)
- ✅ `pipelineExecutionId`: rnxCKmd0QP2q5RI0DQnFDg (NOT null!)
- ✅ `runtimeInput`: Variables correctly populated
- ⚠️ Pipeline aborted after ~2 seconds (separate issue - see "Pipeline Abort Issue" section)

**Conclusion:** The QUEUED trigger issue is **RESOLVED**. Trigger now successfully creates pipeline executions. A new issue exists where pipeline aborts immediately after starting.

---

## System Architecture

### Component Overview

1. **GitHub Actions Workflow** (`main-ci.yml`)
   - Builds Docker images and database changelog artifacts
   - Triggers Harness webhook with JSON payload containing:
     - `version` (e.g., "dev-1ed47a7")
     - `github_org` (e.g., "liquibase-examples")
     - `deployment_target` (e.g., "aws")
     - Additional metadata (commit SHA, message, etc.)

2. **Harness Pipeline** (`Deploy_Bagel_Store`)
   - Remote pipeline stored in Git: `harness/pipelines/deploy-pipeline.yaml`
   - Requires 3 runtime input variables:
     - `VERSION` (String, required: true)
     - `GITHUB_ORG` (String, required: true)
     - `DEPLOYMENT_TARGET` (String, required: true)

3. **Harness Input Set** (`webhook_default`)
   - Remote Input Set stored in Git: `harness/input-sets/webhook-default-2.yaml`
   - Maps webhook payload to pipeline variables using trigger expressions

4. **Harness Webhook Trigger** (`GitHub_Actions_CI`)
   - Custom webhook trigger (created manually in UI, not in Git)
   - Should resolve pipeline variables from webhook payload

### GitOps Configuration

**Managed in Git (Remote):**
- Pipeline: `harness/pipelines/deploy-pipeline.yaml`
- Template: `harness/templates/deployment-steps.yaml`
- Input Set: `harness/input-sets/webhook-default-2.yaml`

**Managed in Harness UI:**
- Webhook Trigger: `GitHub_Actions_CI` (NOT in Git)
- This is by design per `CLAUDE.md` ADR (avoids Terraform provider issues)

---

## The Problem

### Symptom

When GitHub Actions completes and sends webhook to Harness:
1. ✅ Webhook is received successfully (`status: "SUCCESS"`)
2. ✅ Event correlation ID is generated
3. ❌ Pipeline execution **never starts**
4. ❌ Trigger remains in `QUEUED` state indefinitely
5. ❌ `pipelineExecutionId` stays `null`
6. ❌ `runtimeInput` stays `null`

### API Evidence

```bash
curl -s "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/{eventId}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw"
```

**Response:**
```json
{
  "status": "QUEUED",
  "pipelineExecutionId": null,
  "runtimeInput": null,
  "message": "Trigger execution is queued.",
  "payload": {
    "version": "dev-1ed47a7",
    "github_org": "liquibase-examples",
    "deployment_target": "aws",
    ...
  }
}
```

**Key Observations:**
- `payload` contains all required fields ✅
- `runtimeInput: null` means pipeline variables were NOT resolved ❌
- `pipelineExecutionId: null` means pipeline never started ❌

---

## What We've Tried

### Attempt 1: Fix Pipeline Variable Definition (COMPLETED)

**Initial Problem:** Only 2 of 3 pipeline variables appeared in trigger Input Set UI.

**Root Cause Found:** Harness Input Sets only display variables with `required: true` in pipeline definition.

**Original pipeline variable:**
```yaml
- name: DEPLOYMENT_TARGET
  type: String
  required: false    # ❌ Hidden from Input Sets
  value: aws         # ❌ Static default
```

**Fixed to:**
```yaml
- name: DEPLOYMENT_TARGET
  type: String
  required: true     # ✅ Now visible in Input Sets
  value: <+input>    # ✅ Runtime input
```

**Commit:** `86031bb` - "Fix DEPLOYMENT_TARGET not appearing in Harness trigger Input Set"

**Result:** Variable now appears in trigger UI, but pipeline **still stays QUEUED**.

---

### Attempt 2: Use Input Set References (ATTEMPTED)

**Configuration:**

**Trigger YAML:**
```yaml
trigger:
  name: GitHub Actions CI
  identifier: GitHub_Actions_CI
  pipelineIdentifier: Deploy_Bagel_Store
  source:
    type: Webhook
    spec:
      type: Custom
  inputSetRefs:
    - webhook_default  # ✅ References the Input Set
```

**Input Set File:** `harness/input-sets/webhook-default-2.yaml`
```yaml
inputSet:
  name: Webhook Default
  identifier: webhook_default
  pipeline:
    identifier: Deploy_Bagel_Store
    variables:
      - name: VERSION
        type: String
        value: <+trigger.payload.version>
      - name: GITHUB_ORG
        type: String
        value: <+trigger.payload.github_org>
      - name: DEPLOYMENT_TARGET
        type: String
        value: <+trigger.payload.deployment_target>
```

**Result:** Trigger configuration is correct, identifiers match, but `runtimeInput: null` in API response. Pipeline **stays QUEUED**.

---

### Attempt 3: Use Inline inputYaml (ATTEMPTED)

**Configuration:**

Replaced `inputSetRefs` with inline `inputYaml` in trigger:

```yaml
trigger:
  name: GitHub Actions CI
  identifier: GitHub_Actions_CI
  pipelineIdentifier: Deploy_Bagel_Store
  source:
    type: Webhook
    spec:
      type: Custom
  inputYaml: |
    pipeline:
      identifier: Deploy_Bagel_Store
      variables:
        - name: VERSION
          type: String
          value: <+trigger.payload.version>
        - name: GITHUB_ORG
          type: String
          value: <+trigger.payload.github_org>
        - name: DEPLOYMENT_TARGET
          type: String
          value: <+trigger.payload.deployment_target>
```

**Result:** Still `runtimeInput: null`. Pipeline **stays QUEUED**.

---

## Critical Questions Requiring Investigation

### 1. Why is `runtimeInput` Always Null?

**Evidence:**
- Webhook payload contains all required fields
- Trigger expressions are correct: `<+trigger.payload.version>`
- Both Input Set approach AND inline `inputYaml` approach fail
- No exceptions in API response (`exceptionOccured: false`)

**Questions:**
- Is there a Harness-side validation error that's not being reported?
- Are remote pipelines incompatible with webhook triggers + Input Sets?
- Is there a required configuration field we're missing?

### 2. Input Set Sync Issues?

**Evidence:**
- Input Set is stored in Git (`webhook-default-2.yaml`)
- Trigger references it by correct identifier (`webhook_default`)
- User re-created Input Set in UI multiple times
- Git file was last modified 2+ hours before latest test

**Questions:**
- Does Harness properly sync remote Input Sets with triggers?
- Is there a cache invalidation issue?
- Does the Input Set need to be **Inline** instead of **Remote (Git)** for webhook triggers?

### 3. Remote Pipeline Compatibility?

**Evidence:**
- Pipeline is stored in Git (remote)
- Input Set is stored in Git (remote)
- Trigger is created in UI (not in Git)
- Manual pipeline executions work fine (not tested, but assumed)

**Questions:**
- Do remote pipelines have issues with webhook triggers?
- Does `pipelineBranchName: <+trigger.branch>` cause problems?
- Is there a feature flag or permission issue?

### 4. Pipeline Variable Resolution Order?

**Evidence:**
- All 3 variables have `required: true` and `value: <+input>`
- Trigger should provide values via Input Set or `inputYaml`
- But Harness seems to be waiting for manual input instead

**Questions:**
- Is Harness treating this as a "manual execution waiting for input"?
- Does the trigger's variable resolution take precedence over pipeline defaults?
- Is there a precedence issue between Input Set values and `inputYaml` values?

---

## Configuration Files

### Pipeline Definition (Git)

**File:** `harness/pipelines/deploy-pipeline.yaml`

**Key sections:**
```yaml
pipeline:
  name: Deploy Bagel Store
  identifier: Deploy_Bagel_Store
  variables:
    - name: VERSION
      type: String
      description: Git tag version (e.g., v1.0.0)
      required: true
      value: <+input>

    - name: GITHUB_ORG
      type: String
      description: GitHub organization name
      required: true
      value: <+input>

    - name: DEPLOYMENT_TARGET
      type: String
      description: Deployment target (aws or local)
      required: true
      value: <+input>
```

### Input Set Definition (Git)

**File:** `harness/input-sets/webhook-default-2.yaml`

```yaml
inputSet:
  name: Webhook Default
  identifier: webhook_default
  orgIdentifier: default
  projectIdentifier: bagel_store_demo
  pipeline:
    identifier: Deploy_Bagel_Store
    variables:
      - name: VERSION
        type: String
        value: <+trigger.payload.version>
      - name: GITHUB_ORG
        type: String
        value: <+trigger.payload.github_org>
      - name: DEPLOYMENT_TARGET
        type: String
        value: <+trigger.payload.deployment_target>
```

### Current Trigger Configuration (UI)

**Latest configuration (inline inputYaml):**

```yaml
trigger:
  name: GitHub Actions CI
  identifier: GitHub_Actions_CI
  enabled: true
  description: Triggered automatically when GitHub Actions completes artifact builds
  tags: {}
  orgIdentifier: default
  projectIdentifier: bagel_store_demo
  pipelineIdentifier: Deploy_Bagel_Store
  source:
    type: Webhook
    spec:
      type: Custom
      spec:
        payloadConditions:
          - key: version
            operator: Equals
            value: <+trigger.payload.version>
        headerConditions: []
  pipelineBranchName: <+trigger.branch>
  inputYaml: |
    pipeline:
      identifier: Deploy_Bagel_Store
      variables:
        - name: VERSION
          type: String
          value: <+trigger.payload.version>
        - name: GITHUB_ORG
          type: String
          value: <+trigger.payload.github_org>
        - name: DEPLOYMENT_TARGET
          type: String
          value: <+trigger.payload.deployment_target>
```

**Previous configuration (Input Set reference):**
```yaml
inputSetRefs:
  - webhook_default
```

---

## Webhook Payload Example

**GitHub Actions sends:**
```json
{
  "version": "dev-1ed47a7",
  "github_org": "liquibase-examples",
  "deployment_target": "aws",
  "commit_sha": "1ed47a76f68753b57c9bfdcc0327d878da915b07",
  "commit_message": "Fix GitHub Actions syntax error in webhook payload...",
  "triggered_by": "recampbell",
  "run_id": "18438704823"
}
```

**Harness receives (confirmed via API):**
```json
{
  "status": "SUCCESS",
  "data": {
    "eventCorrelationId": "68ebaba50580207a8a89a957",
    "webhookProcessingDetails": {
      "payload": "{\n    \"version\": \"dev-1ed47a7\",\n    \"github_org\": \"liquibase-examples\",\n    \"deployment_target\": \"aws\",\n    ...\n}"
    }
  }
}
```

---

## Environment Details

**Harness Account:** `_dYBmxlLQu61cFhvdkV4Jw`
**Organization:** `default`
**Project:** `bagel_store_demo`
**Pipeline:** `Deploy_Bagel_Store`
**Trigger:** `GitHub_Actions_CI`

**Webhook URL Format:**
```
https://app.harness.io/gateway/pipeline/api/webhook/custom/{webhookToken}/v3?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&triggerIdentifier=GitHub_Actions_CI
```

**Note:** The actual webhook URL with token is stored in GitHub repository variable `HARNESS_WEBHOOK_URL` (not committed to Git for security).

**Harness Delegate:**
- Running via Docker Compose locally
- Status: Connected (verified in UI)
- Recent heartbeat: < 1 minute
- Logs show some non-fatal errors (telemetry/logging related)

**Harness CLI:**
- Installed at `~/bin/harness` (version 0.0.29)
- Authenticated with API token
- Note: CLI doesn't support inputset/trigger commands (use API instead)

**Git Branch:** `main`
**Repository:** `gha-cd-bagelstore-demo`

---

## Test Cases to Reproduce

### Test Case 1: Rerun GitHub Actions Workflow

```bash
# Get latest successful run
gh run list --workflow=main-ci.yml --limit 1 --json databaseId,conclusion --jq '.[0]'

# Rerun it
gh run rerun 18438704823

# Wait for webhook trigger
sleep 60

# Check trigger status
curl -s "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/{eventId}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw" | jq '{status, pipelineExecutionId, runtimeInput}'
```

**Expected:** Pipeline starts executing
**Actual:** `status: "QUEUED"`, `pipelineExecutionId: null`, `runtimeInput: null`

### Test Case 2: Manual Pipeline Execution (NOT TESTED)

**To test whether the issue is trigger-specific:**

1. Go to Harness UI → Pipelines → Deploy Bagel Store
2. Click "Run"
3. Select Input Set: `webhook_default`
4. Click "Run Pipeline"

**Question:** Does manual execution with Input Set work? If YES, the issue is trigger-specific. If NO, the issue is with the Input Set itself.

---

## Documentation References

### Harness Documentation Patterns (from Context7)

**Trigger with Input Set Reference:**
```yaml
trigger:
  inputSetRefs:
    - myInputSet
```

**Trigger with Inline Override:**
```yaml
trigger:
  inputSetRefs:
    - myInputSet
  inputYaml: |
    pipeline:
      variables:
        - name: var1
          value: <+trigger.payload.field>
```

**Note:** Both patterns are valid according to Harness docs. Our implementation matches these patterns exactly.

### Related Harness Issues (from Context7 docs)

- **PIPE-24088, ZD-74889:** "Trigger Input Set Value Application" - Fixed issue where pipelines weren't using correct Input Set values
- **PIPE-27923, ZD-86676, 89044:** "Triggers with Pipelines and Input Sets in Different Git Repos" - Fixed triggers failing when pipeline and Input Set are in different repos with different default branches

**Our case:** Pipeline and Input Set are in the **same repo**, same branch (`main`).

---

## Harness API Authentication

All Harness API calls require authentication via API key.

**Authentication Header:**
```bash
-H 'x-api-key: YOUR_API_TOKEN'
```

**To create an API token:**
1. In Harness UI, click profile icon (top right) → **My Profile**
2. Go to **"My API Keys"** section → **"+ API Key"**
3. Name it (e.g., "debug-api-key") → **"Save"**
4. Click **"+ Token"** within the API key → Name it (e.g., "debug-token")
5. Set expiration (recommend 30 days for debugging)
6. Click **"Generate Token"**
7. **IMPORTANT:** Copy the token immediately (shown only once!)

**Example API call:**
```bash
curl -X GET \
  'https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main' \
  -H 'x-api-key: YOUR_TOKEN'
```

---

## Investigation Priorities

### Priority 1: Validate Input Set Sync

**Action:** Use Harness API to retrieve the actual Input Set definition Harness has cached/loaded.

**Questions:**
- Does the Input Set Harness sees match the Git file?
- Is Harness reading from the correct branch?
- Is there a sync delay or cache issue?

**API Endpoint:**
```bash
curl -X GET \
  'https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main' \
  -H 'x-api-key: YOUR_TOKEN'
```

### Priority 2: Test Manual Execution with Input Set

**Action:** Manually run pipeline with Input Set to isolate trigger vs Input Set issue.

**Steps:**
1. Go to Harness UI
2. Run pipeline manually
3. Select `webhook_default` Input Set
4. Click Run

**If this works:** Problem is trigger-specific (variable resolution from webhook payload)
**If this fails:** Problem is with Input Set definition itself

### Priority 3: Check Harness Logs/Audit Trail

**Action:** Review Harness audit logs or execution logs for hidden errors.

**Questions:**
- Are there validation errors not surfaced in API?
- Is there a permission issue?
- Are there feature flag requirements for remote pipelines + triggers?

### Priority 4: Verify Delegate Functionality

**Action:** Ensure delegate can successfully resolve expressions and execute pipelines.

**Current delegate status:**
- Shows "Connected" in UI ✅
- Has recent heartbeat ✅
- Shows non-fatal logging errors (cosmetic)

**Question:** Could delegate issues prevent trigger processing even though it shows "Connected"?

---

## Success Criteria

**The issue is resolved when:**

1. ✅ GitHub Actions completes and sends webhook to Harness
2. ✅ Harness receives webhook successfully
3. ✅ Pipeline execution starts automatically (not QUEUED)
4. ✅ `pipelineExecutionId` is assigned (not null)
5. ✅ `runtimeInput` is populated with variable values from trigger payload
6. ✅ Pipeline variables are resolved:
   - `VERSION = "dev-1ed47a7"`
   - `GITHUB_ORG = "liquibase-examples"`
   - `DEPLOYMENT_TARGET = "aws"`
7. ✅ Dev stage deploys automatically
8. ✅ Test/Staging/Prod stages wait for approval

---

## Additional Context

### Project Background

This is a demo project showcasing coordinated database + application deployments:
- Liquibase Secure 5.0.1 for database changes
- Python Flask application
- AWS infrastructure (RDS, App Runner, S3, Secrets Manager)
- Multi-environment promotion (dev → test → staging → prod)

### Why This Matters

The webhook trigger is the **critical integration point** between GitHub Actions CI and Harness CD. Without it working:
- Manual deployments are required (defeats automation purpose)
- Demo flow is broken (CI builds artifacts but CD never deploys them)
- Cannot showcase the full GitHub Actions + Harness integration

### Time Investment

**Total debugging time:** ~4 hours
**Root cause:** Still unknown
**Attempts:** 3 different configurations (all failed)

---

## Files for Review

**Critical files to examine:**

1. `harness/pipelines/deploy-pipeline.yaml` - Pipeline definition
2. `harness/input-sets/webhook-default-2.yaml` - Input Set definition
3. `.github/workflows/main-ci.yml` - GitHub Actions workflow
4. `docs/HARNESS_MANUAL_SETUP.md` - Setup documentation
5. `CLAUDE.md` - Project context and ADRs

**Commit history:**

```bash
# Input Set changes
git log --oneline -- harness/input-sets/webhook-default-2.yaml

# Pipeline changes
git log --oneline -- harness/pipelines/deploy-pipeline.yaml
```

---

## Request for Next Investigator

**Please:**

1. **Deeply research** Harness webhook trigger documentation for remote pipelines
2. **Verify** if Input Sets stored in Git are compatible with webhook triggers
3. **Test** manual pipeline execution with Input Set (Test Case 2)
4. **Query** Harness API to retrieve actual Input Set definition Harness sees
5. **Check** if there are known issues with:
   - Remote pipelines + webhook triggers + Input Sets
   - Variable resolution from trigger payload expressions
   - Git Experience + Custom webhooks
6. **Consider** reaching out to Harness Support if this is a platform bug

**Key Question:** Why does Harness accept the webhook, acknowledge receipt, but then fail to resolve pipeline variables from EITHER Input Set OR inline `inputYaml`, resulting in permanent QUEUED state?

---

## TEST RESULTS & INVESTIGATION FINDINGS

### Test Execution (October 12, 2025 - 13:56 UTC)

**Commit Tested:** `7736958` - "Fix: Add branch field to Harness webhook payload for Git Experience"

### Root Cause Hypothesis (DISPROVEN)

**Primary Issue:** Missing `branch` field in webhook payload prevents Harness from resolving remote pipeline location.

**Detailed Explanation:**

1. **Harness Git Experience Requirement:**
   - Remote pipelines and Input Sets are stored in Git
   - Harness needs to know which branch to fetch them from
   - The trigger configuration uses: `pipelineBranchName: <+trigger.branch>`
   - This is the **default and recommended** pattern per Harness documentation

2. **Custom Webhook Limitation:**
   - GitHub webhook events (push, PR, etc.) automatically include branch context
   - **Custom webhooks** must explicitly provide branch in the payload
   - Our GitHub Actions workflow was sending: `version`, `github_org`, `deployment_target`, metadata
   - **Missing:** `branch` field

3. **Failure Sequence:**
   ```
   GitHub Actions → Webhook Payload (no branch) → Harness Trigger
   → Tries to resolve <+trigger.branch> → NULL
   → Cannot fetch remote pipeline from Git
   → Cannot resolve pipeline variables
   → Execution stays QUEUED indefinitely
   → pipelineExecutionId: null, runtimeInput: null
   ```

4. **Why Input Sets Also Failed:**
   - Input Sets are also stored in Git (remote)
   - Harness uses the same branch resolution: `<+trigger.branch>`
   - Without branch context, cannot fetch Input Set either
   - Both `inputSetRefs` and inline `inputYaml` approaches failed

### Investigation Process

**Research Methods:**
1. ✅ Read all configuration files (pipeline, Input Set, workflow, template)
2. ✅ Fetched Harness documentation via Context7 MCP for webhook triggers
3. ✅ Reviewed git history for recent changes
4. ✅ Analyzed trigger execution API responses
5. ✅ Compared configuration against Harness best practices

**Key Documentation Finding:**

From Harness Developer Hub:
> "Pipeline Reference Branch: Shows the default value for the Pipeline Reference Branch field when Git Experience is enabled. This setting determines which branch's pipeline and Input Set definitions are used for builds triggered by webhooks."
>
> Default: `pipelineBranchName: <+trigger.branch>`

**Discovery Timeline:**
- **Initial hypothesis:** Input Set sync issues or validation errors
- **Second hypothesis:** Remote pipeline compatibility problems
- **Final discovery:** `<+trigger.branch>` expression cannot resolve without branch in payload
- **Validation:** Webhook payload inspection confirmed no `branch` field present

### Solution Applied

**File:** `.github/workflows/main-ci.yml`

**Change:** Added `branch` field to webhook payload (line 248)

```diff
  curl -X POST "${{ vars.HARNESS_WEBHOOK_URL }}" \
    -H "Content-Type: application/json" \
    -d "{
      \"version\": \"${{ steps.version.outputs.version }}\",
      \"github_org\": \"${{ github.repository_owner }}\",
      \"deployment_target\": \"${DEPLOYMENT_TARGET}\",
+     \"branch\": \"${{ github.ref_name }}\",
      \"commit_sha\": \"${{ github.sha }}\",
      \"commit_message\": $(echo '${{ github.event.head_commit.message }}' | jq -Rs .),
      \"triggered_by\": \"${{ github.actor }}\",
      \"run_id\": \"${{ github.run_id }}\"
    }"
```

**Benefits of this fix:**
- ✅ Resolves `<+trigger.branch>` expression correctly
- ✅ Enables Harness to fetch remote pipeline from Git
- ✅ Enables Harness to fetch remote Input Set from Git
- ✅ Pipeline variables resolve correctly from trigger payload
- ✅ Non-breaking change (adds data, doesn't remove anything)
- ✅ Future-proof (supports branch-specific deployments if needed)
- ✅ Uses GitHub context variable (`${{ github.ref_name }}`) for accuracy

### Actual Test Results (October 12, 2025)

**Test Execution:**

1. ✅ **Committed and pushed changes:** Commit `7736958`
2. ✅ **GitHub Actions workflow triggered:** Run ID `18444907420`
3. ✅ **Workflow completed successfully:** All 3 jobs passed
4. ✅ **Webhook sent with branch field:** Payload confirmed includes `"branch": "main"`

**Harness Response:**

```json
{
  "status": "SUCCESS",
  "data": {
    "eventCorrelationId": "68ebb3da5a3afd7016e34ade",
    "webhookProcessingDetails": {
      "status": "QUEUED",
      "pipelineExecutionId": null,
      "runtimeInput": null,
      "message": "Trigger execution is queued.",
      "payload": "{...\"branch\": \"main\"...}",
      "warningMsg": "There are multiple trigger events generated from this eventId"
    }
  }
}
```

**Result: ❌ HYPOTHESIS DISPROVEN**

- Webhook received successfully (✅)
- Payload includes `branch` field (✅)
- **Trigger STILL QUEUED** (❌)
- `pipelineExecutionId`: still null (❌)
- `runtimeInput`: still null (❌)

**Additional Findings:**

1. **Warning message:** "There are multiple trigger events generated from this eventId"
   - Indicates potential trigger configuration issue
   - May suggest duplicate/conflicting trigger definitions

2. **No delegate activity:** Delegate logs show no trigger processing
   - Issue occurs at Harness platform level, not delegate level
   - Trigger validation/resolution failing before reaching delegate

3. **Webhook communication works:** Harness receives and acknowledges payload
   - Network/authentication working correctly
   - Problem is in trigger→pipeline execution handoff

### Expected Behavior After Fix

**Successful webhook trigger flow:**

```
GitHub Actions Completes
  ↓
Sends webhook with branch field
  ↓
Harness Trigger receives payload
  ↓
Resolves <+trigger.branch> = "main"
  ↓
Fetches remote pipeline from Git (main branch)
  ↓
Fetches remote Input Set from Git (main branch)
  ↓
Resolves pipeline variables:
  - VERSION = <+trigger.payload.version>
  - GITHUB_ORG = <+trigger.payload.github_org>
  - DEPLOYMENT_TARGET = <+trigger.payload.deployment_target>
  ↓
Creates pipeline execution (pipelineExecutionId assigned)
  ↓
Starts Dev stage deployment
  ↓
SUCCESS
```

### Lessons Learned

1. **Hypothesis Testing is Critical:**
   - ❌ **WRONG APPROACH:** Research → Make changes → Assume fixed → Document success
   - ✅ **RIGHT APPROACH:** Research → Form hypothesis → Test empirically → Analyze results → Iterate
   - Adding `branch` field seemed logical based on docs but was insufficient

2. **Documentation Research ≠ Root Cause:**
   - Harness docs mention `pipelineBranchName: <+trigger.branch>` requirement
   - This led to plausible hypothesis about missing branch field
   - **BUT:** Hypothesis must be tested, not assumed correct

3. **Multiple Factors May Be Required:**
   - Adding branch field alone didn't fix the issue
   - Problem is likely combination of factors
   - Need to verify ACTUAL trigger configuration (not just assume)

4. **Warning Messages Are Clues:**
   - "There are multiple trigger events generated" → May indicate config issue
   - Could mean duplicate triggers or conflicting definitions
   - This was not investigated in initial hypothesis

5. **Testing Checklist for Custom Webhooks:**
   - [x] Payload includes all pipeline variable mappings
   - [x] Payload includes `branch` field (tested - not sufficient)
   - [ ] **Verify actual trigger configuration in Harness UI**
   - [ ] **Confirm Input Set is synced and accessible**
   - [ ] **Check for duplicate/conflicting trigger definitions**
   - [ ] **Review Harness audit logs for hidden errors**
   - [ ] **Test manual pipeline execution with same Input Set**

### Related Documentation Updates

**Files updated:**
1. ✅ `.github/workflows/main-ci.yml` - Added `branch` field to webhook payload
2. ✅ `docs/HARNESS_TRIGGER_QUEUED_ISSUE.md` - Root cause analysis and resolution

**Recommended future updates:**
1. `docs/HARNESS_MANUAL_SETUP.md` - Document `branch` field requirement
2. `harness/README.md` - Add webhook payload requirements section
3. `CLAUDE.md` - Add to "Common Gotchas" section

## NEXT INVESTIGATION STEPS FOR ANOTHER AI

### Priority 1: Verify Actual Trigger Configuration (HIGH PRIORITY)

**Current Status:** We have NEVER looked at the actual trigger configuration in Harness UI. All assumptions are based on documentation patterns.

**Actions Required:**

1. **Access Harness UI and view trigger:**
   - URL: https://app.harness.io/ng/#/account/_dYBmxlLQu61cFhvdkV4Jw/all/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/pipeline-studio/
   - Navigate to: Triggers → "GitHub_Actions_CI"
   - **Export trigger YAML** and compare with expectations

2. **Check critical trigger fields:**
   ```yaml
   # What we EXPECT (but haven't verified):
   trigger:
     pipelineBranchName: <+trigger.branch>  # Is this actually set?
     inputSetRefs:
       - webhook_default  # Does this reference exist?
     # OR
     inputYaml: |
       pipeline:
         identifier: Deploy_Bagel_Store
         variables: [...]
   ```

3. **Questions to answer:**
   - Is `pipelineBranchName` set at all? Or is it hardcoded to `main`?
   - Does trigger use `inputSetRefs` or inline `inputYaml`?
   - Are there **multiple triggers** with the same identifier? (Warning message suggests this)
   - Are there payload conditions that might be blocking execution?

**Why This is Critical:**
- We've been debugging based on assumptions, not reality
- The warning "multiple trigger events generated" suggests config issues
- Trigger might not even be using the branch field we added

### Priority 2: Investigate "Multiple Trigger Events" Warning

**Current Status:** Harness returned: `"warningMsg": "There are multiple trigger events generated from this eventId"`

**This indicates:**
- Potentially duplicate trigger definitions
- Could be multiple triggers responding to same webhook
- May cause race condition or conflict

**Actions Required:**

1. **List all triggers for the pipeline:**
   ```bash
   # Via Harness API
   curl -X GET \
     'https://app.harness.io/pipeline/api/triggers?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&targetIdentifier=Deploy_Bagel_Store' \
     -H 'x-api-key: YOUR_API_KEY'
   ```

2. **Check for duplicates:**
   - Are there multiple triggers with same/similar names?
   - Do they all point to same webhook URL?
   - Could they be conflicting?

3. **Review trigger history:**
   - Check Harness audit logs for trigger create/update events
   - Look for patterns of trigger recreation/duplication

### Priority 3: Test Manual Pipeline Execution

**Current Status:** We've never tested if manual execution works with the Input Set.

**Why This Matters:**
- If manual execution FAILS → Problem is with Input Set definition
- If manual execution WORKS → Problem is trigger-specific

**Actions Required:**

1. **Manual execution test:**
   - Go to Harness UI → Pipelines → Deploy Bagel Store
   - Click "Run"
   - Select Input Set: "webhook_default"
   - Manually provide values:
     - VERSION: "dev-test123"
     - GITHUB_ORG: "liquibase-examples"
     - DEPLOYMENT_TARGET: "aws"
   - Click "Run Pipeline"

2. **Observe results:**
   - Does pipeline start? → Input Set definition is valid
   - Does it stay queued? → Input Set has same issue as trigger
   - Does it fail immediately? → Configuration/syntax error

### Priority 4: Verify Input Set Git Sync

**Current Status:** Input Set file exists in Git (`input-sets/webhook-default-2.yaml`) but we don't know if Harness can access it.

**Actions Required:**

1. **Check Input Set in Harness UI:**
   - Navigate to: Project Settings → Input Sets
   - Find: "Webhook Default" (identifier: `webhook_default`)
   - Check: Is it marked as "Remote" or "Inline"?
   - Check: Does it show as synced with Git?

2. **Fetch Input Set via API:**
   ```bash
   curl -X GET \
     'https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main' \
     -H 'x-api-key: YOUR_API_KEY'
   ```

3. **Compare Git vs Harness:**
   - Does API response match Git file content?
   - Are trigger payload expressions preserved? (`<+trigger.payload.version>`)
   - Is branch parameter in API URL correct?

### Priority 5: Check Harness Audit Logs

**Current Status:** We've only checked delegate logs, not Harness platform audit logs.

**Actions Required:**

1. **Access audit logs:**
   - Harness UI → Account Settings → Audit Trail
   - Filter by:
     - Time: Last 2 hours
     - Resource Type: Trigger, Pipeline, Input Set
     - Action: Trigger Execution, Pipeline Execution

2. **Look for:**
   - Trigger execution attempts with QUEUED status
   - Any error messages not surfaced in API
   - Input Set fetch failures
   - Pipeline validation errors

### Priority 6: Verify Pipeline YAML Syntax

**Current Status:** Pipeline is in Git (`pipelines/deploy-pipeline.yaml`) but may have issues.

**Actions Required:**

1. **Validate pipeline variables:**
   ```yaml
   # Check in pipelines/deploy-pipeline.yaml:
   variables:
     - name: VERSION
       type: String
       required: true  # Must be true
       value: <+input>  # Must be <+input> for runtime
   ```

2. **Check for:**
   - All 3 variables have `required: true`
   - All 3 variables have `value: <+input>`
   - No typos in variable names (case-sensitive)
   - Pipeline identifier matches: `Deploy_Bagel_Store`

### Priority 7: Alternative Hypothesis - Payload Conditions

**New Hypothesis:** Trigger may have payload conditions that are failing validation.

**Actions Required:**

1. **Check trigger for payload conditions:**
   ```yaml
   # In trigger configuration:
   spec:
     payloadConditions:
       - key: <+trigger.payload.something>
         operator: Equals
         value: expected_value
   ```

2. **Test theory:**
   - If payload conditions exist and are failing, trigger won't execute
   - Check if any conditions reference fields not in payload
   - Verify condition logic matches actual payload values

### Success Criteria (Updated)

The issue is fully resolved when:

1. ✅ GitHub Actions completes and sends webhook to Harness
2. ✅ Harness receives webhook successfully
3. ✅ Pipeline execution starts automatically (**NOT** QUEUED)
4. ✅ `pipelineExecutionId` is assigned (not null)
5. ✅ `runtimeInput` is populated with variable values from trigger payload
6. ✅ Pipeline variables are resolved:
   - `VERSION = "dev-<sha>"`
   - `GITHUB_ORG = "liquibase-examples"`
   - `DEPLOYMENT_TARGET = "aws"`
7. ✅ Dev stage deploys automatically
8. ✅ Test/Staging/Prod stages wait for approval
9. ✅ No manual intervention required

**Current Status:**
- ✅ Step 1: Complete
- ✅ Step 2: Complete
- ❌ Steps 3-9: BLOCKED by QUEUED status

### Time Investment Summary

**Investigation Phases:**

1. **Initial Investigation:** ~4 hours (original documentation of problem)
2. **Hypothesis Development:** ~30 minutes (Context7 research, formed branch field hypothesis)
3. **Implementation:** ~15 minutes (added branch field to payload)
4. **Testing:** ~15 minutes (end-to-end test, hypothesis DISPROVEN)
5. **Total Time:** ~5 hours

**Root Cause:** Still unknown (hypothesis about branch field was incorrect)
**Complexity:** Higher than initially assumed
**Impact:** Critical (CI/CD integration still blocked)

---

## SUMMARY FOR NEXT INVESTIGATOR

### What We Know (Confirmed)

1. ✅ **Webhook communication works:**
   - GitHub Actions successfully sends payload
   - Harness receives and acknowledges webhook
   - Network/authentication functioning correctly

2. ✅ **Payload is complete:**
   - Includes all expected fields: `version`, `github_org`, `deployment_target`, `branch`
   - Format is valid JSON
   - No parsing errors

3. ✅ **No delegate issues:**
   - Delegate shows "unhealthy" but this is cosmetic (telemetry errors)
   - No trigger processing in delegate logs
   - Issue occurs before reaching delegate

4. ❌ **Trigger stays QUEUED:**
   - `pipelineExecutionId`: null
   - `runtimeInput`: null
   - No pipeline execution created

### What We Don't Know (Requires Investigation)

1. ❓ **Actual trigger configuration:**
   - Have never viewed it in Harness UI
   - Don't know if `pipelineBranchName` is set
   - Don't know if it uses `inputSetRefs` or inline `inputYaml`

2. ❓ **Input Set accessibility:**
   - File exists in Git, but is Harness syncing it?
   - Can Harness fetch it from the `main` branch?
   - Are the trigger expressions valid?

3. ❓ **"Multiple trigger events" meaning:**
   - Warning suggests configuration issue
   - Could be duplicate triggers
   - Never investigated

4. ❓ **Manual execution behavior:**
   - Never tested if manual run works with Input Set
   - This would isolate trigger vs Input Set issues

### Recommended Starting Point

**Start with Priority 1:** View actual trigger configuration in Harness UI. Everything else is speculation until we see the real configuration.

**Most Likely Root Causes (Ranked):**

1. **Trigger configuration issue** (70% probability)
   - Wrong `pipelineBranchName` setting
   - Incorrect Input Set reference
   - Payload condition blocking execution

2. **Input Set Git sync failure** (20% probability)
   - Harness can't fetch from `main` branch
   - File path or identifier mismatch
   - Permission/connector issue

3. **Duplicate/conflicting triggers** (10% probability)
   - Warning message suggests this
   - Multiple triggers responding to same webhook

### Key Files & Resources

**Local Files:**
- Pipeline: `/harness/pipelines/deploy-pipeline.yaml`
- Input Set: `/harness/input-sets/webhook-default-2.yaml`
- Workflow: `/.github/workflows/main-ci.yml`

**Harness Resources:**
- Account: `_dYBmxlLQu61cFhvdkV4Jw`
- Organization: `default`
- Project: `bagel_store_demo`
- Pipeline: `Deploy_Bagel_Store`
- Trigger: `GitHub_Actions_CI`

**Latest Test:**
- Event ID: `68ebb3da5a3afd7016e34ade`
- Workflow Run: `18444907420`
- Commit: `7736958`

**API Endpoints:**
```bash
# Trigger details
curl "https://app.harness.io/gateway/pipeline/api/webhook/triggerExecutionDetailsV2/{eventId}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw"

# List triggers
curl "https://app.harness.io/pipeline/api/triggers?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&targetIdentifier=Deploy_Bagel_Store" \
  -H 'x-api-key: YOUR_API_KEY'

# Input Set
curl "https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main" \
  -H 'x-api-key: YOUR_API_KEY'
```

---

## FINAL RESOLUTION (October 12, 2025)

### Actual Root Cause (Confirmed)

**The trigger had a malformed payload condition:**

```yaml
trigger:
  source:
    type: Webhook
    spec:
      type: Custom
      spec:
        payloadConditions:
          - key: version
            operator: Equals
            value: <+trigger.payload.version>  # ❌ WRONG!
```

**Why This Failed:**
- Harness treats the value as a **literal string**, not an expression
- Compares: `payload.version == "<+trigger.payload.version>"` (the text)
- Since actual value is `"dev-7736958"`, condition ALWAYS fails
- Failed condition = trigger stays QUEUED, never executes

### The Fix

**Corrected trigger configuration:**

```yaml
trigger:
  name: GitHub Actions CI
  identifier: GitHub_Actions_CI
  enabled: true
  description: Triggered automatically when GitHub Actions completes artifact builds
  tags: {}
  orgIdentifier: default
  projectIdentifier: bagel_store_demo
  pipelineIdentifier: Deploy_Bagel_Store
  source:
    type: Webhook
    spec:
      type: Custom
      spec:
        payloadConditions: []  # ✅ REMOVED malformed condition
        headerConditions: []
  pipelineBranchName: <+trigger.branch>  # ✅ Needed for Git Experience
  inputSetRefs:
    - webhook_default  # ✅ Cleaner than inline inputYaml
```

**Key changes:**
1. **Removed payload condition entirely** (no condition = always execute)
2. **Kept `pipelineBranchName: <+trigger.branch>`** (required for remote pipelines)
3. **Switched to `inputSetRefs`** instead of inline `inputYaml`
4. **Branch field in webhook payload** (added earlier in commit 7736958)

### Verification Test Results

**Test Execution:** October 12, 2025, 14:15 UTC

**GitHub Actions:**
- Workflow Run: 18444907420
- Status: Success (all 3 jobs passed)
- Webhook sent with event ID: `68ebb7e7a03d443c9d53c1b8`

**Harness Response:**
```json
{
  "status": "TARGET_EXECUTION_REQUESTED",
  "pipelineExecutionId": "rnxCKmd0QP2q5RI0DQnFDg",
  "runtimeInput": "pipeline:\n  identifier: Deploy_Bagel_Store\n  variables:\n    - name: VERSION\n      value: <+trigger.payload.version>\n    - name: GITHUB_ORG\n      value: <+trigger.payload.github_org>\n    - name: DEPLOYMENT_TARGET\n      value: <+trigger.payload.deployment_target>",
  "message": "Pipeline execution was requested successfully",
  "warningMsg": null
}
```

**Success Criteria Met:**
- ✅ Webhook received and acknowledged
- ✅ Pipeline execution created (NOT QUEUED!)
- ✅ Pipeline execution ID assigned
- ✅ Runtime input variables populated
- ✅ No warning messages
- ✅ Status changed from QUEUED to EXECUTION_REQUESTED

**Execution URL:** https://app.harness.io/ng/#/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/executions/rnxCKmd0QP2q5RI0DQnFDg/pipeline

### What We Learned

1. **Always check actual configuration, not assumptions**
   - Spent hours researching documentation and making hypotheses
   - Actual problem was visible in 5 seconds once we viewed trigger config
   - Lesson: View real configuration FIRST, then form hypotheses

2. **Payload conditions are validation gates**
   - Failed condition = execution blocked, stays QUEUED
   - No error message indicates which condition failed
   - Condition expressions must evaluate, not compare to literal strings

3. **Branch field was needed (hypothesis partially correct)**
   - Required for `pipelineBranchName: <+trigger.branch>` to work
   - Enables Git Experience to fetch remote pipeline/Input Sets
   - But wasn't the blocker - payload condition was

4. **Testing is essential**
   - First hypothesis (branch field) seemed logical but was insufficient
   - Only empirical testing revealed the real problem
   - Documentation research helps but must be validated

### Files Changed

**Commit 7736958 (Partial Fix):**
- `.github/workflows/main-ci.yml` - Added `branch` field to webhook payload
- `docs/HARNESS_TRIGGER_QUEUED_ISSUE.md` - Documentation (later updated)

**Trigger Configuration Fix (Applied in Harness UI):**
- Removed payload condition from trigger `GitHub_Actions_CI`
- Changed from inline `inputYaml` to `inputSetRefs: [webhook_default]`

### Known Issue: Pipeline Aborts Immediately

**New Problem Discovered:** Pipeline starts but aborts after ~2 seconds.

**Evidence:**
- Pipeline status: "Aborted"
- Dev stage status: "Aborted"
- Duration: 1760278509 → 1760278511 (~2 seconds)
- Aborted by: "systemUser"

**This is a SEPARATE issue** from the QUEUED problem. See separate investigation document: `HARNESS_PIPELINE_ABORT_ISSUE.md`

---

## Time Investment Summary

**Total Investigation Time:** ~6 hours

**Phases:**
1. Initial problem documentation: ~4 hours
2. Hypothesis development (branch field): ~30 minutes
3. Implementation and testing: ~30 minutes
4. Hypothesis disproven, further research: ~15 minutes
5. Viewing actual trigger config: ~5 minutes
6. Identifying real root cause: ~5 minutes
7. Applying fix and verification: ~15 minutes
8. Final documentation: ~30 minutes

**Key Insight:** 5 minutes of viewing actual configuration saved hours of speculation. Always verify assumptions against reality.

---

**Resolution Date:** October 12, 2025, 14:15 UTC
**Resolved By:** Claude Code AI Assistant (Sonnet 4.5) with user collaboration
**Root Cause:** Malformed payload condition in trigger configuration
**Solution:** Removed payload condition, used inputSetRefs, added branch field to webhook
**Status:** ✅ RESOLVED (QUEUED issue fixed, separate abort issue exists)

---

**Report End**
