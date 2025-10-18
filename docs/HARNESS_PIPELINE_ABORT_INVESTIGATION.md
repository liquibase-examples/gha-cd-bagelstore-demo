# Harness Pipeline Abort Investigation Report

**Execution ID**: `rnxCKmd0QP2q5RI0DQnFDg`
**Pipeline**: `Deploy_Bagel_Store`
**Status**: Aborted after ~2 seconds
**Investigation Date**: 2025-10-12

## Summary

Pipeline execution aborted immediately (within 2 seconds) before any tasks reached the delegate. Investigation revealed **three critical configuration mismatches** causing the pipeline to fail during initialization.

## Root Causes Identified

### 1. ❌ **Missing GitHub Container Registry Connector**

**Issue**: Pipeline references a non-existent connector.

**Evidence**:
- Pipeline YAML (`harness/pipelines/deploy-pipeline.yaml:60`) references:
  ```yaml
  connectorRef: github_container_registry
  ```
- Actual connector in Harness: `github_bagel_store`
- Result: Harness cannot resolve artifact source, aborts pipeline

**Fix Required**:
```yaml
# Change line 60 in harness/pipelines/deploy-pipeline.yaml
connectorRef: github_bagel_store  # Was: github_container_registry
```

### 2. ❌ **Environment Identifier Mismatch**

**Issue**: Pipeline expects different environment identifiers than what exists in Harness.

**Evidence**:
- Pipeline expects: `dev`, `test`, `staging`, `prod`
- Harness has: `psr_dev`, `psr_test`, `psr_staging`, `psr_prod`
- Result: Cannot resolve environment references, pipeline aborts

**Current State**:
```bash
$ curl https://app.harness.io/ng/api/environmentsV2?... | jq '.data.content[].environment.identifier'
"psr_prod"
"psr_test"
"psr_staging"
"psr_dev"
```

**Fix Options**:

**Option A**: Update pipeline to match existing environments (minimal change):
```yaml
# In harness/pipelines/deploy-pipeline.yaml, update all environment references:
environmentRef: psr_dev     # Line 66 (was: dev)
environmentRef: psr_test    # Line 113 (was: test)
environmentRef: psr_staging # Line 173 (was: staging)
environmentRef: psr_prod    # Line 234 (was: prod)
```

**Option B**: Rename environments in Harness to match pipeline (cleaner identifiers):
- Rename via Harness UI or API:
  - `psr_dev` → `dev`
  - `psr_test` → `test`
  - `psr_staging` → `staging`
  - `psr_prod` → `prod`

### 3. ❌ **Missing Step Group Template**

**Issue**: Pipeline references a template that doesn't exist in Harness.

**Evidence**:
- Pipeline references (lines 77-79, 139-142, 199-202, 259-262):
  ```yaml
  template:
    templateRef: Coordinated_DB_App_Deployment
    versionLabel: v1.0
  ```
- API check shows: **0 templates** in project
- Template file exists in Git: `harness/templates/deployment-steps.yaml`
- Result: Harness cannot load template, pipeline initialization fails

**Fix Required**:

Follow [docs/HARNESS_MANUAL_SETUP.md](HARNESS_MANUAL_SETUP.md) to create the template:

1. Navigate to: **Project Settings** → **Templates** → **+ New Template**
2. Select: **Step Group Template**
3. Configure:
   - **Name**: `Coordinated DB and App Deployment`
   - **Version Label**: `v1.0`
   - **Git Experience**: Enable "Use Git"
   - **Connector**: Select `github_bagel_store`
   - **Repository**: `harness-gha-bagelstore`
   - **Git Branch**: `main`
   - **YAML Path**: `harness/templates/deployment-steps.yaml`
4. Save template

## Execution Timeline

```
1760278508424 - Pipeline execution starts
1760278509267 - Pipeline created
1760278509451 - Dev stage created
1760278509491 - Dev stage starts
1760278511192 - Dev stage aborts (~1.7 seconds)
1760278511338 - Pipeline aborts
1760278511019 - Aborted by: systemUser
```

