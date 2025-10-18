# AI Handoff: GitHub Actions ECR Migration - Phase 2

## Current Status: ✅ Phase 1 Complete - Infrastructure & Scripts Updated

**Last Updated:** 2025-10-18
**Working Directory:** `/Users/recampbell/workspace/harness-gha-bagelstore`
**Branch:** `main`

---

## What Was Completed (Phase 1)

### 1. IAM Policy Updated ✅
- Updated `scripts/create-harness-aws-user.sh` with ECR Public permissions
- IAM policy version: v1 → v2
- Policy now includes `ECRPublicManagement` statement
- Tested and verified: IAM user can access ECR Public API

### 2. Terraform Infrastructure Created ✅
**New Resources:**
- ECR Public repository: `public.ecr.aws/l1v5b6d6/psr-bagel-store`
- Registry alias: `l1v5b6d6`
- GitHub secrets (automated via Terraform):
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION` (us-east-1)
- GitHub variables:
  - `DEMO_ID` (psr)
  - `DEPLOYMENT_TARGET` (aws)

**Files Created:**
- `terraform/ecr-public.tf`
- `terraform/github-secrets.tf`

**Files Modified:**
- `terraform/main.tf` - Added GitHub provider + us-east-1 AWS provider
- `terraform/outputs.tf` - Added ECR outputs
- `terraform/harness-environments.tf` - Added `ecr_public_alias` variable to all 4 environments

### 3. Deployment Scripts Updated ✅
**Files Modified:**
- `harness/scripts/deploy-application.sh` - Uses ECR Public images from AWS_PARAMS
- `docker-compose-demo.yml` - All 4 environments reference ECR Public
- `.env.example` - Added `ECR_PUBLIC_ALIAS` and `DEMO_ID` variables
- `.harness/.../Coordinated_DB_App_Deployment/v1_0.yaml` - Passes `ecr_public_alias` in AWS_PARAMS

### 4. Testing Completed ✅
- ✅ Manual ECR push test (nginx:latest → test-push) succeeded
- ✅ Image verified in repository
- ✅ GitHub secrets/variables verified
- ✅ Terraform outputs verified

---

## What Needs To Be Done (Phase 2) - YOUR TASK

### Task: Update GitHub Actions Workflow to Push to ECR (NOT GHCR)

**File:** `.github/workflows/main-ci.yml`

**Goal:** Replace GHCR publishing with ECR Public publishing

---

## Step-by-Step Plan for GitHub Actions Update

### Step 1: Remove GHCR Login (~line 167-172)

**DELETE this block:**
```yaml
- name: Log in to GitHub Container Registry
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Step 2: Add ECR Public Login

**ADD this block (after checkout, before metadata extraction):**
```yaml
- name: Log in to AWS Public ECR
  uses: docker/login-action@v3
  with:
    registry: public.ecr.aws
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_REGION: us-east-1
```

### Step 3: Get ECR Registry Alias

**ADD this step (before metadata extraction):**
```yaml
- name: Get ECR registry alias
  id: ecr_alias
  run: |
    ALIAS=$(aws ecr-public describe-registries --region us-east-1 --query 'registries[0].registryAlias' --output text)
    echo "alias=$ALIAS" >> $GITHUB_OUTPUT
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Step 4: Update Metadata Extraction (~line 174-182)

**CHANGE from:**
```yaml
- name: Extract metadata for Docker
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ github.repository_owner }}/${{ steps.demo.outputs.demo_id }}-bagel-store
    tags: |
      type=raw,value=${{ steps.version.outputs.version }}
      type=raw,value=latest
      type=sha,prefix=
```

**TO:**
```yaml
- name: Extract metadata for Docker
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: public.ecr.aws/${{ steps.ecr_alias.outputs.alias }}/${{ steps.demo.outputs.demo_id }}-bagel-store
    tags: |
      type=raw,value=${{ steps.version.outputs.version }}
      type=raw,value=latest
      type=sha,prefix=
