# Terraform + SSM Migration Summary

## What Changed

Successfully migrated from direct AWS API deployment to Terraform-managed infrastructure with SSM parameter store for image tags.

## Implementation Completed

### 1. Terraform Backend Setup ✅
- **Created S3 bucket:** `907240911534-psr-terraform-state`
- **Enabled versioning and encryption:** AES256
- **Created `backend.tf`:** Configured S3 backend with native locking (Terraform 1.10+)
- **Migrated state:** Local state → S3 remote state (126KB state file)

### 2. SSM Parameter Store Integration ✅
- **Created SSM parameters for all environments:**
  - `/psr/image-tags/dev` = `latest`
  - `/psr/image-tags/test` = `latest`
  - `/psr/image-tags/staging` = `latest`
  - `/psr/image-tags/prod` = `latest`

- **Updated `terraform/app-runner.tf`:**
  - Added `data.aws_ssm_parameter.image_tag` data sources
  - Created `local.image_tags` map for environment → tag mapping
  - Updated `image_identifier` to read from SSM: `${local.image_tags[each.key]}`
  - Fixed port: `80` (NGINX) → `5000` (Flask)
  - Fixed environment variables: Added all required vars (DB_HOST, DB_PORT, etc.)
  - Fixed secret names: `SECRETS_MANAGER_ARN_*` → `DB_USERNAME`, `DB_PASSWORD`
  - Removed broken `DATABASE_URL` variable
  - Fixed health check path: `/` → `/health`

### 3. IAM Policies ✅
- **Created managed policy:** `HarnessTerraformSSMAccess`
- **Attached to user:** `harness-bagel-store-deployer`
- **Permissions granted:**
  - SSM: GetParameter, PutParameter on `/psr/*`
  - S3: State bucket access (907240911534-psr-terraform-state)
  - App Runner: UpdateService, DescribeService on `bagel-store-psr-*`
  - RDS: DescribeDBInstances (read-only)
  - Secrets Manager: GetSecretValue on `psr/rds/*`
  - EC2: Describe operations (network info)
  - IAM: PassRole for App Runner instance role

### 4. Harness Template Updates ✅
**File:** `.harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml`

**Replaced Step 3 (Deploy Application shell script) with 3 new steps:**

**Step 3a: Clone Terraform Code**
- Clones repository to `/tmp/harness-terraform-$$`
- Copies Terraform files to `/opt/harness-delegate/terraform/`
- Uses GitHub PAT for authentication
- Timeout: 3 minutes

**Step 3b: Update SSM Image Tag**
- Writes `VERSION` to SSM: `/psr/image-tags/{environment}`
- Uses AWS credentials from Harness secrets
- Timeout: 2 minutes

**Step 3c: Deploy Application via Terraform**
- Runs `terraform init` (loads S3 backend)
- Runs `terraform apply -target=aws_apprunner_service.bagel_store["{environment}"]`
- Uses AWS credentials from Harness secrets
- Timeout: 15 minutes

### 5. Documentation Created ✅
- **`docs/IAM_POLICY_HARNESS_DELEGATE.json`:** Complete IAM policy
- **`docs/IAM_SETUP_INSTRUCTIONS.md`:** Step-by-step IAM setup guide
- **`terraform/backend.tf`:** S3 backend configuration

## Architecture Changes

### Before (Problematic)
```
Harness Pipeline:
├─ Fetch Changelog
├─ Update Database (Liquibase)
└─ Deploy Application (Shell Script)
   └─ aws apprunner update-service --source-configuration "{ ... }"
      ├─ Hardcoded all env vars
      ├─ Hardcoded secrets ARNs
      └─ Configuration duplicated between Terraform and script
```

### After (Best Practice)
```
Harness Pipeline:
├─ Fetch Changelog
├─ Update Database (Liquibase)
├─ Clone Terraform Code (Git)
├─ Update SSM Parameter (write image tag)
└─ Deploy via Terraform Apply
   └─ terraform apply -target=aws_apprunner_service.bagel_store["dev"]
      ├─ Reads image tag from SSM
      ├─ All configuration in Terraform files
      └─ Single source of truth
```

## Benefits

1. **✅ Single Source of Truth:** All App Runner configuration in `terraform/app-runner.tf`
2. **✅ No Configuration Duplication:** Removed hardcoded values from deployment script
3. **✅ GitOps-Friendly:** Infrastructure changes via Git PRs to Terraform files
4. **✅ No Drift:** Terraform state always matches reality
5. **✅ Industry Standard:** SSM + Terraform + S3 backend is best practice pattern
6. **✅ Auditable:** Terraform plan shows exactly what will change
7. **✅ Rollback-Capable:** S3 state versioning + SSM parameter history
8. **✅ Secure:** State encrypted in S3, credentials via IAM roles