**Duration**: ~2 seconds from start to abort

## Why Abort Happened Before Delegate

The pipeline failed during the **initialization phase** where Harness:
1. Resolves pipeline YAML from Git ✅
2. Resolves Input Set variables ✅ (webhook payload successfully parsed)
3. **Resolves connectors** ❌ (github_container_registry not found)
4. **Resolves environments** ❌ (dev/test/staging/prod not found)
5. **Loads templates** ❌ (Coordinated_DB_App_Deployment not found)
6. Assigns tasks to delegate ⏸️ (never reached this step)

Since initialization failed, no tasks were ever created for the delegate, explaining why delegate logs show only heartbeats.

## Verification Steps

After applying fixes, verify resources:

```bash
# Run resource check script
./scripts/check-harness-resources.sh

# Expected output:
# Connectors: github_bagel_store ✅
# Environments: dev, test, staging, prod ✅
# Templates: Coordinated_DB_App_Deployment v1.0 ✅
# Secrets: github_pat, aws_*, liquibase_license_key ✅
```

## API Investigation Commands

Commands used during investigation:

```bash
# Get execution details
source harness/.env
curl -X GET \
  "https://app.harness.io/pipeline/api/pipelines/execution/v2/${EXECUTION_ID}?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" \
  -H "x-api-key: ${HARNESS_API_KEY}"

# Check Input Set
curl -X GET \
  "https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store" \
  -H "x-api-key: ${HARNESS_API_KEY}"

# List all resources
./scripts/check-harness-resources.sh
```

## Input Set Variable Resolution (Working Correctly)

The Input Set successfully resolved webhook payload variables:

```yaml
variables:
  - name: VERSION
    value: <+trigger.payload.version>     # Resolved to: "dev-7736958"
  - name: GITHUB_ORG
    value: <+trigger.payload.github_org>  # Resolved to: "liquibase-examples"
  - name: DEPLOYMENT_TARGET
    value: <+trigger.payload.deployment_target>  # Resolved to: "aws"
```

This confirms the webhook trigger is working correctly. The issue is **not** with variable resolution.

## Recommended Fix Order

1. **Create Step Group Template** (5 minutes)
   - Follow HARNESS_MANUAL_SETUP.md
   - Enables GitOps for template changes

2. **Fix Connector Reference** (1 minute)
   - Edit `harness/pipelines/deploy-pipeline.yaml`
   - Change `github_container_registry` → `github_bagel_store`
   - Commit and push

3. **Fix Environment References** (Choose one):
   - **Option A** (faster): Update pipeline YAML to use `psr_dev`, `psr_test`, `psr_staging`, `psr_prod`
   - **Option B** (cleaner): Rename environments in Harness to `dev`, `test`, `staging`, `prod`

4. **Test Execution**
   - Trigger webhook from GitHub Actions
   - Monitor: https://app.harness.io/ng/#/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/executions

## Related Documentation

- [docs/HARNESS_MANUAL_SETUP.md](HARNESS_MANUAL_SETUP.md) - Template and pipeline setup
- [harness/README.md](../harness/README.md) - Harness configuration overview
- [docs/HARNESS_TRIGGER_QUEUED_ISSUE.md](HARNESS_TRIGGER_QUEUED_ISSUE.md) - Previous webhook trigger fix

## Key Learnings

1. **Delegate logs ≠ pipeline failures**: If pipeline aborts before 5 seconds, check initialization (connectors, environments, templates)
2. **systemUser abort = configuration error**: When "systemUser" aborts a pipeline, it's usually a validation/initialization failure
3. **Use API for investigation**: Harness API provides detailed execution data when UI is not accessible
4. **Resource naming consistency matters**: Identifiers in YAML must exactly match Harness resource identifiers
5. **Terraform + Manual hybrid requires setup**: Git-backed templates must be created manually (one-time setup)

## Status

✅ Investigation complete
⏳ Fixes pending
📝 Documentation updated
