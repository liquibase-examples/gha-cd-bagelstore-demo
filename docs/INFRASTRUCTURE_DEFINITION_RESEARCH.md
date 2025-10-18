# Infrastructure Definition Research Report

**Problem**: Pipeline consistently aborts with "Invalid request: infrastructure definition reference is not specified"
**Date**: 2025-10-12
**Status**: ✅ ROOT CAUSE IDENTIFIED

---

## Executive Summary

After 4 failed commit attempts and deep research into Harness CustomDeployment requirements, the root cause has been identified:

**CustomDeployment requires infrastructure definitions to exist in the environment, even when using `deployToAll: true`.**

The current setup creates **ZERO infrastructure definitions** (neither in Terraform nor manually), which is why the pipeline cannot find any infrastructure to deploy to.

---

## What We Tried (4 Commits)

All attempted fixes focused on the **pipeline YAML**, but the issue is **missing infrastructure resources**:

1. ✅ **Commit f54d1b2**: Fixed connector reference (`github_container_registry` → `github_bagel_store`)
2. ✅ **Commit 50444e8**: Fixed environment references (`dev` → `psr_dev` for all 4 stages)
3. ❌ **Commit 9afacde**: Removed `infrastructureDefinitions` blocks (made it worse!)
4. ❌ **Commit e50f123**: Changed `deployToAll: false` → `deployToAll: true` (didn't help)

**Result**: All commits were valid syntax changes, but didn't solve the underlying problem.

---

## Root Cause Analysis

### 1. Understanding `deployToAll: true`

From Harness documentation:

> **`deployToAll` does NOT mean "bypass infrastructure definitions"**
> **It means: "deploy to ALL infrastructure definitions in this environment"**

If the environment has **zero infrastructure definitions**, then `deployToAll: true` has **nothing to deploy to**.

**Analogy**:
```
deployToAll: true = "FOR EACH infra IN environment.infrastructures: deploy(infra)"

If environment.infrastructures = [] (empty list)
Then: No iterations, no deployment, error: "infrastructure definition reference is not specified"
```

### 2. CustomDeployment Architecture Requirements

From Harness Developer Hub documentation on CustomDeployment:

> "In your Harness Pipeline stage Environment, **create a Harness Infrastructure Definition** that uses the Deployment Template."

**Key Requirements**:
1. **Deployment Template** (Custom): Defines HOW to deploy (fetch instances, execute steps)
2. **Infrastructure Definition**: Defines WHERE to deploy (references the template, provides variables)
3. **Environment**: Container for infrastructure definitions
4. **Pipeline Stage**: References environment + infrastructure definitions

**Current State vs. Required State**:

| Resource Type | Current | Required | Status |
|--------------|---------|----------|--------|
| Deployment Template | ✅ Defined in service | ✅ Required | ✅ EXISTS |
| Infrastructure Definitions | ❌ 0 created | ✅ 4 required (dev/test/staging/prod) | ❌ MISSING |
| Environments | ✅ 4 created (psr_dev, psr_test, etc.) | ✅ Required | ✅ EXISTS |
| Pipeline Stages | ✅ 4 stages | ✅ Required | ✅ EXISTS |

### 3. Why Terraform Didn't Create Infrastructure Definitions

From Harness documentation (Context7 research):

**Infrastructure definitions are separate resources from environments.**

**Evidence from our Terraform**:

**File: `terraform/harness-environments.tf`**
```hcl
resource "harness_platform_environment" "demo_environments" {
  for_each = local.harness_environments

  identifier = each.value.identifier
  name       = each.value.name
  # ... creates environment with VARIABLES
  # ... but NO infrastructure definitions!
}
```

**Search results**:
```bash
$ grep -r "harness_platform_infrastructure" terraform/
# (no results - resource type not used)
```

**Why?**
- Terraform creates **environments** (containers)
- But does NOT create **infrastructure definitions** (deployment targets within environments)
- This was likely an oversight in the Terraform design

### 4. Comparison with Other Deployment Types

**For Kubernetes deployments**, infrastructure definitions specify:
- Connector reference (which K8s cluster)
- Namespace
- Release name

**For CustomDeployment**, infrastructure definitions specify:
- Reference to Custom Deployment Template
- Template version
- Custom variables (optional)

**Example from Harness docs** (Salesforce CustomDeployment):
```yaml
infrastructureDefinition:
  name: SalesForceDevSandbox
  identifier: SalesForceDevSandbox
  environmentRef: dev
  deploymentType: CustomDeployment
  type: CustomDeployment
  spec:
    customDeploymentRef:
      templateRef: account.Salesforce
      versionLabel: v1
    variables: []
  allowSimultaneousDeployments: false
```

**For our use case**, we need similar infrastructure definitions that reference our Custom template.

---

## Why Remote Pipelines Don't Change the Requirement

**Question**: "Does storing the pipeline in Git change infrastructure requirements?"

**Answer**: No. Remote vs. inline storage affects:
- ✅ Where pipeline YAML is stored (Git vs. Harness DB)
- ✅ How changes are versioned (Git commits vs. Harness revisions)
- ❌ Infrastructure definition requirements (same for both)

**From Harness release notes** (Context7 research):
> "Git import APIs for pipelines, templates, input sets, services, environments, **infrastructure definitions**, and service overrides now require RepoName, FilePath, and ConnectorRef parameters."

Infrastructure definitions are **independent resources** that can also be stored in Git, but they must exist regardless of pipeline storage location.

---

## Why Service Definition Alone Is Not Enough

**File: `terraform/harness-service.tf`**
```hcl
resource "harness_platform_service" "bagel_store" {
  yaml = <<-EOT
    service:
      serviceDefinition:
        type: CustomDeployment
        spec:
          customDeploymentRef:
            templateRef: Custom
            versionLabel: "1.0"
  EOT
}
```

**This defines**:
- Service type (CustomDeployment)
- Which template to use (Custom v1.0)

**This does NOT define**:
- Where to deploy (AWS? Local? Which environments?)
- Infrastructure-specific variables

**That's the job of infrastructure definitions.**

---

## Solution Options

### Option A: Create Infrastructure Definitions in Terraform (Recommended)

**Pros**:
- Infrastructure as Code
- Version controlled
- Matches current Terraform pattern
- Eliminates manual setup

**Cons**:
- Requires Terraform apply (1 minute)

**Implementation**:

Create `terraform/harness-infrastructure-definitions.tf`:

```hcl
# Infrastructure Definitions for Custom Deployment
# Each environment gets one infrastructure definition

resource "harness_platform_infrastructure" "demo_infrastructures" {
  for_each = local.harness_environments

  identifier     = "${each.value.identifier}_infra"
  name           = "${each.value.name} Infrastructure"
  org_id         = var.harness_org_id
  project_id     = var.harness_project_id
  env_id         = harness_platform_environment.demo_environments[each.key].id
  type           = "CustomDeployment"
  deployment_type = "CustomDeployment"

  yaml = <<-EOT
    infrastructureDefinition:
      name: ${each.value.name} Infrastructure
      identifier: ${each.value.identifier}_infra
      orgIdentifier: ${var.harness_org_id}
      projectIdentifier: ${var.harness_project_id}
      environmentRef: ${each.value.identifier}
      deploymentType: CustomDeployment
      type: CustomDeployment
      spec:
        customDeploymentRef:
          templateRef: Custom
          versionLabel: "1.0"
        variables: []
      allowSimultaneousDeployments: false
  EOT

  tags = [
    "demo_id:${var.demo_id}",
    "environment:${each.key}",
    "managed_by:terraform"
  ]
}

output "harness_infrastructure_identifiers" {
  description = "Harness infrastructure definition identifiers created"
  value = {
    for env in local.environments :
    env => harness_platform_infrastructure.demo_infrastructures[env].identifier
  }
}
```

**Then update pipeline to reference infrastructure**:

```yaml
# harness/pipelines/deploy-pipeline.yaml
environment:
  environmentRef: psr_dev
  deployToAll: true  # Now deploys to the ONE infrastructure definition in psr_dev

  # OR explicitly reference it:
  # infrastructureDefinitions:
  #   - identifier: psr_dev_infra
```

### Option B: Create Infrastructure Definitions Manually (Quick Test)

**Pros**:
- Fast to test (2 minutes per environment)
- No code changes

**Cons**:
- Not version controlled
- Manual process
- Requires 4 separate creations (dev, test, staging, prod)

**Steps** (via Harness UI):

1. Navigate to: **Project Settings** → **Environments** → **psr-dev**
2. Go to **"Infrastructure Definitions"** tab
3. Click **"+ New Infrastructure Definition"**
4. Fill in:
   - **Name**: `Dev Infrastructure`
   - **Identifier**: `psr_dev_infra`
   - **Deployment Type**: `Custom Deployment`
   - **Deployment Template**: `Custom` (version `1.0`)
   - **Variables**: (leave empty)
5. Click **"Save"**
6. Repeat for psr-test, psr-staging, psr-prod

### Option C: Use Explicit Infrastructure References (Not Recommended)

Keep using `deployToAll: false` and explicitly list infrastructure in pipeline:

```yaml
environment:
  environmentRef: psr_dev
  deployToAll: false
  infrastructureDefinitions:
    - identifier: psr_dev_infra
```

**Why not recommended**:
- Still requires creating infrastructure definitions first
- More verbose pipeline YAML
- Less flexible (can't add new infrastructures without pipeline changes)

---

## Recommended Action Plan

1. **Create `terraform/harness-infrastructure-definitions.tf`** (see Option A above)
2. **Run Terraform apply**:
   ```bash
   cd terraform
   AWS_PROFILE=liquibase-sandbox-admin terraform apply
   ```
3. **Verify infrastructure definitions created**:
   ```bash
   source harness/.env
   curl -X GET \
     'https://app.harness.io/gateway/ng/api/infrastructures?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=psr_dev' \
     -H "x-api-key: ${HARNESS_API_KEY}" | jq '.data.content | length'
   # Expected output: 1 (one infrastructure definition in psr_dev)
   ```
4. **Test pipeline execution**:
   ```bash
   # Trigger webhook (rerun last GitHub Actions workflow)
   gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId' | \
     xargs gh run rerun
   ```
5. **Monitor Harness execution**: Should now proceed past initialization phase

---

## Key Learnings

1. **`deployToAll: true` requires infrastructure definitions to exist**
   - It's not a bypass, it's a "deploy to all available infrastructures" flag
   - If 0 infrastructures exist, deployment fails

2. **Environments ≠ Infrastructure Definitions**
   - Environments are **containers** (like folders)
   - Infrastructure Definitions are **deployment targets** (like files in folders)
   - You can have multiple infrastructure definitions per environment

3. **Service definition ≠ Infrastructure definition**
   - Service: "What am I deploying?" (artifact sources, template reference)
   - Infrastructure: "Where am I deploying?" (template variables, environment link)

4. **CustomDeployment is no different from Kubernetes/ECS/Lambda**
   - All deployment types require infrastructure definitions
   - CustomDeployment just references a custom template instead of built-in types

5. **Terraform oversight**
   - Our Terraform created environments but not infrastructure definitions
   - This was likely an incomplete implementation
   - Easy to fix with one new file

---

## Related Issues

This explains several mysterious behaviors:

1. **Why connector/environment fixes didn't work**: Those were real issues, but not THE issue
2. **Why `deployToAll: true` didn't help**: It deploys to all infrastructures... but there are zero
3. **Why error says "not specified"**: Harness can't find ANY infrastructure definitions to deploy to
4. **Why this happened immediately**: Validation happens during pipeline initialization, before delegate tasks

---

## Documentation Updates Required

After implementing the fix:

1. Update `CLAUDE.md`:
   - Document that CustomDeployment requires infrastructure definitions
   - Add to "Architecture Decision Records"

2. Update `terraform/README.md`:
   - Document new `harness-infrastructure-definitions.tf` file
   - Explain infrastructure definition pattern

3. Update `docs/HARNESS_MANUAL_SETUP.md`:
   - Remove any manual infrastructure definition steps (now automated)
   - Or add manual steps if Option B chosen

4. Update `harness/README.md`:
   - Document infrastructure definition resources
   - Explain environment vs infrastructure difference

---

## Verification Checklist

After applying fixes:

- [ ] Terraform shows 4 new infrastructure definitions created
- [ ] API call returns 1 infrastructure per environment
- [ ] Harness UI shows infrastructure definitions under each environment
- [ ] Pipeline execution proceeds past initialization phase
- [ ] Dev stage starts executing steps
- [ ] Delegate receives tasks (shows in delegate logs)
- [ ] Pipeline executes successfully (or fails for a different reason)

---

## Appendix: Research Sources

1. **Harness Developer Hub** - CustomDeployment documentation
   - Source: `/harness/developer-hub` via Context7
   - Key finding: "create a Harness Infrastructure Definition that uses the Deployment Template"

2. **Code Examples** - Salesforce and Google Cloud Run CustomDeployment
   - Both show separate infrastructure definition resources
   - Both reference custom deployment templates

3. **Harness Release Notes** - Infrastructure definition validation
   - "Missing infrastructure definition validation fix"
   - Confirms infrastructure definitions are validated and required

4. **Current Terraform State**
   - `harness-environments.tf`: Creates environments only
   - `harness-service.tf`: Creates service with template reference
   - **No file creates infrastructure definitions**

---

## Status

- ✅ **Research Complete**
- ✅ **Root Cause Identified**
- ✅ **Solution Designed**
- ⏳ **Implementation Pending**
- ⏳ **Testing Pending**

**Next Step**: Implement Option A (Terraform infrastructure definitions)