```

### Step 5: Update Image Summary (~line 206-209)

**CHANGE the pull command in summary from:**
```yaml
echo "docker pull ${{ env.REGISTRY }}/${{ github.repository_owner }}/${{ steps.demo.outputs.demo_id }}-bagel-store:${{ steps.version.outputs.version }}" >> $GITHUB_STEP_SUMMARY
```

**TO:**
```yaml
echo "docker pull public.ecr.aws/${{ steps.ecr_alias.outputs.alias }}/${{ steps.demo.outputs.demo_id }}-bagel-store:${{ steps.version.outputs.version }}" >> $GITHUB_STEP_SUMMARY
```

---

## Testing Plan (After Workflow Update)

### Test 1: Trigger GitHub Actions Workflow

```bash
# Trigger workflow manually
gh workflow run main-ci.yml

# Monitor execution
gh run watch

# View logs
gh run view --log
```

**Expected Results:**
- ✅ Workflow logs in to AWS Public ECR successfully
- ✅ ECR alias retrieved (`l1v5b6d6`)
- ✅ Image pushed to `public.ecr.aws/l1v5b6d6/psr-bagel-store:VERSION`
- ✅ Image tagged with: version, latest, commit SHA

### Test 2: Verify Image in ECR

```bash
export AWS_PROFILE=liquibase-sandbox-admin

aws ecr-public describe-images \
  --repository-name psr-bagel-store \
  --region us-east-1 \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
  --output table
```

**Expected:** Image with workflow version tag visible

### Test 3: Trigger Full Harness Deployment

```bash
# Push a commit to trigger main-ci.yml
git add .
git commit -m "Feat: Migrate from GHCR to AWS Public ECR"
git push

# Watch GitHub Actions
gh run watch

# Monitor Harness deployment
# Go to: https://app.harness.io/ng/account/_dYBmxlLQu61cFhvdkV4Jw/cd/orgs/default/projects/bagel_store_demo/pipelines/Deploy_Bagel_Store/deployments
```

**Expected Results:**
- ✅ GitHub Actions pushes to ECR
- ✅ Harness webhook triggered
- ✅ "Deploy Application" step uses ECR image: `public.ecr.aws/l1v5b6d6/psr-bagel-store:VERSION`
- ✅ App Runner successfully pulls from ECR
- ✅ Deployment succeeds for all 4 environments

### Test 4: Verify App Runner Image

```bash
# Check App Runner service configuration
SERVICE_ARN=$(cd terraform && terraform output -json app_runner_services | jq -r '.dev.service_arn')

aws apprunner describe-service \
  --service-arn "$SERVICE_ARN" \
  --region us-east-1 \
  --query 'Service.SourceConfiguration.ImageRepository.ImageIdentifier' \
  --output text
```

**Expected:** Shows `public.ecr.aws/l1v5b6d6/psr-bagel-store:VERSION`

---

## Important Notes & Context

### ECR Public Details
- **Repository URI:** `public.ecr.aws/l1v5b6d6/psr-bagel-store`
- **Registry Alias:** `l1v5b6d6` (account-specific, discoverable via API)
- **Region:** us-east-1 (Public ECR only available in us-east-1)
- **Cost:** $0 (free storage and bandwidth for public repositories)

### GitHub Secrets Already Configured
- `AWS_ACCESS_KEY_ID` - Harness deployer IAM user credentials
- `AWS_SECRET_ACCESS_KEY` - Harness deployer IAM user credentials
- `AWS_REGION` - us-east-1
- `LIQUIBASE_LICENSE_KEY` - Already exists (don't touch)

### GitHub Variables Already Configured
- `DEMO_ID` - psr
- `DEPLOYMENT_TARGET` - aws
- `HARNESS_WEBHOOK_URL` - Already exists (don't touch)

### Harness Template Changes
**IMPORTANT:** After modifying `.harness/.../Coordinated_DB_App_Deployment/v1_0.yaml`, you MUST refresh the template in Harness UI:
1. Go to: Project Setup → Templates → Coordinated_DB_App_Deployment
2. Click the **Refresh** icon (circular arrow)
3. Verify changes synced from Git

**Why?** No webhook configured for auto-sync. Manual refresh required after Git push.

### Deployment Script Logic
The `deploy-application.sh` script now:
1. Extracts `ecr_public_alias` from `AWS_PARAMS_JSON`
2. Constructs image URL: `public.ecr.aws/${ECR_ALIAS}/${DEMO_ID}-bagel-store:${VERSION}`
3. Logs the image URL before deploying
4. Passes URL to App Runner API

---

## Validation Checklist

Before marking Phase 2 complete, verify:

- [ ] `.github/workflows/main-ci.yml` updated (no GHCR references)
- [ ] GitHub Actions workflow runs successfully
- [ ] Image pushed to ECR Public (visible in AWS console or via CLI)
- [ ] Image tagged with version, latest, and commit SHA
- [ ] Harness template refreshed in UI
- [ ] Full Harness deployment triggered and successful
- [ ] App Runner pulling from ECR (not GHCR)
- [ ] All 4 environments deployed successfully
- [ ] Health checks passing

---

## Rollback Plan (If Issues Occur)

### Revert GitHub Actions Workflow
```bash
git log --oneline -5
git revert <commit-hash-of-ecr-changes>
git push
```

### Revert Harness Template
```bash
cd .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment
git diff v1_0.yaml  # Review changes
git checkout HEAD~1 -- v1_0.yaml  # Revert to previous version
git commit -m "Rollback: Revert ECR changes in template"
git push
# Then refresh template in Harness UI
```

### Revert Deployment Script
```bash
git checkout HEAD~1 -- harness/scripts/deploy-application.sh
git commit -m "Rollback: Revert deploy script to GHCR"
git push
```

---

## Quick Reference Commands

### View ECR Images
```bash
export AWS_PROFILE=liquibase-sandbox-admin
aws ecr-public describe-images --repository-name psr-bagel-store --region us-east-1
```

### Get ECR Alias
```bash
aws ecr-public describe-registries --region us-east-1 --query 'registries[0].registryAlias' --output text
```

### Terraform Outputs
```bash
cd terraform
terraform output ecr_public_repository_uri
terraform output ecr_public_registry_alias
terraform output github_secrets_configured
```

### GitHub Secrets
```bash
gh secret list
gh variable list
```

### Harness Deployment Logs
```bash
# Get latest execution
./scripts/get-pipeline-executions.sh

