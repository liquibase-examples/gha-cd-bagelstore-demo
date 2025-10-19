# Testing Checklist - Terraform + SSM Migration

## Pre-Deployment Verification

### 1. Verify AWS Resources Exist
```bash
# Check S3 state bucket
aws s3 ls s3://907240911534-psr-terraform-state/bagel-store/
# Expected: terraform.tfstate file

# Check SSM parameters
aws ssm get-parameters \
  --names /psr/image-tags/dev /psr/image-tags/test /psr/image-tags/staging /psr/image-tags/prod \
  --query 'Parameters[*].[Name,Value]' \
  --output table
# Expected: All 4 parameters with value "latest"

# Check IAM policy attached
aws iam list-attached-user-policies --user-name harness-bagel-store-deployer
# Expected: HarnessTerraformSSMAccess
```

### 2. Verify Terraform Configuration
```bash
cd terraform

# Plan should work (reads SSM parameters)
AWS_PROFILE=liquibase-sandbox-admin terraform plan

# Expected output:
# - No errors
# - Shows current state from S3
# - Reads SSM parameters successfully
# - May show changes to App Runner (expected if fixing configuration)
```

### 3. Review Code Changes
```bash
# See what changed in Terraform
git diff terraform/app-runner.tf

# See what changed in Harness template
git diff .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml

# Review new backend config
cat terraform/backend.tf

# Review full summary
cat TERRAFORM_SSM_MIGRATION_SUMMARY.md
```

## Commit & Push

### 4. Create Git Commit
```bash
# Add all changes
git add terraform/backend.tf
git add terraform/app-runner.tf
git add .harness/orgs/default/projects/bagel_store_demo/templates/Coordinated_DB_App_Deployment/v1_0.yaml
git add docs/IAM_POLICY_HARNESS_DELEGATE.json
git add docs/IAM_SETUP_INSTRUCTIONS.md
git add TERRAFORM_SSM_MIGRATION_SUMMARY.md
git add TESTING_CHECKLIST.md
git add MIGRATION_STATUS.txt

# Create commit
git commit -m "Refactor: Migrate to Terraform-managed deployments with SSM parameter store

Architecture Changes:
- Replaced direct AWS CLI deployment with Terraform Apply
- Image tags stored in SSM Parameter Store (/psr/image-tags/*)
- Terraform reads SSM and updates App Runner services
- Single source of truth for all infrastructure configuration

Infrastructure:
- Created S3 backend: 907240911534-psr-terraform-state
- Migrated Terraform state from local to S3 (native locking)
- Created SSM parameters for dev/test/staging/prod environments
- Created IAM managed policy: HarnessTerraformSSMAccess

Terraform Changes:
- terraform/backend.tf: S3 backend with native locking (Terraform 1.10+)
- terraform/app-runner.tf:
  * Added SSM data sources for image tags
  * Fixed port: 80→5000 (NGINX→Flask)
  * Fixed secret variable names: DB_USERNAME, DB_PASSWORD
  * Removed broken DATABASE_URL
  * Added all required env vars (DEMO_USERNAME, DB_HOST, etc.)
  * Fixed health check path: /→/health

Harness Changes:
- .harness/.../v1_0.yaml:
  * Added Step 3a: Clone Terraform Code (Git clone)
  * Added Step 3b: Update SSM Image Tag (writes to SSM)
  * Added Step 3c: Deploy via Terraform Apply (targeted apply)
  * Replaced deploy-application.sh shell script

Benefits:
✅ No configuration duplication
✅ GitOps-friendly (infrastructure changes via Git)
✅ No drift (Terraform state matches reality)
✅ Auditable (Terraform plan shows changes)
✅ Rollback-capable (S3 versioning)

Documentation: See TERRAFORM_SSM_MIGRATION_SUMMARY.md

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Verify commit
git show --stat
```

### 5. Push to Remote
```bash
# Push changes
git push origin main

# Verify pushed
git log origin/main -1
```

## Harness Configuration

### 6. Refresh Harness Template
1. Go to Harness UI: https://app.harness.io
2. Navigate to: **Project Setup** → **Templates**
3. Find template: **Coordinated_DB_App_Deployment** (v1.0)
4. Click **Refresh** icon (circular arrow)
5. Wait for Git sync to complete
6. Verify new steps appear:
   - Clone Terraform Code
   - Update SSM Image Tag
   - Deploy Application via Terraform

## Test Deployment

### 7. Manual Test (Optional - Before Harness)
```bash
# Simulate what Harness will do

# 1. Update SSM parameter
aws ssm put-parameter \
  --name "/psr/image-tags/dev" \
  --value "dev-test123" \
  --type String \
  --overwrite

# 2. Run Terraform apply
cd terraform
AWS_PROFILE=liquibase-sandbox-admin terraform apply \
  -target='aws_apprunner_service.bagel_store["dev"]' \
  -auto-approve

# 3. Verify App Runner updated
aws apprunner describe-service \
  --service-arn arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-dev/c2190e5aab3f40f1a0e22560b9af3633 \
  --query 'Service.SourceConfiguration.ImageRepository.ImageIdentifier'

# Expected: public.ecr.aws/.../psr-bagel-store:dev-test123
```

