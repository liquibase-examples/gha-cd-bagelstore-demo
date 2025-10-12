   # Harness Manual Setup Guide

**Why Manual Setup?** Templates, pipelines, and triggers are managed in Git (GitOps approach) and require feature flags from Harness Support to manage via Terraform. Manual setup takes ~10 minutes and avoids feature flag requirements.

**What's Already Done (via Terraform):**
- ✅ 4 Environments (dev, test, staging, prod) with AWS infrastructure outputs
- ✅ 4 Secrets (GitHub PAT, AWS credentials, Liquibase license)
- ✅ 2 Connectors (GitHub, AWS)
- ✅ 1 Service (Bagel Store)

**What Requires Manual Setup:**
- ❌ Step Group Template (GitOps - stored in Git)
- ❌ Pipeline (GitOps - stored in Git)
- ❌ Webhook Trigger

---

## Prerequisites

1. **Terraform applied successfully**
   ```bash
   cd terraform
   AWS_PROFILE=liquibase-sandbox-admin terraform apply
   ```

2. **Harness delegate running and connected**
   ```bash
   cd ../harness
   docker compose ps  # Should show "Up"
   ```

3. **Verify in Harness UI:** https://app.harness.io/ng/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo

---

## Step 1: Create Step Group Template (5 min)

### 1.1 Navigate to Templates

1. Go to Harness UI: **Project Settings** → **Templates** → **+ New Template**
2. Select: **Step Group**

### 1.2 Configure Template

Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Coordinated DB and App Deployment` |
| **Version Label** | `v1.0` |
| **Description** | Coordinated database and application deployment with health checks |
| **Tags** | `purpose:deployment`, `components:database_application` |

### 1.3 Store in Git (Remote)

**IMPORTANT:** Do NOT create inline template. Use remote (Git) storage:

1. Click **"Save"** button dropdown → Select **"Save to Git"**
2. Configure Git details:

   | Field | Value |
   |-------|-------|
   | **Git Connector** | `github-bagel-store` (should be in dropdown) |
   | **Repository** | `gha-cd-bagelstore-demo` |
   | **Git Branch** | `main` |
   | **File Path** | `harness/templates/deployment-steps.yaml` |
   | **Commit Message** | `Add coordinated deployment template via Harness UI` |

3. Click **"Save"**

### 1.4 Verify Template

- Template should appear in Templates list
- Click template → Should show "Remote" indicator
- Should display 4 steps: Fetch Artifact, Update Database, Deploy App, Health Check

---

## Step 2: Create Pipeline (3 min)

### 2.1 Navigate to Pipelines

1. Go to **Pipelines** → **+ Create a Pipeline**
2. Select: **Continuous Delivery**

### 2.2 Configure Pipeline

Fill in the form:

| Field | Value |
|-------|-------|
| **Name** | `Deploy Bagel Store` |
| **Setup** | Select **"Remote"** (NOT Inline) |

### 2.3 Store in Git (Remote)

Configure Git details:

| Field | Value |
|-------|-------|
| **Git Connector** | `github-bagel-store` |
| **Repository** | `gha-cd-bagelstore-demo` |
| **Git Branch** | `main` |
| **YAML Path** | `harness/pipelines/deploy-pipeline.yaml` |

Click **"Create"**

### 2.4 Verify Pipeline

- Pipeline should appear in Pipelines list
- Click pipeline → Should show 4 stages (Deploy to Dev/Test/Staging/Prod)
- Each stage should reference the template created in Step 1

---

## Step 3: Create Input Set (2 min)

**Why?** Remote pipelines require Input Sets to define runtime variables. This Input Set will be used by the webhook trigger.

### 3.1 Navigate to Input Sets

1. Open the **Deploy Bagel Store** pipeline
2. Click **"Input Sets"** tab
3. Click **"+ New Input Set"**

### 3.2 Choose Git Storage

Select **"Third-party Git provider"** (NOT "Harness Code Repository")

### 3.3 Configure Git Details

Fill in the form:

| Field | Value |
|-------|-------|
| **Git Connector** | `github-bagel-store` |
| **Repository** | `gha-cd-bagelstore-demo` |
| **Git Branch** | `main` |
| **YAML Path** | `harness/input-sets/webhook-default.yaml` |

### 3.4 Pipeline Variables

The form will show the pipeline variables defined in your pipeline. Set each variable to **"Runtime input"** (leave blank or set to `<+input>`):

| Variable | Value |
|----------|-------|
| **VERSION** | Leave blank (Runtime input) |
| **GITHUB_ORG** | Leave blank (Runtime input) |
| **DEPLOYMENT_TARGET** | Leave blank (Runtime input) |

**What this means:** These values will be provided at runtime by the webhook trigger, not hardcoded in the Input Set.

### 3.5 Save to Git

1. Click **"Save"**
2. In the **"Save InputSets to Git"** dialog:
   - **Commit message**: `Create inputset Webhook Default` (or customize)
   - **Select Branch to Commit**: `main` (Commit to existing branch)
   - Optional: Check "Start a pull request to merge" if you want PR review
3. Click **"Save"**

**What happens:** Harness will create the file `harness/input-sets/webhook-default.yaml` in Git via commit.

---

## Step 4: Create Webhook Trigger (2 min)

### 4.1 Open Pipeline Triggers

1. Open the **Deploy Bagel Store** pipeline
2. Click **"Triggers"** tab (top right)
3. Click **"+ New Trigger"**

### 4.2 Configure Webhook

Select **"Custom"** webhook type, then configure:

| Field | Value |
|-------|-------|
| **Name** | `GitHub Actions CI` |
| **Description** | Triggered automatically when GitHub Actions completes artifact builds |

### 4.3 Configure Payload Conditions

Under **"Conditions"**, add:

| Field | Operator | Value |
|-------|----------|-------|
| `version` | **Equals** | `<+trigger.payload.version>` |

### 4.4 Select Input Set (Required for Remote Pipelines)

**IMPORTANT:** Remote pipelines require an Input Set to be selected.

1. Click the **"Pipeline Input"** tab in the trigger configuration
2. Click **"+ Select Input Set(s)"** button
3. Select **`webhook_default`** from the dropdown
4. In the trigger configuration, map webhook payload to pipeline variables:
   - `VERSION`: `<+trigger.payload.version>`
   - `GITHUB_ORG`: `<+trigger.payload.github_org>` or hardcode `liquibase-examples`
   - `DEPLOYMENT_TARGET`: `<+trigger.payload.deployment_target>` or hardcode `aws`

**Note:** The Input Set was created in Step 3 and is stored in Git at `harness/input-sets/webhook-default.yaml`.

### 4.5 Save and Copy Webhook URL

1. Click **"Create"**
2. **COPY the Webhook URL** (you'll need it in next step)
3. Format: `https://app.harness.io/gateway/api/webhooks/...`

