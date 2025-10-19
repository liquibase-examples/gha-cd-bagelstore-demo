# IAM Setup Instructions for SSM + Terraform Integration

## Overview

This document describes the IAM permissions required for the new architecture where:
- Harness CD writes SSM parameters and runs Terraform Apply
- Terraform reads SSM parameters and manages App Runner services

## Required IAM Policies

### 1. Harness Delegate Policy

**Who needs this:** The AWS IAM role or user that the Harness delegate uses.

**Policy file:** `docs/IAM_POLICY_HARNESS_DELEGATE.json`

**How to apply:**

```bash
# If using IAM user (current setup - harness-bagel-store-deployer)
AWS_PROFILE=liquibase-sandbox-admin aws iam put-user-policy \
  --user-name harness-bagel-store-deployer \
  --policy-name HarnessTerraformSSMAccess \
  --policy-document file://docs/IAM_POLICY_HARNESS_DELEGATE.json

# OR if using IAM role (recommended for production)
AWS_PROFILE=liquibase-sandbox-admin aws iam put-role-policy \
  --role-name <harness-delegate-role-name> \
  --policy-name HarnessTerraformSSMAccess \
  --policy-document file://docs/IAM_POLICY_HARNESS_DELEGATE.json
```

### 2. GitHub Actions User (Minimal - SSM Write Only)

**Who needs this:** The `harness-bagel-store-deployer` IAM user (used by GitHub Actions).

**Note:** GitHub Actions NO LONGER needs App Runner permissions. It only writes SSM parameters.

**Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SSMParameterWrite",
      "Effect": "Allow",
      "Action": [
        "ssm:PutParameter",
        "ssm:GetParameter"
      ],
      "Resource": [
        "arn:aws:ssm:us-east-1:907240911534:parameter/psr/image-tags/*"
      ]
    }
  ]
}
```

**GitHub Actions does NOT need:**
- ❌ App Runner permissions (Terraform handles this)
- ❌ Secrets Manager permissions (not used in CI)
- ❌ RDS permissions (not used in CI)

## Verification

### Verify Harness Delegate Has Correct Permissions

```bash
# Check if policy is attached
AWS_PROFILE=liquibase-sandbox-admin aws iam list-user-policies \
  --user-name harness-bagel-store-deployer

# Should show: HarnessTerraformSSMAccess

# Get policy details
AWS_PROFILE=liquibase-sandbox-admin aws iam get-user-policy \
  --user-name harness-bagel-store-deployer \
  --policy-name HarnessTerraformSSMAccess
```

### Test SSM Access

```bash
# Write parameter (simulating Harness)
aws ssm put-parameter \
  --name "/psr/image-tags/test-access" \
  --value "test-123" \
  --type String \
  --overwrite

# Read parameter (simulating Terraform)
aws ssm get-parameter \
  --name "/psr/image-tags/test-access" \
  --query 'Parameter.Value' \
  --output text

# Clean up
aws ssm delete-parameter --name "/psr/image-tags/test-access"
```

### Test S3 State Access

```bash
# List state bucket (simulating Terraform)
aws s3 ls s3://907240911534-psr-terraform-state/

# Check state file exists
aws s3 ls s3://907240911534-psr-terraform-state/bagel-store/terraform.tfstate
```

## Current IAM User: harness-bagel-store-deployer

**Account:** 907240911534
**Purpose:** Used by both GitHub Actions AND Harness delegate
**Current permissions:** Mixed (has old deploy-application.sh permissions)

**Action required:** Apply the new `HarnessTerraformSSMAccess` policy to replace old permissions.

## Security Notes

1. **Principle of Least Privilege:**
   - GitHub Actions: Only SSM write for image tags
   - Harness Delegate: Full Terraform + SSM access

2. **Resource Scoping:**
   - All permissions scoped to `/psr/*` or `bagel-store-psr-*` resources
   - EC2 Describe operations require `Resource: "*"` (AWS limitation)

3. **Secrets:**
   - RDS credentials: Accessed via Secrets Manager (already configured)
   - Terraform state: Encrypted in S3 (AES256)
   - SSM parameters: Not encrypted (don't contain secrets, only image tags)

## Troubleshooting

### Error: "AccessDenied" when reading SSM parameter

**Symptom:** Terraform fails with `AccessDenied` on `data.aws_ssm_parameter.image_tag`

**Fix:**
```bash
# Verify parameter exists
aws ssm get-parameter --name "/psr/image-tags/dev"

# Verify IAM permissions
aws iam get-user-policy \
  --user-name harness-bagel-store-deployer \
  --policy-name HarnessTerraformSSMAccess \
  | jq '.PolicyDocument.Statement[] | select(.Sid == "SSMParameterAccess")'
```

### Error: "AccessDenied" on S3 state file

**Symptom:** Terraform init fails with S3 access error

**Fix:**
```bash
# Verify bucket exists
aws s3 ls s3://907240911534-psr-terraform-state/

# Check IAM policy has S3 permissions
aws iam get-user-policy \
  --user-name harness-bagel-store-deployer \
  --policy-name HarnessTerraformSSMAccess \
  | jq '.PolicyDocument.Statement[] | select(.Sid == "TerraformStateAccess")'
```

## Next Steps

1. Apply IAM policy to `harness-bagel-store-deployer` user
2. Test SSM and S3 access (see Verification section)
3. Update Harness template to add SSM write step before Terraform Apply
4. Test full deployment flow