# Get specific execution details
./scripts/get-execution-details.sh <execution_id>

# Get stage logs
./scripts/get-stage-logs.sh <execution_id> "Deploy Application"
```

---

## Files Modified Summary

### Phase 1 (Already Complete):
1. ✅ `scripts/create-harness-aws-user.sh` - ECR permissions
2. ✅ `terraform/main.tf` - GitHub provider + us-east-1
3. ✅ `terraform/ecr-public.tf` - NEW
4. ✅ `terraform/github-secrets.tf` - NEW
5. ✅ `terraform/outputs.tf` - ECR outputs
6. ✅ `terraform/harness-environments.tf` - ecr_public_alias variable
7. ✅ `harness/scripts/deploy-application.sh` - ECR image logic
8. ✅ `docker-compose-demo.yml` - ECR references
9. ✅ `.env.example` - ECR variables
10. ✅ `.harness/.../Coordinated_DB_App_Deployment/v1_0.yaml` - Pass ECR alias

### Phase 2 (YOUR TASK):
1. ⏳ `.github/workflows/main-ci.yml` - Replace GHCR with ECR

---

## Success Criteria

**Phase 2 is complete when:**
1. ✅ No GHCR references in `.github/workflows/main-ci.yml`
2. ✅ GitHub Actions pushes to ECR Public successfully
3. ✅ Harness deploys from ECR Public successfully
4. ✅ App Runner services running ECR images
5. ✅ All tests passing
6. ✅ Documentation updated (if needed)

---

## Next AI Session: Start Here

```bash
# 1. Verify current state
cd /Users/recampbell/workspace/harness-gha-bagelstore
git status
terraform output ecr_public_repository_uri
gh secret list

# 2. Update GitHub Actions workflow
# Follow Step 1-5 above to modify .github/workflows/main-ci.yml

# 3. Test the changes
gh workflow run main-ci.yml
gh run watch

# 4. Verify ECR image pushed
export AWS_PROFILE=liquibase-sandbox-admin
aws ecr-public describe-images --repository-name psr-bagel-store --region us-east-1

# 5. Trigger full deployment
git add .
git commit -m "Feat: Migrate from GHCR to AWS Public ECR"
git push

# 6. Monitor Harness deployment
# (Use Harness UI or scripts/get-pipeline-executions.sh)
```

---

**Repository:** `/Users/recampbell/workspace/harness-gha-bagelstore`
**Branch:** `main`
**AWS Profile:** `liquibase-sandbox-admin`
**Demo ID:** `psr`
**ECR Alias:** `l1v5b6d6`

**Take it from here! 🚀**
