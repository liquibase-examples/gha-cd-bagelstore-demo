# Harness CustomDeployment Template Guide

## Critical Limitation: Cannot Store in Git

**IMPORTANT:** Harness Git Experience does NOT support CustomDeployment templates (only StepGroup templates).

**Error when attempting Git import:**
```
Invalid request: Template of type [CustomDeployment] cannot be imported from git.
Please create the template manually.
```

## Template Structure - Required Fields

All CustomDeployment templates MUST include these sections or validation will fail:

### 1. Instance Attributes (MANDATORY Field Name)

```yaml
instanceAttributes:
  - name: instancename          # ← MUST be exactly "instancename"
    jsonPath: instance
    description: ""
```

**Critical Requirement:**
- Field name MUST be `instancename` (not `hostname`, `instance`, `server`, etc.)
- This is a hard-coded Harness requirement
- Error if wrong: "instancename value in the Field Name setting is mandatory"

**Source:** [Harness Developer Hub - Custom Deployments](https://developer.harness.io/docs/continuous-delivery/deploy-srv-diff-platforms/custom/custom-deployment-tutorial/)

### 2. Instances List Path

```yaml
instancesListPath: instances    # JSON path to array in fetchInstancesScript output
```

Points to the array in your script's JSON output. For example:
- Script outputs: `{"instances": [...]}`
- Set: `instancesListPath: instances`

### 3. Execution Section

```yaml
execution:
  stepTemplateRefs: []          # Can be empty but MUST exist
```

Required section even if empty. References step templates for deployment logic.

## Complete Minimal Template Example

This template satisfies all validation requirements:

```yaml
template:
  name: Custom Deployment
  identifier: Custom
  versionLabel: "1.0"
  type: CustomDeployment
  projectIdentifier: bagel_store_demo
  orgIdentifier: default
  spec:
    infrastructure:
      variables: []
      fetchInstancesScript:
        store:
          type: Inline
          spec:
            content: |
              #!/bin/bash
              echo '{"instances": []}'
      instanceAttributes:
        - name: instancename
          jsonPath: instance
          description: ""
      instancesListPath: instances
    execution:
      stepTemplateRefs: []
```

## Manual Creation Process

1. **Navigate to Harness UI:** Project Setup → Templates → + New Template
2. **Select:** Custom Deployment
3. **Switch to YAML view**
4. **Paste the complete template YAML** (all required fields)
5. **Save**

## This Repository's Pattern

**Two Template Types:**

1. **CustomDeployment Template** (`Custom` v1.0):
   - **Purpose:** Infrastructure validation placeholder
   - **Creation:** Manual in Harness UI (cannot be in Git)
   - **Location (reference only):** `.harness/.../templates/Custom/v1_0.yaml`
   - **Content:** Minimal - satisfies validation requirements

2. **StepGroup Template** (`Coordinated_DB_App_Deployment` v1.0):
   - **Purpose:** Actual deployment logic
   - **Creation:** Stored in Git, auto-syncs to Harness
   - **Location:** `.harness/.../templates/Coordinated_DB_App_Deployment/v1_0.yaml`
   - **Content:** All deployment steps (fetch artifacts, DB update, app deployment, health check)

## Why This Pattern?

**Requirement:** Harness CustomDeployment infrastructure definitions MUST reference a deployment template via `customDeploymentRef.templateRef`.

**Our Solution:**
- Minimal CustomDeployment template (`Custom`) satisfies validation
- Actual deployment logic lives in StepGroup template
- Keeps logic centralized and version-controlled in Git

**Trade-offs:**
- ✅ Single source of truth for deployment logic (Git)
- ✅ Terraform-friendly infrastructure definitions
- ✅ Satisfies Harness validation requirements
- ⚠️ Non-standard pattern (not in official Harness docs)
- ⚠️ CustomDeployment template must be manually recreated if deleted

## Common Errors

### Error: "instancename value in the Field Name setting is mandatory"

**Cause:** Using wrong field name in `instanceAttributes.name`

**Fix:** Change to exactly `instancename`:
```yaml
instanceAttributes:
  - name: instancename    # ← Must be this exact string
```

### Error: "Missing property 'execution'"

**Cause:** Missing `execution` section

**Fix:** Add the section (can be empty):
```yaml
execution:
  stepTemplateRefs: []
```

### Error: "Missing property 'instancesListPath'"

**Cause:** Missing `instancesListPath` field

**Fix:** Add under `infrastructure` (not under `fetchInstancesScript`):
```yaml
spec:
  infrastructure:
    fetchInstancesScript: {...}
    instancesListPath: instances    # ← Add here
```

## Verification

After creating the template manually:

**Check in Harness UI:**
- Navigate to: Project Setup → Templates
- Verify you see: **Custom Deployment** (1.0) with type **Custom Deployment**

**Verify infrastructure definitions reference it:**
```bash
curl -s "https://app.harness.io/gateway/ng/api/infrastructures/psr_dev_infra?..." \
  -H "x-api-key: ${HARNESS_API_KEY}" | \
  jq -r '.data.infrastructure.yaml' | grep -A 2 "customDeploymentRef"
```

Expected:
```yaml
customDeploymentRef:
  templateRef: Custom
  versionLabel: "1.0"
```

## Historical Context

**Problem:** Pipeline failed with `INVALID_REQUEST` at Infrastructure step

**Root Cause:** Infrastructure definitions had `templateRef: ""` (empty string)

**Research Findings (4 independent AI agents):**
- CustomDeployment type REQUIRES valid templateRef
- Empty string is invalid (fails validation)
- All official Harness docs show populated templateRef
- The "Custom" template never existed historically (was always a mistake)

**Solution:** Create minimal CustomDeployment template to satisfy validation while keeping deployment logic in StepGroup template.

**Date Fixed:** 2025-10-18