---

## Step 5: Set GitHub Repository Variable

### 5.1 Set HARNESS_WEBHOOK_URL Variable

Run this command with the webhook URL from Step 4.5:

```bash
gh variable set HARNESS_WEBHOOK_URL \
  --repo liquibase-examples/gha-cd-bagelstore-demo \
  --body "PASTE_WEBHOOK_URL_HERE"
```

### 5.2 Verify Variable

```bash
gh variable list --repo liquibase-examples/gha-cd-bagelstore-demo | grep HARNESS_WEBHOOK_URL
```

Should show: `HARNESS_WEBHOOK_URL  <webhook_url>  Updated YYYY-MM-DD`

---

## Verification

### Test the Complete Flow

1. **Trigger GitHub Actions:**
   ```bash
   git commit --allow-empty -m "Test Harness integration"
   git push origin main
   ```

2. **Watch GitHub Actions:**
   ```bash
   gh run list --limit 1
   gh run watch <run_id>
   ```

3. **Check Harness Pipeline:**
   - When GitHub Actions completes, webhook should trigger Harness
   - Go to Harness UI → Pipelines → Deploy Bagel Store → Executions
   - Should see new execution with version from GitHub tag

### Expected Flow

```
┌─────────────────┐
│  Git Push       │
│  (main branch)  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│  GitHub Actions CI      │
│  - Build Docker image   │
│  - Create changelog ZIP │
│  - Publish to ghcr.io   │
│  - Post to webhook      │
└────────┬────────────────┘
         │
         ▼
┌─────────────────────────┐
│  Harness Pipeline       │
│  - Deploy to Dev (auto) │
│  - Deploy to Test       │
│  - Deploy to Staging    │
│  - Deploy to Prod       │
└─────────────────────────┘
```

---

## Troubleshooting

### Template Not Showing in Pipeline

**Problem:** Pipeline can't find the template

**Solution:**
1. Verify template exists: Project Settings → Templates
2. Check template version label is exactly: `v1.0`
3. Ensure template is saved to correct Git path

### Webhook Not Triggering

**Problem:** GitHub Actions completes but Harness doesn't start

**Solution:**
1. Check GitHub variable is set: `gh variable list --repo ...`
2. Verify webhook URL in Harness UI matches GitHub variable
3. Check trigger conditions (payload must include `version` field)
4. View trigger execution history in Harness UI

### Cannot Create Trigger - "Input Set Required"

**Problem:** Trigger creation fails with error about missing Input Set

**Solution:**
1. Verify Input Set exists in Git: `harness/input-sets/webhook-default.yaml`
2. Ensure Input Set is committed and pushed to `main` branch
3. In trigger UI, go to "Pipeline Input" tab
4. Click "+ Select Input Set(s)" and select `webhook_default`
5. Do NOT try to manually enter pipeline variables - use Input Set instead

### Pipeline Fails on Dev Deployment

**Problem:** Dev stage fails immediately

**Solution:**
1. Check Harness environments exist: Project Settings → Environments
2. Verify environment variables populated (14 variables per env)
3. Check delegate is connected: Project Settings → Delegates
4. Review execution logs in Harness UI

### Cannot Find GitHub Connector

**Problem:** Dropdown doesn't show `github-bagel-store` connector

**Solution:**
1. Verify connector exists: Project Settings → Connectors
2. Check connector shows "Connected" status
3. Test connection in connector settings
4. Ensure delegate is running and healthy

---

## Summary

After completing these steps, you have:

✅ **GitOps Pipeline:** Template and pipeline stored in Git
✅ **Automated Trigger:** GitHub Actions automatically triggers Harness
✅ **Multi-Environment:** 4 environments with approval gates
✅ **Infrastructure Integration:** Environments pre-configured with AWS outputs

**Total Setup Time:** ~10 minutes

**Maintenance:** Template and pipeline changes happen via Git commits (pull requests). No need to touch Harness UI again.