### 8. Trigger Harness Deployment
```bash
# Option 1: Via GitHub Actions
git commit --allow-empty -m "Test: Trigger Harness deployment"
git push

# Option 2: Manual trigger in Harness UI
# Navigate to Pipelines → Deploy_Bagel_Store → Run
```

### 9. Monitor Harness Execution
**Watch for these steps to complete:**
1. ✅ Fetch Changelog Artifact (~1 min)
2. ✅ Update Database (~3 min)
3. ✅ Clone Terraform Code (~30 sec)
4. ✅ Update SSM Image Tag (~10 sec)
5. ✅ Deploy via Terraform Apply (~5-10 min)
   - Should show: `terraform init` output
   - Should show: `terraform apply` with App Runner changes
   - Should show: "Apply complete!"
6. ✅ Health Check (~30 sec)
   - Should hit: https://ftngew3ms2.us-east-1.awsapprunner.com/health
   - Should return: HTTP 200 {"status": "healthy"}

### 10. Verify Deployment Success
```bash
# Check App Runner service status
aws apprunner describe-service \
  --service-arn arn:aws:apprunner:us-east-1:907240911534:service/bagel-store-psr-dev/c2190e5aab3f40f1a0e22560b9af3633 \
  --query 'Service.Status'

# Expected: RUNNING

# Check health endpoint
curl https://ftngew3ms2.us-east-1.awsapprunner.com/health

# Expected: {"status":"healthy","database":"connected"}

# Check version endpoint
curl https://ftngew3ms2.us-east-1.awsapprunner.com/version

# Expected: {"application":"bagel-store","version":"dev-xxx","environment":"production"}
```

### 11. Verify No Configuration Drift
```bash
# After Harness deployment, run terraform plan again
cd terraform
AWS_PROFILE=liquibase-sandbox-admin terraform plan

# Expected: "No changes. Your infrastructure matches the configuration."
# This proves Harness didn't create drift by manually updating App Runner
```

## Troubleshooting

### If Step "Clone Terraform Code" Fails
**Check:**
- GitHub PAT secret exists in Harness
- PAT has `repo` scope
- Repository name is correct

**Debug:**
```bash
# Test Git clone manually
git clone https://YOUR_PAT@github.com/liquibase-examples/harness-gha-bagelstore.git /tmp/test
```

### If Step "Update SSM Image Tag" Fails
**Check:**
- IAM policy `HarnessTerraformSSMAccess` attached to user
- AWS credentials in Harness secrets are correct

**Debug:**
```bash
# Test SSM write manually
aws ssm put-parameter \
  --name "/psr/image-tags/test" \
  --value "test123" \
  --overwrite
```

### If Step "Deploy via Terraform" Fails
**Check:**
- Terraform files present at `/opt/harness-delegate/terraform/`
- S3 backend accessible
- IAM permissions for App Runner

**Debug:**
```bash
# SSH into delegate or check logs
docker logs harness-delegate-psr --tail 100

# Manual Terraform run
cd /opt/harness-delegate/terraform
terraform init
terraform plan
```

### If Health Check Fails (HTTP 404)
**This was the original issue! Check:**
- App Runner port is 5000 (not 80)
- Health check path is `/health` (not `/`)
- DEMO_USERNAME and DEMO_PASSWORD env vars set
- DB_USERNAME and DB_PASSWORD secrets correctly named

**Debug:**
```bash
# Check App Runner logs
aws logs tail "/aws/apprunner/bagel-store-psr-dev/.../application" --since 10m

# Look for:
# - Flask startup messages
# - Database connection success
# - Port 5000 binding
```

## Rollback Plan

### If Deployment Completely Fails

**Option 1: Revert Git Changes**
```bash
git revert HEAD
git push
# Refresh Harness template
```

**Option 2: Manual Terraform Apply**
```bash
# Set SSM back to working version
aws ssm put-parameter --name "/psr/image-tags/dev" --value "working-version" --overwrite

# Apply Terraform
cd terraform
terraform apply -auto-approve
```

**Option 3: Direct AWS CLI (Emergency)**
```bash
# Update App Runner directly (old way)
aws apprunner update-service \
  --service-arn <arn> \
  --source-configuration '{ "ImageRepository": { "ImageIdentifier": "...:working-version" } }'
```

## Success Criteria

- [x] All AWS resources created (S3, SSM, IAM)
- [x] Terraform state migrated to S3
- [x] IAM policies applied
- [x] Code changes committed and pushed
- [ ] Harness template refreshed
- [ ] Deployment triggered
- [ ] All pipeline steps complete successfully
- [ ] Health check returns HTTP 200
- [ ] App accessible at service URL
- [ ] No configuration drift (terraform plan shows no changes)
- [ ] Logs show correct environment variables
- [ ] Database connection successful

---

**When all checkboxes are complete, the migration is successful!**