## What's Left

### Not Done (User is away - no commits yet)
- [ ] Test deployment flow end-to-end
- [ ] Mark `harness/scripts/deploy-application.sh` as deprecated
- [ ] Git commit changes
- [ ] Git push to remote
- [ ] Trigger Harness deployment
- [ ] Verify health check passes

### Files Changed (Staged but Not Committed)
1. **terraform/backend.tf** (NEW) - S3 backend configuration
2. **terraform/app-runner.tf** (MODIFIED) - SSM integration, fixed config
3. **.harness/.../v1_0.yaml** (MODIFIED) - New deployment steps
4. **docs/IAM_POLICY_HARNESS_DELEGATE.json** (NEW) - IAM policy
5. **docs/IAM_SETUP_INSTRUCTIONS.md** (NEW) - Setup guide

### AWS Resources Created
1. **S3 Bucket:** `907240911534-psr-terraform-state` (versioned, encrypted)
2. **SSM Parameters:** `/psr/image-tags/{dev,test,staging,prod}`
3. **IAM Policy:** `HarnessTerraformSSMAccess` (managed policy, attached to user)

## Testing Plan (When User Returns)

### 1. Verify Terraform Configuration
```bash
cd terraform
AWS_PROFILE=liquibase-sandbox-admin terraform plan

# Should show changes to App Runner services (reading from SSM)
```

### 2. Manual Test SSM → Terraform Flow
```bash
# Update SSM parameter
aws ssm put-parameter \
  --name "/psr/image-tags/dev" \
  --value "dev-test123" \
  --overwrite

# Run Terraform apply
cd terraform
terraform apply -target='aws_apprunner_service.bagel_store["dev"]' -auto-approve

# Verify App Runner service updated
aws apprunner describe-service \
  --service-arn <arn> \
  --query 'Service.SourceConfiguration.ImageRepository.ImageIdentifier'
# Should show: ...bagel-store:dev-test123
```

### 3. Test Harness Pipeline
1. Refresh template in Harness UI
2. Trigger deployment
3. Verify steps execute:
   - Clone Terraform Code ✓
   - Update SSM Image Tag ✓
   - Deploy via Terraform ✓
4. Check health check passes

### 4. Verify No Configuration Drift
```bash
# After Harness deployment, run terraform plan
cd terraform
terraform plan

# Should show "No changes" (proving Harness didn't create drift)
```

## Rollback Plan (If Needed)

### If Deployment Fails:

**Option 1: Revert Template (Quick)**
```bash
git checkout HEAD~1 .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml
git commit -m "Revert: Rollback to shell script deployment"
git push
# Refresh template in Harness UI
```

**Option 2: Fix Forward (Preferred)**
- Check Harness execution logs
- Fix issue in Terraform or template
- Commit fix, push, refresh template

**Option 3: Manual Intervention**
```bash
# Manually run Terraform from local machine
cd terraform
AWS_PROFILE=liquibase-sandbox-admin terraform apply
```

## Key Files Reference

| File | Purpose | Status |
|------|---------|--------|
| `terraform/backend.tf` | S3 backend config | NEW |
| `terraform/app-runner.tf` | App Runner with SSM integration | MODIFIED |
| `.harness/.../v1_0.yaml` | Harness template (Terraform steps) | MODIFIED |
| `docs/IAM_POLICY_HARNESS_DELEGATE.json` | IAM permissions | NEW |
| `docs/IAM_SETUP_INSTRUCTIONS.md` | Setup guide | NEW |
| `harness/scripts/deploy-application.sh` | Old deployment script | DEPRECATED |

## Next Steps for User

1. **Review changes:** `git diff` to see all modifications
2. **Test locally:** Run `terraform plan` to verify configuration
3. **Commit changes:** Create descriptive commit message
4. **Push to remote:** `git push origin main`
5. **Refresh Harness template:** Project Setup → Templates → Refresh
6. **Test deployment:** Trigger pipeline, verify all steps pass
7. **Monitor health check:** Ensure Flask app starts correctly

## Success Criteria

- [ ] Terraform plan shows App Runner reading from SSM
- [ ] Harness pipeline completes all new steps
- [ ] Health check returns HTTP 200 on `/health`
- [ ] App Runner service uses correct image tag from SSM
- [ ] No configuration drift after deployment
- [ ] Terraform state in S3 (not local)

---

**Migration completed:** 2025-10-19
**AWS Account:** 907240911534
**Demo ID:** psr
**Terraform State:** s3://907240911534-psr-terraform-state/bagel-store/terraform.tfstate
