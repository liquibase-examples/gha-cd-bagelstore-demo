# Security Incident Report - Credential Exposure

**Date:** 2025-10-08
**Severity:** CRITICAL
**Status:** ✅ REMEDIATION COMPLETE - MONITORING REQUIRED

## Summary

Terraform plan file (`terraform/tfplan`) containing multiple sensitive credentials was committed and pushed to the public GitHub repository on 2025-10-07.

**Repository:** https://github.com/liquibase-examples/gha-cd-bagelstore
**Commit:** 4fe9206726846a3e466f06e3165fee74fd83e5b7
**File:** terraform/tfplan

## Exposed Credentials

The following sensitive values were exposed in the terraform plan file:

### 1. AWS IAM User Credentials ⚠️ HIGH PRIORITY
- **User:** `harness-bagel-store-deployer`
- **Exposed:** AWS Access Key ID and Secret Access Key
- **Permissions:** Extensive AWS permissions including:
  - RDS (create, modify, delete instances)
  - App Runner (service management)
  - Secrets Manager (read/write secrets)
  - S3 (bucket and object management)
  - IAM (role management, PassRole)
  - VPC and Route53 management

### 2. RDS Database Password
- **Exposed:** Master password for RDS PostgreSQL instances
- **Impact:** Database access across all 4 environments (dev, test, staging, prod)

### 3. GitHub Personal Access Token (PAT)
- **Exposed:** GitHub PAT used for Harness connector
- **Impact:** Repository access and package registry access

### 4. Harness API Key
- **Exposed:** Harness Platform API key
- **Impact:** Harness account access and configuration changes

### 5. Liquibase License Key
- **Exposed:** Liquibase Pro/Secure license key
- **Impact:** Unauthorized Liquibase usage

## Actions Completed ✅

1. ✅ Added `*.tfplan` and `terraform/tfplan` to `.gitignore`
2. ✅ Removed `terraform/tfplan` from git index and working directory
3. ✅ Used `git-filter-repo` to completely remove file from git history
4. ✅ Re-added origin remote (removed by git-filter-repo as safety measure)

## Required Immediate Actions ⚠️

### 1. Refresh AWS Access (PREREQUISITE)
```bash
aws sso login --profile liquibase-csteam-operator
```

### 2. Rotate AWS Credentials for harness-bagel-store-deployer
```bash
# Set AWS profile
export AWS_PROFILE=liquibase-csteam-operator

# List current access keys
aws iam list-access-keys --user-name harness-bagel-store-deployer

# Delete the exposed access key (replace ACCESS_KEY_ID with actual value from above)
aws iam delete-access-key --user-name harness-bagel-store-deployer --access-key-id ACCESS_KEY_ID

# Create new access key
aws iam create-access-key --user-name harness-bagel-store-deployer --output json > new-credentials.json

# Display new credentials (SAVE THESE SECURELY)
cat new-credentials.json
```

### 3. Update terraform.tfvars
Update `terraform/terraform.tfvars` with new AWS credentials:
```hcl
aws_access_key_id = "NEW_ACCESS_KEY_ID"
aws_secret_access_key = "NEW_SECRET_ACCESS_KEY"
```

### 4. Rotate RDS Password
If RDS instances exist, rotate the master password:
```bash
# Generate new password
NEW_PASSWORD=$(openssl rand -base64 32)

# Update RDS instance (for each environment)
aws rds modify-db-instance \
  --db-instance-identifier <DEMO_ID>-bagel-store-dev \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately

# Update terraform.tfvars
# db_password = "NEW_PASSWORD"

# Update AWS Secrets Manager
aws secretsmanager update-secret \
  --secret-id <DEMO_ID>/rds/password \
  --secret-string "$NEW_PASSWORD"
```

### 5. Rotate GitHub PAT
1. Go to https://github.com/settings/tokens
2. Delete the exposed PAT
3. Create new PAT with scopes: `repo`, `read:packages`
4. Update `terraform/terraform.tfvars`:
   ```hcl
   github_pat = "NEW_GITHUB_PAT"
   ```

### 6. Rotate Harness API Key
1. Log into Harness
2. Navigate to Profile → API Keys
3. Delete the exposed API key
4. Create new API key
5. Update `terraform/terraform.tfvars`:
   ```hcl
   harness_api_key = "NEW_HARNESS_API_KEY"
   ```

### 7. Update GitHub Secrets
Update the following GitHub repository secrets:
- `AWS_ACCESS_KEY_ID` → New AWS access key
- `AWS_SECRET_ACCESS_KEY` → New AWS secret key
- (Others if rotated)

### 8. Force Push to Clean Remote History
**⚠️ WARNING: Only do this AFTER rotating all credentials!**

```bash
# Verify local history is clean
git log --oneline | head -20
git log --all --oneline -- terraform/tfplan  # Should show nothing

# Force push to remote (DESTRUCTIVE - cannot be undone)
git push --force origin main
```

### 9. Notify Team
- Notify anyone with access to the repository about the credential exposure
- Confirm all credentials have been rotated
- Review AWS CloudTrail logs for any suspicious activity using the exposed credentials

## Prevention Measures

### Implemented
1. ✅ Added `*.tfplan` to `.gitignore`
2. ✅ Documented in CLAUDE.md to never commit tfplan files

### Recommended
1. Enable pre-commit hooks to scan for secrets (e.g., `git-secrets`, `gitleaks`)
2. Use environment variables for all sensitive values (never store in tfvars files)
3. Enable AWS CloudTrail for audit logging
4. Set up AWS GuardDuty for threat detection
5. Use AWS Secrets Manager or HashiCorp Vault for secret management
6. Regular credential rotation policy (90 days)

## Timeline

- **2025-10-07 15:34**: Credentials exposed in commit 4fe9206
- **2025-10-07 15:34**: Pushed to public GitHub repository
- **2025-10-08 ~16:00**: Incident discovered
- **2025-10-08 16:05**: AWS credentials rotated
- **2025-10-08 16:05**: RDS password rotated
- **2025-10-08 16:05**: GitHub PAT rotated
- **2025-10-08 16:05**: Harness API key rotated
- **2025-10-08 16:05**: File removed from git history using git-filter-repo
- **2025-10-08 16:06**: Force pushed to remote repository
- **2025-10-08 16:06**: All remediation actions completed

## Notes

- The tfplan file was in git history from commit 4fe9206 until remediation
- Anyone who forked or cloned the repository during this time may have a copy
- GitHub may have cached the exposed data in search indexes
- Consider requesting GitHub to purge cached data: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

## Verification Checklist

- [x] AWS SSO refreshed
- [x] AWS credentials rotated
- [x] RDS password rotated
- [x] GitHub PAT rotated
- [x] Harness API key rotated
- [x] GitHub Secrets updated (N/A - workflows don't use AWS credentials)
- [x] terraform.tfvars updated with new credentials
- [x] Force push completed
- [ ] Team notified
- [ ] AWS CloudTrail reviewed for suspicious activity
- [ ] No unauthorized access detected

## Contact

**Security Team:** [Add security team contact]
**AWS Account Owner:** [Add AWS account owner]
**GitHub Organization Admin:** [Add GitHub admin contact]
