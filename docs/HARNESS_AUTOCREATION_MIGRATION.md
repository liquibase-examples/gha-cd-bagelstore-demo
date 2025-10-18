# Harness Git Experience Autocreation Migration Plan

**Document Version:** 1.0
**Last Updated:** 2025-10-18
**Status:** Ready for Execution

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Migration Verification](#pre-migration-verification)
4. [Migration Strategy](#migration-strategy)
5. [Step-by-Step Migration](#step-by-step-migration)
6. [Verification](#verification)
7. [Post-Migration Cleanup](#post-migration-cleanup)
8. [Troubleshooting](#troubleshooting)
9. [Rollback Procedure](#rollback-procedure)

---

## Overview

### What is Autocreation?

**Autocreation** is a Harness Git Experience feature that automatically creates entities (pipelines, templates, input sets, services, environments) when YAML files are pushed to Git following a specific directory structure convention.

**Key Pattern:** All files must be under `.harness/` directory in your repository's default branch (main/master).

### Current State

```
harness/
├── pipelines/deploy-pipeline.yaml          # Pipeline: Deploy_Bagel_Store
├── templates/deployment-steps.yaml         # Template: Coordinated_DB_App_Deployment (v1.0)
└── input-sets/webhook-default-2.yaml       # Input Set: webhook_default

Management: Manual setup in Harness UI
```

### Target State

```
.harness/
└── orgs/
    └── default/
        └── projects/
            └── bagel_store_demo/
                ├── pipelines/
                │   └── Deploy_Bagel_Store.yaml
                ├── templates/
                │   └── Coordinated_DB_App_Deployment/
                │       └── v1_0.yaml
                └── pipelines/
                    └── Deploy_Bagel_Store/
                        └── input_sets/
                            └── webhook_default.yaml

Management: Automatic creation via Git push
```

### Benefits

- ✅ **True GitOps** - All changes via pull requests
- ✅ **No manual UI setup** - Push to Git, entities autocreate
- ✅ **Version control** - Full entity history in Git
- ✅ **Eliminates timeout issues** - No Terraform remote resource problems
- ✅ **Simplified workflow** - Developers create entities via Git

---

## Prerequisites

### 1. Harness Configuration Requirements

#### A. Git Connector (Verify Existing)

**Action:** Verify your existing `github_bagel_store` connector has:
- ✅ Personal Access Token (PAT) authentication
- ✅ "Enable API access" option enabled
- ✅ Scopes: `repo`, `read:packages`

**How to verify:**
1. Harness UI → Project Settings → Connectors
2. Find `github_bagel_store` connector
3. Click Edit → Check "Enable API access" is ON
4. Verify PAT has required scopes

#### B. Webhook Registration (REQUIRED - Must Be Done First)

**Action:** Register a project-level webhook in Harness

**Steps:**
1. Navigate to Harness UI
2. Project Settings → Webhooks → "+ New Webhook"
3. Configure:
   - **Name:** `bagel_store_autocreation`
   - **Repository URL:** `https://github.com/<YOUR_ORG>/harness-gha-bagelstore`
   - **Events:** Push events to default branch (main)
   - **Scope:** Project-level (bagel_store_demo)
4. Save webhook
5. **CRITICAL:** Webhook will automatically track `.harness/` folder

**Verification:**
- Webhook appears in Webhook list
- Status shows "Active" or "Connected"

### 2. Local Environment

- ✅ Git repository cloned
- ✅ Access to push to main branch
- ✅ Harness UI access for verification

### 3. Information Gathering

**Collect the following identifiers from current Harness entities:**

```bash
# From harness/pipelines/deploy-pipeline.yaml
Pipeline Identifier: Deploy_Bagel_Store
Org Identifier: default
Project Identifier: bagel_store_demo

# From harness/templates/deployment-steps.yaml
Template Identifier: Coordinated_DB_App_Deployment
Version Label: v1.0

# From harness/input-sets/webhook-default-2.yaml
Input Set Identifier: webhook_default
```

---

## Pre-Migration Verification

### Step 1: Backup Current Entity YAMLs

**Purpose:** Create backups in case rollback is needed

```bash
# Create backup directory
mkdir -p harness/backup-$(date +%Y%m%d)

# Copy current files
cp harness/pipelines/deploy-pipeline.yaml harness/backup-$(date +%Y%m%d)/
cp harness/templates/deployment-steps.yaml harness/backup-$(date +%Y%m%d)/
cp harness/input-sets/webhook-default-2.yaml harness/backup-$(date +%Y%m%d)/

# Verify backup
ls -la harness/backup-*/
```

### Step 2: Export Entities from Harness UI (Additional Backup)

**Action:** Export YAML from Harness UI for pipeline and template

1. **Pipeline:**
   - Harness UI → Pipelines → Deploy Bagel Store
   - Click "YAML" view
   - Copy entire YAML
   - Save to `harness/backup-$(date +%Y%m%d)/pipeline-export.yaml`

2. **Template:**
   - Harness UI → Templates → Coordinated DB and App Deployment
   - Click "YAML" view
   - Copy entire YAML
   - Save to `harness/backup-$(date +%Y%m%d)/template-export.yaml`

### Step 3: Document Current State

```bash
# Create state documentation
cat > harness/backup-$(date +%Y%m%d)/CURRENT_STATE.md <<EOF
# Current Harness Configuration State

**Date:** $(date +%Y-%m-%d)

## Entities in Harness UI:
- Pipeline: Deploy_Bagel_Store
- Template: Coordinated_DB_App_Deployment (v1.0)
- Input Set: webhook_default

## Entities in Terraform:
- Service: bagel_store
- Environments: psr_dev, psr_test, psr_staging, psr_prod (keep in Terraform)
- Secrets: github_pat, aws_access_key_id, aws_secret_access_key, liquibase_license_key
- Connectors: github_bagel_store, aws_bagel_store

## Migration Plan:
- Move to autocreation: Pipeline, Template, Input Set
- Keep in Terraform: Service, Environments, Secrets, Connectors
EOF

cat harness/backup-*/CURRENT_STATE.md
```

### Step 4: Verify Webhook is Registered

**CRITICAL:** Autocreation will NOT work without webhook

**Verify:**
1. Harness UI → Project Settings → Webhooks
2. Look for webhook pointing to your repository
3. Verify Status is "Active"

**If webhook doesn't exist:** STOP and complete Prerequisites section first.

---

## Migration Strategy

### Approach: Delete-First Method (Recommended)

**Rationale:**
- Avoids identifier conflicts
- Clean migration path
- Easier to verify success

**Process:**
1. Delete existing pipeline, template, input set from Harness UI
2. Create `.harness/` directory structure
3. Move YAML files to autocreation paths
4. Commit and push to Git
5. Verify autocreation in Harness UI

### What We're Migrating

| Entity | Current Location | New Location | Action |
|--------|-----------------|--------------|--------|
| Pipeline | `harness/pipelines/deploy-pipeline.yaml` | `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml` | Move + Autocreate |
| Template | `harness/templates/deployment-steps.yaml` | `.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml` | Move + Autocreate |
| Input Set | `harness/input-sets/webhook-default-2.yaml` | `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml` | Move + Autocreate |

### What We're NOT Migrating (Keeping in Terraform)

- ✅ **Service:** bagel_store (Terraform manages this well)
- ✅ **Environments:** psr_dev, psr_test, psr_staging, psr_prod (auto-populated with AWS outputs)
- ✅ **Secrets:** GitHub PAT, AWS credentials, Liquibase license
- ✅ **Connectors:** GitHub, AWS

**Reason:** Environments are **CRITICAL VALUE** - auto-populated with 14 AWS infrastructure outputs via Terraform. Moving to autocreation means manually maintaining these values.

---

## Step-by-Step Migration

### Phase 1: Delete Existing Entities from Harness UI

**IMPORTANT:** Do this BEFORE creating `.harness/` files to avoid identifier conflicts.

#### Step 1.1: Delete Pipeline

1. Harness UI → Pipelines → Deploy Bagel Store
2. Click "⋮" (three dots) → Delete
3. Confirm deletion
4. Verify pipeline is gone from list

#### Step 1.2: Delete Template

1. Harness UI → Templates → Coordinated DB and App Deployment
2. Click "⋮" (three dots) → Delete
3. Confirm deletion
4. Verify template is gone from list

#### Step 1.3: Delete Input Set

1. Harness UI → Pipelines (if pipeline still exists) or Input Sets
2. Find webhook_default input set
3. Delete it
4. Confirm deletion

**Verification Checkpoint:**
- Navigate to Pipelines → Should see "No pipelines" or empty list
- Navigate to Templates → Coordinated_DB_App_Deployment should be gone
- Input set should not appear in any views

---

### Phase 2: Create Autocreation Directory Structure

#### Step 2.1: Create `.harness/` Base Directory

```bash
# Navigate to repository root
cd /Users/recampbell/workspace/harness-gha-bagelstore

# Create .harness directory structure
mkdir -p .harness/orgs/default/projects/bagel_store_demo/{pipelines,templates,services,envs}

# Verify structure
tree .harness/ -L 5
```

**Expected output:**
```
.harness/
└── orgs
    └── default
        └── projects
            └── bagel_store_demo
                ├── envs
                ├── pipelines
                ├── services
                └── templates
```

#### Step 2.2: Create Subdirectories for Template Versions and Input Sets

```bash
# Template version directory (named after template identifier)
mkdir -p .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment

# Input sets directory (nested under pipeline identifier)
mkdir -p .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets

# Verify complete structure
tree .harness/
```

**Expected output:**
```
.harness/
└── orgs
    └── default
        └── projects
            └── bagel_store_demo
                ├── envs
                ├── pipelines
                │   └── Deploy_Bagel_Store
                │       └── input_sets
                ├── services
                └── templates
                    └── Coordinated_DB_App_Deployment
```

---

### Phase 3: Move YAML Files to Autocreation Paths

#### Step 3.1: Move Pipeline YAML

```bash
# Copy (not move yet, for safety) pipeline to autocreation path
cp harness/pipelines/deploy-pipeline.yaml \
   .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml

# Verify file exists
cat .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml | head -10
```

**Verification:**
- File should start with `pipeline:`
- Should contain `identifier: Deploy_Bagel_Store`
- Should contain `projectIdentifier: bagel_store_demo`
- Should contain `orgIdentifier: default`

#### Step 3.2: Move Template YAML

**IMPORTANT:** Version label in filename uses underscore, not dot!
- ✅ Correct: `v1_0.yaml`
- ❌ Wrong: `v1.0.yaml`

```bash
# Copy template to autocreation path (underscore in version!)
cp harness/templates/deployment-steps.yaml \
   .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml

# Verify file exists
cat .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml | head -10
```

**Verification:**
- File should start with `template:`
- Should contain `identifier: Coordinated_DB_App_Deployment`
- Should contain `versionLabel: v1.0` (with dot in YAML, underscore in filename)
- Should contain `projectIdentifier: bagel_store_demo`
- Should contain `orgIdentifier: default`

#### Step 3.3: Move Input Set YAML

```bash
# Copy input set to autocreation path (nested under pipeline identifier)
cp harness/input-sets/webhook-default-2.yaml \
   .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml

# Verify file exists
cat .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml
```

**Verification:**
- File should start with `inputSet:`
- Should contain `identifier: webhook_default`
- Should contain `pipeline.identifier: Deploy_Bagel_Store`
- Should contain `projectIdentifier: bagel_store_demo`
- Should contain `orgIdentifier: default`

#### Step 3.4: Verify All Files Are in Place

```bash
# List all YAML files in .harness/
find .harness/ -name "*.yaml" -type f

# Expected output:
# .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml
# .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml
# .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml
```

**Count should be 3 files.**

---

### Phase 4: Commit and Push to Trigger Autocreation

#### Step 4.1: Review Changes

```bash
# Check git status
git status

# Should show:
# new file:   .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml
# new file:   .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml
# new file:   .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml
```

#### Step 4.2: Create .gitignore Entry (Optional)

**Check if `.harness/` should be ignored:**

```bash
# Check current .gitignore
grep "\.harness" .gitignore
```

**Expected:** `.harness/` should NOT be in .gitignore (we want to commit these files)

**If `.harness/` is in .gitignore, remove that line:**
```bash
# Remove .harness/ from .gitignore if present
sed -i.bak '/^\.harness\//d' .gitignore
rm -f .gitignore.bak
```

#### Step 4.3: Add Files to Git

```bash
# Add .harness directory
git add .harness/

# Verify what's staged
git diff --staged --name-only
```

#### Step 4.4: Commit with Descriptive Message

```bash
git commit -m "Migrate to Harness Git Experience autocreation pattern

- Move pipeline Deploy_Bagel_Store to autocreation path
- Move template Coordinated_DB_App_Deployment (v1.0) to autocreation path
- Move input set webhook_default to autocreation path
- Delete manual entities from Harness UI (completed)
- Webhook registered at project level

Files will be automatically created in Harness when pushed to main branch.

Related: Harness autocreation migration plan
"
```

#### Step 4.5: Push to Main Branch

**CRITICAL:** Autocreation only works on default branch (main/master)

```bash
# Ensure you're on main branch
git branch --show-current
# Should output: main

# If not on main, switch to main
git checkout main

# Push to trigger autocreation
git push origin main
```

**What happens next:**
1. GitHub receives push event
2. GitHub sends webhook to Harness
3. Harness webhook processes `.harness/` files
4. Harness autocreates entities based on file paths
5. Entities appear in Harness UI

**Expected time:** 30 seconds to 2 minutes

---

## Verification

### Step 1: Check Webhook Events Page

**Purpose:** Verify Harness received and processed the webhook

**Steps:**
1. Harness UI → Project Settings → Webhooks
2. Click on your webhook name
3. Navigate to "Events" or "Recent Deliveries"
4. Look for most recent event (should be your push)
5. Verify status is "Success" or "Processed"

**Troubleshooting if webhook failed:**
- Click on event to see error details
- Common issues: Path structure incorrect, YAML syntax error, identifier conflicts

### Step 2: Verify Pipeline Autocreated

**Steps:**
1. Harness UI → Pipelines
2. Look for "Deploy Bagel Store" pipeline
3. Click on pipeline name
4. Verify:
   - Pipeline opens successfully
   - All 4 stages present (Dev, Test, Staging, Production)
   - YAML view matches source file
   - Git metadata shows source: `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml`

**Expected:**
- Pipeline appears with correct name and identifier
- Shows as "Remote" entity (not "Inline")
- Git icon appears next to pipeline name

### Step 3: Verify Template Autocreated

**Steps:**
1. Harness UI → Templates
2. Look for "Coordinated DB and App Deployment" template
3. Click on template name
4. Verify:
   - Template opens successfully
   - Version "v1.0" is present
   - All 5 steps present (Fetch Changelog, Update Database, Deploy Application, Health Check, Fetch Instances)
   - YAML view matches source file
   - Git metadata shows source

**Expected:**
- Template appears with correct name and identifier
- Version v1.0 is available
- Shows as "Remote" entity

### Step 4: Verify Input Set Autocreated

**Steps:**
1. Harness UI → Pipelines → Deploy Bagel Store
2. Click "Run" or "Inputs" → "Input Sets"
3. Look for "Webhook Default" input set
4. Verify:
   - Input set appears in list
   - Contains mappings for VERSION, GITHUB_ORG, DEPLOYMENT_TARGET
   - Values use trigger payload expressions

**Expected:**
- Input set appears with correct identifier
- Shows as "Remote" entity

### Step 5: Test Pipeline Execution (Optional but Recommended)

**Purpose:** Verify autocreated entities work correctly

**Steps:**
1. Harness UI → Pipelines → Deploy Bagel Store → Run
2. Select "webhook_default" input set
3. Provide values:
   - VERSION: `v1.0.0` (or latest version)
   - GITHUB_ORG: `<your-org>`
   - DEPLOYMENT_TARGET: `local`
4. Click "Run Pipeline"
5. Monitor execution

**Expected:**
- Pipeline executes without YAML errors
- Template steps execute correctly
- If deployment fails, verify it's infrastructure issue, not YAML issue

### Verification Checklist

- [ ] Webhook event shows "Success" status
- [ ] Pipeline "Deploy Bagel Store" appears in Pipelines list
- [ ] Pipeline shows "Remote" badge or Git icon
- [ ] Template "Coordinated DB and App Deployment" appears in Templates list
- [ ] Template version "v1.0" is available
- [ ] Input Set "webhook_default" appears under pipeline
- [ ] All entities show correct Git source path in metadata
- [ ] Test pipeline execution succeeds (or fails with infrastructure issue, not YAML error)

---

## Post-Migration Cleanup

### Step 1: Remove Old Files from `harness/` Directory

**Purpose:** Clean up redundant files now that entities are in `.harness/`

```bash
# Remove old pipeline, template, input set files
rm harness/pipelines/deploy-pipeline.yaml
rm harness/templates/deployment-steps.yaml
rm harness/input-sets/webhook-default-2.yaml

# Keep delegate files
# harness/docker-compose.yml - KEEP
# harness/.env - KEEP
# harness/.env.example - KEEP

# Verify what's left
ls -la harness/
```

**Expected remaining files:**
```
harness/
├── .env                    # Delegate config (KEEP)
├── .env.example            # Delegate template (KEEP)
├── docker-compose.yml      # Delegate (KEEP)
├── artifacts/              # May be empty (KEEP or remove)
├── backup-YYYYMMDD/        # Backup directory (KEEP for now)
└── README.md               # Update or remove
```

### Step 2: Update `harness/README.md`

**Action:** Update README to reflect new autocreation pattern

```bash
# Edit harness/README.md
# Update sections about pipeline, template, input set locations
# Add reference to .harness/ directory
# Update setup instructions
```

**Key changes:**
- Remove references to `harness/pipelines/`, `harness/templates/`, `harness/input-sets/`
- Add section: "Entities are managed via `.harness/` directory (autocreation pattern)"
- Add link to this migration document

### Step 3: Commit Cleanup

```bash
# Stage deletions
git add harness/pipelines/deploy-pipeline.yaml
git add harness/templates/deployment-steps.yaml
git add harness/input-sets/webhook-default-2.yaml
git add harness/README.md  # If updated

# Commit cleanup
git commit -m "Clean up old Harness entity files after autocreation migration

- Remove harness/pipelines/deploy-pipeline.yaml (now in .harness/)
- Remove harness/templates/deployment-steps.yaml (now in .harness/)
- Remove harness/input-sets/webhook-default-2.yaml (now in .harness/)
- Update harness/README.md to reflect autocreation pattern

All entities now managed via .harness/ autocreation directory.
"

# Push cleanup
git push origin main
```

### Step 4: Update Project Documentation

**Files to update:**

1. **CLAUDE.md** (Project AI guide):
   - Update ADR section "Why Hybrid Harness Management"
   - Change from "Manual setup" to "Autocreation pattern"
   - Update file paths in examples

2. **README.md** (Project overview):
   - Update Harness setup instructions
   - Add `.harness/` to repository structure diagram
   - Update quick start guide

3. **docs/HARNESS_MANUAL_SETUP.md**:
   - OBSOLETE - Either delete or mark as deprecated
   - Add note: "Replaced by autocreation pattern, see `.harness/` directory"

**Example CLAUDE.md update:**

```markdown
### Harness Entity Management (Updated 2025-10-18)

- **Decision:** Use Harness Git Experience autocreation pattern
- **Implementation:**
  - All pipelines, templates, input sets in `.harness/` directory
  - Automatic entity creation on Git push to main branch
  - Project-level webhook registered for autocreation
  - Services and Environments remain in Terraform (AWS integration)
- **Benefits:**
  - True GitOps workflow (changes via pull requests)
  - No manual UI setup required
  - Version control for all entities
  - No Terraform timeout issues for remote resources
```

### Step 5: Create `.harness/README.md`

**Purpose:** Document the autocreation structure for future reference

```bash
cat > .harness/README.md <<'EOF'
# Harness Git Experience Autocreation Directory

This directory contains Harness entity definitions managed via Git Experience autocreation pattern.

## Directory Structure

```
.harness/
└── orgs/
    └── default/
        └── projects/
            └── bagel_store_demo/
                ├── pipelines/           # Pipeline definitions
                ├── templates/           # Step Group Templates
                ├── services/            # Service definitions (optional)
                └── envs/                # Environment definitions (optional)
```

## How It Works

1. **Webhook:** Project-level webhook registered in Harness monitors this repository
2. **Push to Main:** When files are pushed to main branch, webhook triggers
3. **Autocreation:** Harness automatically creates/updates entities based on file paths
4. **File Path Convention:** Path structure maps to Harness hierarchy (org → project → entity type)

## Entity Locations

- **Pipeline:** `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml`
- **Template:** `.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml`
- **Input Set:** `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/input_sets/webhook_default.yaml`

## Making Changes

1. Edit YAML files in `.harness/` directory
2. Test changes locally (validate YAML syntax)
3. Commit and push to main branch
4. Verify autocreation in Harness UI (Webhook Events page)

## Important Notes

- **Only default branch:** Autocreation only processes files in main/master branch
- **File limit:** Max 300 files per commit can be autocreated
- **No deletion:** Deleting files in Git does NOT delete entities in Harness
- **Identifiers must be unique:** Duplicate identifiers will cause autocreation to fail

## Reference

- [Harness Autocreation Documentation](https://developer.harness.io/docs/platform/git-experience/autocreation-of-entities/)
- Migration Plan: `docs/HARNESS_AUTOCREATION_MIGRATION.md`
EOF

git add .harness/README.md
git commit -m "Add .harness/ directory documentation"
git push origin main
```

---

## Troubleshooting

### Issue 1: Webhook Event Shows Error

**Symptom:** Webhook Events page shows "Failed" or error status

**Diagnosis Steps:**
1. Click on failed event to see error details
2. Look for error message (e.g., "Invalid path", "Duplicate identifier", "YAML syntax error")

**Common Errors and Solutions:**

#### Error: "Invalid path structure"
- **Cause:** File path doesn't match autocreation convention
- **Fix:** Verify path follows exact pattern: `.harness/orgs/<org>/projects/<project>/<entity_type>/...`
- **Example:** Should be `.harness/orgs/default/...` not `.harness/default/...`

#### Error: "Duplicate identifier"
- **Cause:** Entity with same identifier already exists in Harness
- **Fix:** Delete existing entity from Harness UI, then re-push
- **Alternative:** Change identifier in YAML file

#### Error: "YAML syntax error"
- **Cause:** Invalid YAML formatting
- **Fix:** Validate YAML using online validator or `yamllint`
- **Command:** `yamllint .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml`

#### Error: "Repository not found" or "Access denied"
- **Cause:** Git connector doesn't have API access or wrong permissions
- **Fix:** Verify connector has "Enable API access" ON and PAT has `repo` scope

### Issue 2: Entities Not Appearing in Harness UI

**Symptom:** Webhook event shows success, but entities don't appear

**Diagnosis:**
1. Wait 2-3 minutes (autocreation can take time)
2. Refresh Harness UI page
3. Check correct org/project (default/bagel_store_demo)
4. Verify webhook event actually shows "Success"

**Possible Causes:**
- Webhook processed different files (check event details)
- Entities created in wrong org/project (check identifiers in YAML)
- Browser cache (hard refresh: Ctrl+Shift+R or Cmd+Shift+R)

### Issue 3: Template Version Not Showing Correctly

**Symptom:** Template created but version label is wrong

**Common Issue:** Filename vs. YAML mismatch
- **Filename:** `v1_0.yaml` (underscore)
- **YAML content:** `versionLabel: v1.0` (dot)

**Fix:** Ensure filename uses underscore, YAML uses dot

### Issue 4: Input Set Not Associated with Pipeline

**Symptom:** Input set created but not visible in pipeline

**Cause:** Input set not in correct directory structure

**Fix:** Verify path is:
```
.harness/orgs/default/projects/bagel_store_demo/pipelines/<PIPELINE_IDENTIFIER>/input_sets/<filename>.yaml
```

**CRITICAL:** Pipeline identifier in path must match `pipeline.identifier` in input set YAML

### Issue 5: Pipeline Execution Fails with "Template Not Found"

**Symptom:** Pipeline runs but fails when trying to use template

**Cause:** Template reference in pipeline doesn't match autocreated template

**Fix:** Verify in pipeline YAML:
```yaml
template:
  templateRef: Coordinated_DB_App_Deployment  # Must match template identifier
  versionLabel: v1.0                          # Must match template version
```

### Issue 6: Changes Not Triggering Autocreation

**Symptom:** Push to main doesn't trigger webhook

**Diagnosis:**
1. Verify changes are in `.harness/` directory
2. Verify push was to default branch (main/master)
3. Check webhook is still active in Harness

**Fix:**
```bash
# Verify default branch
git branch --show-current

# Verify webhook is registered
# Harness UI → Project Settings → Webhooks → Check status
```

---

## Rollback Procedure

### When to Rollback

- Autocreation repeatedly fails
- Entities are created incorrectly and can't be fixed
- Need to revert to manual setup temporarily

### Rollback Steps

#### Step 1: Restore Entities from Backup

```bash
# Navigate to backup directory
cd harness/backup-YYYYMMDD/

# Review backup files
ls -la

# Use Harness UI to recreate entities:
# 1. Copy YAML from backup files
# 2. Create pipeline manually in Harness UI → Pipelines → New Pipeline → YAML
# 3. Paste YAML and save
# 4. Repeat for template and input set
```

#### Step 2: Delete `.harness/` Directory (Optional)

```bash
# Remove .harness directory
git rm -r .harness/

# Commit removal
git commit -m "Rollback: Remove autocreation directory, revert to manual setup"

# Push
git push origin main
```

**Note:** This doesn't delete entities from Harness, only removes Git files

#### Step 3: Disable Webhook (Optional)

1. Harness UI → Project Settings → Webhooks
2. Find autocreation webhook
3. Click "⋮" → Disable or Delete
4. Confirm action

#### Step 4: Document Rollback Reason

```bash
cat > docs/HARNESS_AUTOCREATION_ROLLBACK.md <<EOF
# Harness Autocreation Rollback

**Date:** $(date +%Y-%m-%d)
**Reason:** [Describe why rollback was needed]

## Actions Taken:
1. Restored entities from backup
2. Removed .harness/ directory
3. Disabled webhook

## Lessons Learned:
[Document what went wrong and how to avoid in future]

## Future Plans:
[Will we attempt autocreation again? What needs to change?]
EOF
```

---

## Reference Information

### Autocreation File Path Patterns

#### Pipelines (Project-level)
```
.harness/orgs/<org_id>/projects/<project_id>/pipelines/<filename>.yaml
```

#### Templates (Project-level)
```
.harness/orgs/<org_id>/projects/<project_id>/templates/<template_id>/<version_filename>.yaml
```

#### Input Sets (Project-level)
```
.harness/orgs/<org_id>/projects/<project_id>/pipelines/<pipeline_id>/input_sets/<filename>.yaml
```

#### Services (Project-level)
```
.harness/orgs/<org_id>/projects/<project_id>/services/<filename>.yaml
```

#### Environments (Project-level)
```
.harness/orgs/<org_id>/projects/<project_id>/envs/<env_type>/<filename>.yaml
```
Where `<env_type>` is `production` or `pre_production`

### Important Constraints

- **Max files per commit:** 300 files (exceeding causes autocreation to fail)
- **Branch requirement:** Only default branch (main/master) is processed
- **Identifier uniqueness:** Must be unique within project scope
- **RBAC:** Not applicable - if you can push to repo, entities will be created
- **Deletion:** Deleting files in Git does NOT delete entities in Harness (create-only)

### Useful Commands

```bash
# Validate YAML syntax
yamllint .harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml

# Find all .harness YAML files
find .harness/ -name "*.yaml" -type f

# Count .harness YAML files (ensure < 300 per commit)
find .harness/ -name "*.yaml" -type f | wc -l

# Show .harness directory structure
tree .harness/

# Verify identifiers in all YAML files
grep -r "identifier:" .harness/ | grep -v "projectIdentifier\|orgIdentifier"
```

---

## Migration Completion Checklist

### Pre-Migration
- [ ] Webhook registered in Harness (project-level)
- [ ] Git connector has "Enable API access" enabled
- [ ] Current entities backed up (files + UI export)
- [ ] Current state documented

### Migration
- [ ] Existing entities deleted from Harness UI
- [ ] `.harness/` directory structure created
- [ ] Pipeline YAML moved to autocreation path
- [ ] Template YAML moved to autocreation path (with v1_0.yaml filename)
- [ ] Input set YAML moved to autocreation path
- [ ] Changes committed and pushed to main branch

### Verification
- [ ] Webhook event shows "Success" status
- [ ] Pipeline appears in Harness UI
- [ ] Template appears in Harness UI (version v1.0 present)
- [ ] Input set appears under pipeline
- [ ] All entities show "Remote" badge or Git icon
- [ ] Test pipeline execution succeeds

### Post-Migration
- [ ] Old files removed from `harness/` directory
- [ ] `harness/README.md` updated
- [ ] `.harness/README.md` created
- [ ] Project documentation updated (CLAUDE.md, README.md)
- [ ] Cleanup committed and pushed
- [ ] Migration documented as complete

### Success Criteria
- ✅ All entities autocreated successfully
- ✅ Pipeline executes without errors
- ✅ Changes can be made via Git (edit YAML → push → autocreate)
- ✅ Team can use GitOps workflow for entity management

---

## Next Steps After Migration

### 1. Update Team Workflow

**Document new process for team members:**
- To modify pipeline: Edit `.harness/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store.yaml`
- To modify template: Edit `.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml`
- To add new version: Create `v2_0.yaml` file in same template directory
- To modify input set: Edit input set YAML file
- All changes must be committed and pushed to main branch

### 2. Enable Pull Request Workflow (Recommended)

**Setup:**
1. Create branch protection rules for main branch
2. Require pull request reviews for changes to `.harness/` directory
3. Add YAML validation to CI/CD pipeline (GitHub Actions)

**Example GitHub Actions validation:**
```yaml
name: Validate Harness YAML
on:
  pull_request:
    paths:
      - '.harness/**/*.yaml'
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate YAML syntax
        run: |
          sudo apt-get install -y yamllint
          yamllint .harness/
```

### 3. Monitor Autocreation

**Setup alerting for webhook failures:**
1. Harness UI → Project Settings → Notifications
2. Create notification rule for webhook failures
3. Send to team Slack/email

### 4. Consider Full Migration (Optional)

**If autocreation works well, consider migrating:**
- Services (currently in Terraform)
- Environments (⚠️ be careful - loses AWS auto-population)

**Recommendation:** Keep Services/Environments in Terraform for now - autocreation is working great for pipelines/templates/input sets.

---

## Support and Resources

### Documentation
- [Harness Autocreation Official Docs](https://developer.harness.io/docs/platform/git-experience/autocreation-of-entities/)
- [Git Experience Overview](https://developer.harness.io/docs/platform/git-experience/git-experience-overview/)
- [Webhook Configuration](https://developer.harness.io/docs/platform/triggers/webhooks/)

### Internal Resources
- Migration Plan: `docs/HARNESS_AUTOCREATION_MIGRATION.md` (this file)
- Project Guide: `CLAUDE.md`
- Harness README: `harness/README.md`
- Autocreation README: `.harness/README.md`

### Getting Help
- Harness Community Slack: [https://join-community-slack.harness.io/](https://join-community-slack.harness.io/)
- Harness Support: [https://support.harness.io/](https://support.harness.io/)
- GitHub Issues: Document issues in project repo for team visibility

---

**END OF MIGRATION PLAN**

*This document should be executed step-by-step. Do not skip verification steps. Document any deviations or issues encountered.*
