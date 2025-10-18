# AI Handoff Prompt

**Date:** 2025-10-18
**Session:** Harness Pipeline `INVALID_REQUEST` Error Resolution
**Status:** ✅ Core issue RESOLVED, delegate needed for full deployment

---

## Current State Summary

### ✅ COMPLETED: Infrastructure Step Validation Fixed

**Problem:** Harness pipeline failed at Infrastructure step with `INVALID_REQUEST` error

**Root Cause:** Infrastructure definitions had empty `templateRef: ""` which is invalid for CustomDeployment type

**Solution Implemented:**
1. Created minimal CustomDeployment template (`Custom` v1.0) manually in Harness UI
2. Updated all 4 infrastructure definitions to reference `templateRef: Custom`
3. Updated Terraform configuration to match
4. Created comprehensive documentation

**Verification:**
- Pipeline execution `m8JtF_47TL6hc-FbC5TyWg` successfully passed Infrastructure step
- Infrastructure validation: ✅ SUCCESS (was failing before)

### ⚠️ NEXT ISSUE: No Delegate Running

**Current Pipeline Status:**
- Service Step: ✅ Passed
- Infrastructure Step: ✅ Passed (THIS WAS THE FIX)
- Execution Steps: ❌ Aborted - "No eligible delegates available"

**Reason:** Harness delegate is not running (expected, separate from original issue)

---

## What You're Picking Up

### Immediate Next Step

**Start the Harness delegate to enable full deployment:**

```bash
cd /Users/recampbell/workspace/harness-gha-bagelstore/harness
docker compose up -d
```

**Verify delegate connection:**
1. Check Harness UI: Project Settings → Delegates
2. Look for: "Connected" status + recent heartbeat (<1 min)
3. Note: Delegate logs may show errors (Stackdriver, telemetry) - these are non-fatal if UI shows "Connected"

**Then retrigger pipeline:**
```bash
gh run rerun $(gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

---

## Critical Context

### Repository Pattern: Minimal CustomDeployment Template

**IMPORTANT:** This repo uses a non-standard but validated pattern:

1. **CustomDeployment Template** (`Custom` v1.0):
   - Purpose: Infrastructure validation placeholder only
   - Location: Created manually in Harness UI (CANNOT be in Git)
   - Reference file: `.harness/.../templates/Custom/v1_0.yaml` (documentation only)

2. **StepGroup Template** (`Coordinated_DB_App_Deployment` v1.0):
   - Purpose: Actual deployment logic
   - Location: `.harness/.../templates/Coordinated_DB_App_Deployment/v1_0.yaml` (in Git)
   - Content: All deployment steps (fetch artifacts, DB update, app deployment, health check)

**Why:** Harness requires CustomDeployment infrastructure to reference a deployment template, but we keep logic in StepGroup for centralization.

### Key Files Created This Session

**Documentation:**
- `docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md` - Complete CustomDeployment template guide
- `docs/HARNESS_API_WORKFLOWS.md` - API commands for pipeline monitoring
- `CLAUDE.md` - Updated with documentation references

**Code:**
- `.harness/.../templates/Custom/v1_0.yaml` - Template reference (manual in UI)
- 4 infrastructure YAMLs updated with `templateRef: Custom`
- `terraform/harness-infrastructure-definitions.tf` - Updated comments and templateRef

---

## Documentation to Read

**Before working on specific areas, read the relevant docs:**

### Harness-Related Issues

1. **CustomDeployment template problems** → Read `docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md`
   - Required fields: `instancename`, `instancesListPath`, `execution`
   - Manual creation process
   - Common errors (`INVALID_REQUEST` at Infrastructure step)

2. **Pipeline debugging** → Read `docs/HARNESS_API_WORKFLOWS.md`
   - Getting execution details via API
   - Finding failed steps
   - Common error patterns

3. **Delegate issues** → Read `harness/README.md`
   - Delegate setup and troubleshooting
   - Verifying connectivity
   - Understanding non-fatal errors

4. **General troubleshooting** → Read `docs/TROUBLESHOOTING.md`
   - Diagnostic scripts
   - Common errors
   - Solutions

### Project-Specific Patterns

- **Read `CLAUDE.md` first** - Project conventions and AI guidance
- **Check "AI Documentation Reference Rules"** (CLAUDE.md line 207+) - When to read specific docs
- **Use API-first approach** (CLAUDE.md line 59+) - Always use API before suggesting UI changes

---

## Common Gotchas to Avoid

### 1. Environment Variable Reading

**ALWAYS read harness/.env file first before using variables:**

```bash
# ✅ CORRECT
Read harness/.env  # See the value
# Then use directly:
curl ... -H "x-api-key: pat._dYBmxlLQu61cFhvdkV4Jw..."

