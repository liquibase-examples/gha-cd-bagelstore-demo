# AI Handoff: Complete Harness Deployment Testing

**Date:** 2025-10-18
**Status:** 🟡 Fixes committed, deployment testing required
**Previous Session:** Fixed unzip→tar bug, created diagnostic scripts, updated CLAUDE.md

---

## What Was Just Fixed (Commit a50fb12)

### ✅ Created Diagnostic Scripts
1. **`scripts/get-trigger.sh`** - Verify trigger Input Set configuration
2. **`scripts/get-delegate-logs.sh <task-id> [minutes]`** - Get delegate execution logs

### ✅ Fixed Script Parsing Bugs
- `scripts/get-pipeline-executions.sh` - Now correctly detects Input Set (was false negative)
- Fixed YAML parsing: `^ *- ` handles variable indentation

### ✅ Fixed Critical Deployment Bug
- **`.harness/.../Coordinated_DB_App_Deployment/v1_0.yaml` line 78**
- Changed: `unzip -q changelog.zip` → `tar -xzf changelog.tar.gz`
- **Why:** Delegate container doesn't have `unzip`, artifacts are `.tar.gz` format

### ✅ Documentation Updates
- **CLAUDE.md** - Added comprehensive Script-First Policy (saves 10-15 min per query)
- **CLAUDE.md** - Updated Historical Mistakes section

---

## Current State

### Delegate
- ✅ **Running and connected** (container: `harness-delegate-psr`)
- ✅ Receiving tasks from Harness
- ✅ Executing shell scripts

### Trigger Configuration
- ✅ **Input Set configured:** `webhook_default`
- ✅ **Pipeline Reference Branch:** `<+trigger.branch>`
- ✅ **Webhook URL** set in GitHub variable `HARNESS_WEBHOOK_URL`

### Known Remaining Issue
**Line 68 in deployment template** still references GitHub Packages:
```bash
PACKAGE_URL="https://maven.pkg.github.com/.../bagel-store-changelog/.../changelog-....zip"
```

But actual artifact is in **GitHub Actions artifact storage** (not Packages).

**Impact:** Artifact download will likely fail with 404 or authentication error.

---

## Your Mission: Test & Fix Deployment

### Step 1: Refresh Template in Harness UI (CRITICAL!)

**Why:** Git Experience has no webhook configured (manual sync required)

1. Go to Harness UI: **Project Setup** → **Templates**
2. Click template: `Coordinated_DB_App_Deployment`
3. Click **Refresh** icon (circular arrow in top right)
4. Verify version shows recent timestamp
5. Check YAML shows `tar -xzf changelog.tar.gz` (line 78)

**Verification:**
```bash
./scripts/get-template.sh Coordinated_DB_App_Deployment | grep "tar -xzf"
```

### Step 2: Trigger New Deployment

