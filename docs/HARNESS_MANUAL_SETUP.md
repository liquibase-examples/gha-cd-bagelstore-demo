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
| **YAML Path** | `harness/input-sets/webhook-default-2.yaml` |

### 3.4 Pipeline Variables

**IMPORTANT:** For webhook triggers, the Input Set file in Git already has the correct expressions that map webhook payload to pipeline variables.

The file at `harness/input-sets/webhook-default-2.yaml` contains:
```yaml
variables:
  - name: VERSION
    value: <+trigger.payload.version>
  - name: GITHUB_ORG
    value: <+trigger.payload.github_org>
  - name: DEPLOYMENT_TARGET
    value: <+trigger.payload.deployment_target>
```

**You do NOT need to manually edit these values in the Harness UI.** When you save the Input Set, Harness reads these expressions from Git.

**Key Point:** These are NOT `<+input>` (which waits for manual user input), but `<+trigger.payload.*>` expressions (which automatically resolve from webhook payload data).

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
4. **Scroll down** to see the "Pipeline Variables" section
5. **Verify** the variables show the trigger payload expressions (in orange text):
   - `VERSION`: `<+trigger.payload.version>`
   - `GITHUB_ORG`: `<+trigger.payload.github_org>`
   - `DEPLOYMENT_TARGET`: `<+trigger.payload.deployment_target>`

**Note:** These values come from the Input Set file in Git (`harness/input-sets/webhook-default-2.yaml`). You should NOT see `<+input>` values - if you do, the Input Set needs to be re-synced from Git (delete and re-add it).

### 4.5 Save Trigger

Click **"Create"** to save the trigger.

### 4.6 Copy Webhook URL

After saving, you'll be back at the Trigger Listing page. Get the webhook URL:

**Click the Webhook Icon**

1. Look in the **WEBHOOK** column next to your trigger
2. Click the link icon (🔗)
3. This will either:
   - Copy the webhook URL to your clipboard, OR
   - Display the webhook URL in a popup

**Expected format:** `https://app.harness.io/gateway/pipeline/api/webhook/custom/...`

---

## Step 5: Set GitHub Repository Variable

### 5.1 Set HARNESS_WEBHOOK_URL Variable

Run this command with the webhook URL from Step 4.6:

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
1. Verify Input Set exists in Git: `harness/input-sets/webhook-default-2.yaml`
2. Ensure Input Set is committed and pushed to `main` branch
3. In trigger UI, go to "Pipeline Input" tab
4. Click "+ Select Input Set(s)" and select `webhook_default`
5. Do NOT try to manually enter pipeline variables - use Input Set instead

### Trigger Stays QUEUED - Never Executes

**Problem:** Webhook successfully posts to Harness, but pipeline execution stays in QUEUED state forever with `pipelineExecutionId: null`

**Symptoms:**
- GitHub Actions completes successfully
- Webhook returns `"status":"SUCCESS"`
- Harness API shows `"status":"QUEUED"` with `"message":"Trigger execution is queued"`
- Pipeline never starts executing

**Root Cause:** Input Set has `<+input>` values (manual runtime input) instead of `<+trigger.payload.*>` expressions (webhook payload data)

**Solution:**
1. Check Input Set file in Git: `harness/input-sets/webhook-default-2.yaml`
2. Verify all variables use trigger payload expressions:
   ```yaml
   value: <+trigger.payload.version>          # ✅ CORRECT
   # NOT:
   value: <+input>                             # ❌ WRONG - waits forever for manual input
   ```
3. If values are wrong, update the file in Git and push
4. In Harness UI, delete and recreate the Input Set to force re-sync from Git
5. Update the trigger to use the refreshed Input Set

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