# ❌ WRONG (fails with "blank argument")
source harness/.env && curl ... -H "x-api-key: ${HARNESS_API_KEY}"
```

### 2. CustomDeployment Templates Cannot Be in Git

**Do NOT try to import CustomDeployment templates from Git:**
- Error: "Template of type [CustomDeployment] cannot be imported from git"
- Solution: Create manually in Harness UI
- StepGroup templates CAN be in Git (like `Coordinated_DB_App_Deployment`)

### 3. Delegate Logs Show Errors But Delegate Works

**Pattern:** Delegate showing `remote-stackdriver-log-submitter` errors while showing "Connected" in UI = **working fine**

**Verify delegate status in UI, not just logs:**
- UI: Project Settings → Delegates → Look for "Connected" + recent heartbeat
- Logs are not reliable for determining actual status

### 4. Use API for Diagnostics

**Don't rely on UI screenshots - use API:**

```bash
# Get latest execution
source harness/.env
curl -s -X POST "https://app.harness.io/pipeline/api/pipelines/execution/summary?..." \
  -d '{"pipelineIdentifier":"Deploy_Bagel_Store","filterType":"PipelineExecution"}' | \
  jq '.data.content[0].planExecutionId'

# Get detailed errors
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/{EXECUTION_ID}?..." | \
  jq '.data.executionGraph.nodeMap | to_entries[] | select(.value.status == "Failed")'
```

See `docs/HARNESS_API_WORKFLOWS.md` for complete API reference.

---

## Expected Next Steps

### 1. Start Delegate (Immediate)

```bash
cd harness && docker compose up -d
docker compose logs -f  # Monitor logs
```

Verify in Harness UI: Project Settings → Delegates → "Connected"

### 2. Trigger Full Deployment

```bash
gh run rerun $(gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

### 3. Monitor Pipeline Execution

**Get execution ID:**
```bash
source harness/.env
curl -s -X POST "https://app.harness.io/pipeline/api/pipelines/execution/summary?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"pipelineIdentifier":"Deploy_Bagel_Store","filterType":"PipelineExecution"}' | \
  jq '.data.content[0].planExecutionId'
```

**Check for failures:**
```bash
EXECUTION_ID="..."  # From above
curl -s "https://app.harness.io/pipeline/api/pipelines/execution/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq '.data.executionGraph.nodeMap | to_entries[] | select(.value.status == "Failed" or .value.status == "Aborted") | {step: .value.name, error: .value.failureInfo.message}'
```

### 4. Expected Result

**Successful deployment should:**
- ✅ Pass Service step (artifact resolution)
- ✅ Pass Infrastructure step (validation)
- ✅ Execute deployment steps:
  1. Fetch Changelog Artifact
  2. Update Database (Liquibase)
  3. Deploy Application (AWS App Runner or local Docker)
  4. Health Check
  5. Fetch Instances
- ✅ Complete with status "Success"

---

## Quick Reference

### Key Identifiers

- **Account ID:** `_dYBmxlLQu61cFhvdkV4Jw`
- **Organization:** `default`
- **Project:** `bagel_store_demo`
- **Pipeline:** `Deploy_Bagel_Store`
- **Demo ID:** `psr`

### Repository Location

```
/Users/recampbell/workspace/harness-gha-bagelstore/
```

### Authentication

API key stored in: `harness/.env` (gitignored)

```bash
source harness/.env  # Loads HARNESS_API_KEY
```

### Diagnostic Scripts

```bash
./scripts/verify-harness-entities.sh    # Verify all resources exist
./scripts/get-pipeline-executions.sh    # Query pipeline history
./scripts/update-trigger.sh             # Update trigger configuration
```

---

## Research Findings from This Session

### Multi-Agent Research (4 parallel agents)

**Question:** Why `INVALID_REQUEST` at Infrastructure step?

**Unanimous Finding:**
- CustomDeployment type REQUIRES valid templateRef
- Empty string `""` is INVALID (fails validation)
- All official Harness docs show populated templateRef
- Solution: Create minimal template with required fields

**Required Fields Discovered:**
1. `instanceAttributes.name: instancename` (MUST be exactly "instancename")
2. `instancesListPath: instances` (JSON path to array)
3. `execution.stepTemplateRefs: []` (can be empty but must exist)

**Source:** [Harness Developer Hub](https://developer.harness.io/docs/continuous-delivery/deploy-srv-diff-platforms/custom/custom-deployment-tutorial/)

---

## Success Criteria

✅ **Core Issue (Fixed):**
- Infrastructure step passes validation
- No more `INVALID_REQUEST` error

⏭️ **Next Milestone:**
- Delegate running and connected
- Full deployment completes successfully
- Application deployed to dev environment
- Health check passes

---

## If You Get Stuck

1. **Read CLAUDE.md** - Project conventions and patterns
2. **Check documentation references** - CLAUDE.md line 207+ tells you which docs to read
3. **Use diagnostic scripts** - `./scripts/verify-harness-entities.sh` and others
4. **Check API for detailed errors** - See `docs/HARNESS_API_WORKFLOWS.md`
5. **Review recent commits** - Last 3 commits contain the fix context

---

## Summary

**What was accomplished:**
- ✅ Diagnosed and fixed `INVALID_REQUEST` at Infrastructure step
- ✅ Created CustomDeployment template with all required fields
- ✅ Updated infrastructure definitions and Terraform
- ✅ Created comprehensive documentation
- ✅ Verified fix via pipeline execution

**Current state:**
- Infrastructure validation: ✅ Working
- Delegate: ❌ Not running (expected)
- Next step: Start delegate and complete full deployment

**You're inheriting:**
- A working Infrastructure step validation
- Complete documentation in `docs/`
- Clear next steps (start delegate, trigger pipeline)
- API workflows for monitoring

Good luck! 🚀