```bash
# Option A: Trigger GitHub Actions workflow
gh workflow run main-ci.yml

# Option B: Rerun latest workflow
gh run rerun $(gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

### Step 3: Monitor Pipeline Execution

```bash
# Watch GitHub Actions
gh run watch $(gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId') --exit-status

# Check Harness pipeline (after GHA completes)
./scripts/get-pipeline-executions.sh

# Get latest execution ID
EXEC_ID=$(./scripts/get-pipeline-executions.sh | grep "Execution ID:" | awk '{print $3}')
```

### Step 4: Diagnose Failures

**If pipeline aborts again:**

```bash
# Get delegate logs for latest task
./scripts/get-delegate-logs.sh

# Get detailed execution info
./scripts/get-execution-details.sh $EXEC_ID

# Check trigger configuration
./scripts/get-trigger.sh
```

**Common failure points to check:**
1. ❌ **Artifact download fails (404)** → GitHub Packages vs Actions artifacts issue
2. ❌ **Authentication fails** → Check GitHub PAT in Harness secrets
3. ❌ **tar extraction fails** → Check file format mismatch
4. ❌ **Liquibase fails** → Check database connectivity, license key

---

## Expected Outcomes

### Success Path
1. ✅ GitHub Actions completes (builds changelog artifact + Docker image)
2. ✅ Harness webhook triggered
3. ✅ Pipeline execution starts
4. ✅ Fetch Changelog Artifact step succeeds (downloads + extracts)
5. ✅ Update Database step succeeds (Liquibase runs)
6. ✅ Deploy Application step succeeds (AWS App Runner or local Docker)
7. ✅ Health Check passes
8. ✅ Deployment completes with "Success" status

### Likely Failure: Artifact Download (Line 68 Issue)

**Error will show:**
```
curl: (22) The requested URL returned error: 404 Not Found
```

**Root cause:** Template tries to download from GitHub Packages but artifact is in Actions artifacts storage.

**Fix options:**

**Option A: Download from GitHub Actions API**
```bash
# Get artifact download URL
ARTIFACT_URL=$(gh api repos/{owner}/{repo}/actions/runs/{run_id}/artifacts \
  --jq '.artifacts[] | select(.name | startswith("changelog-")) | .archive_download_url')

# Download artifact
curl -L -H "Authorization: Bearer $GITHUB_TOKEN" -o changelog.tar.gz "$ARTIFACT_URL"
```

**Option B: Publish to GitHub Packages (add step to workflow)**
```yaml
- name: Publish changelog to GitHub Packages
  run: |
    # Upload to maven.pkg.github.com
    # (requires additional configuration)
```

**Option C: Use S3 instead**
```bash
# Upload to S3 in GitHub Actions
aws s3 cp artifacts/changelog.tar.gz s3://bucket/changelog-$VERSION.tar.gz

# Download from S3 in Harness
aws s3 cp s3://bucket/changelog-$VERSION.tar.gz changelog.tar.gz
```

---

## Diagnostic Scripts Reference

All scripts use Script-First Policy (see CLAUDE.md line 59)

### Quick Diagnostics
```bash
./scripts/get-pipeline-executions.sh         # Latest pipeline runs + trigger status
./scripts/get-trigger.sh                     # Verify trigger Input Set configuration
./scripts/get-delegate-logs.sh               # Recent delegate tasks and errors
./scripts/verify-harness-entities.sh         # Verify all Harness resources exist
```

### Detailed Diagnostics
```bash
./scripts/get-execution-details.sh <exec-id>   # Full execution JSON
./scripts/get-stage-logs.sh <exec-id> <stage>  # Logs for specific stage
./scripts/get-delegate-logs.sh <task-id> 30    # Delegate logs for specific task
```

### Example Workflow
```bash
# 1. Check latest execution
./scripts/get-pipeline-executions.sh
# Output shows: Execution ID: ABC123, Status: Aborted

# 2. Get execution details
./scripts/get-execution-details.sh ABC123

# 3. Get delegate logs for debugging
./scripts/get-delegate-logs.sh

# 4. Find task ID from logs, get detailed task logs
./scripts/get-delegate-logs.sh xMOm-CUNQ8mjduw5wQkn3w-DEL 30
```

---

## Critical Context: Script-First Policy

**BEFORE making ANY API call or diagnostic query:**
1. Check `ls scripts/*.sh` for existing script
2. Read CLAUDE.md "Available Harness Scripts" section (line 99)
3. Try the script FIRST
4. If script fails, DEBUG (pwd, permissions, bash invocation)
5. ONLY use manual curl if no script exists

**Why this matters:**
- Saves 10-15 minutes per query
- Avoids variable scoping issues with curl
- Scripts handle authentication, parsing, formatting automatically

---

## Next Steps (Your Tasks)

### Immediate (Required)
1. ✅ **Refresh template in Harness UI** (Git sync required)
2. ✅ **Trigger new deployment** (GitHub Actions workflow)
3. ✅ **Monitor execution** (use diagnostic scripts)
4. ✅ **Diagnose failure point** (likely artifact download)

### After Identifying Failure
5. ⚠️ **Fix artifact download** (choose Option A, B, or C above)
6. ⚠️ **Update deployment template** (line 68 PACKAGE_URL)
7. ⚠️ **Test full deployment** (dev → test → staging → prod)
8. ⚠️ **Verify application health** (check endpoints, database)

### Documentation
9. ⚠️ **Document fix** (update HANDOFF or create new doc)
10. ⚠️ **Update CLAUDE.md** if new patterns discovered
11. ⚠️ **Create script** if manual process needs automation

---

## Success Criteria

✅ **Deployment completes successfully** (Status: Success in Harness)
✅ **All 4 stages pass** (Deploy to Dev, Test, Staging, Production)
✅ **Application accessible** (health check passes)
✅ **Database updated** (Liquibase changesets applied)
✅ **Docker image deployed** (correct version from ghcr.io)

---

## If You Get Stuck

1. **Read CLAUDE.md** - Project conventions, diagnostic approach
2. **Check docs/TROUBLESHOOTING.md** - Common errors and solutions
3. **Use diagnostic scripts** - Don't manually construct curl commands!
4. **Check delegate logs** - Real-time execution details
5. **Verify Harness UI** - Sometimes API lags behind UI state

---

## Quick Reference

### Repository
```
/Users/recampbell/workspace/harness-gha-bagelstore
```

### Key Identifiers
- **Account:** `_dYBmxlLQu61cFhvdkV4Jw`
- **Organization:** `default`
- **Project:** `bagel_store_demo`
- **Pipeline:** `Deploy_Bagel_Store`
- **Trigger:** `GitHub_Actions_CI`
- **Input Set:** `webhook_default`
- **Delegate:** `harness-delegate-psr`

### Environment
- **Deployment Mode:** AWS App Runner (not local Docker)
- **Target Environment:** `psr-dev` (first in pipeline)
- **Delegate Location:** Docker container on local machine
- **Artifacts:** GitHub Actions artifact storage + ghcr.io Docker registry

---

## Recent Commits
```
a50fb12 - Fix: Harness deployment issues and add diagnostic tools
cd6477b - (previous commits)
```

---

Good luck! The hardest debugging is done (found the unzip bug). Now it's just artifact download configuration. Use the diagnostic scripts liberally - they'll save you tons of time! 🚀
