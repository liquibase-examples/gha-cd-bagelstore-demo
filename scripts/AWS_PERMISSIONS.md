# AWS IAM Permissions for Harness Deployment

This document explains the IAM permissions required for the Harness Bagel Store deployment.

## Quick Start

Run the automated script to create an IAM user with the correct permissions:

```bash
./scripts/create-harness-aws-user.sh
```

The script will:
1. Create IAM user: `harness-bagel-store-deployer`
2. Create custom policy: `HarnessBagelStoreDeploymentPolicy`
3. Generate access keys
4. Display credentials to add to `terraform/terraform.tfvars`

## Required AWS Resources and Permissions

### 1. RDS (Relational Database Service)
**Resources Created:**
- PostgreSQL RDS instance (db.t3.micro)
- DB subnet group
- Security group for RDS

**Required Permissions:**
- `rds:CreateDBInstance` - Create the PostgreSQL database
- `rds:DeleteDBInstance` - Destroy resources
- `rds:DescribeDBInstances` - Query database state
- `rds:ModifyDBInstance` - Update database configuration
- `rds:CreateDBSubnetGroup` - Create subnet group
- `rds:DeleteDBSubnetGroup` - Destroy subnet group
- `rds:DescribeDBSubnetGroups` - Query subnet groups
- `rds:AddTagsToResource` - Tag resources with demo_id
- `rds:ListTagsForResource` - Read resource tags

### 2. App Runner
**Resources Created:**
- 4 App Runner services (dev, test, staging, prod)
- Auto-scaling configuration (fixed 1 instance)

**Required Permissions:**
- `apprunner:CreateService` - Deploy Flask applications
- `apprunner:DeleteService` - Destroy services
- `apprunner:DescribeService` - Query service state
- `apprunner:UpdateService` - Deploy new versions (used by Harness)
- `apprunner:ListServices` - List existing services
- `apprunner:CreateAutoScalingConfiguration` - Set instance count
- `apprunner:DeleteAutoScalingConfiguration` - Destroy configuration
- `apprunner:DescribeAutoScalingConfiguration` - Query scaling settings
- `apprunner:ListAutoScalingConfigurations` - List configurations
- `apprunner:TagResource` - Tag services with demo_id
- `apprunner:UntagResource` - Remove tags
- `apprunner:ListTagsForResource` - Read service tags

### 3. Secrets Manager
**Resources Created:**
- RDS username secret
- RDS password secret

**Required Permissions:**
- `secretsmanager:CreateSecret` - Store database credentials
- `secretsmanager:DeleteSecret` - Destroy secrets
- `secretsmanager:DescribeSecret` - Query secret metadata
- `secretsmanager:GetSecretValue` - Read credentials (used by App Runner and Liquibase)
- `secretsmanager:PutSecretValue` - Update credential values
- `secretsmanager:UpdateSecret` - Modify secret configuration
- `secretsmanager:TagResource` - Tag secrets with demo_id
- `secretsmanager:UntagResource` - Remove tags
- `secretsmanager:ListSecrets` - List existing secrets

### 4. S3
**Resources Created:**
- Liquibase flows bucket (public read)
- Operation reports bucket (private)
- Flow files: pr-validation-flow.yaml, main-deployment-flow.yaml
- Policy checks configuration

**Required Permissions:**
- `s3:CreateBucket` - Create S3 buckets
- `s3:DeleteBucket` - Destroy buckets
- `s3:ListBucket` - List bucket contents
- `s3:GetBucketLocation` - Query bucket region
- `s3:GetBucketVersioning` - Check versioning status
- `s3:PutBucketVersioning` - Enable versioning
- `s3:GetBucketPublicAccessBlock` - Check public access settings
- `s3:PutBucketPublicAccessBlock` - Configure public access
- `s3:GetBucketPolicy` - Read bucket policy
- `s3:PutBucketPolicy` - Set bucket policy (public read for flows)
- `s3:DeleteBucketPolicy` - Remove bucket policy
- `s3:GetLifecycleConfiguration` - Check lifecycle rules
- `s3:PutLifecycleConfiguration` - Set lifecycle (30-day deletion for reports)
- `s3:PutObject` - Upload flow files and reports
- `s3:GetObject` - Download flow files (used by Liquibase)
- `s3:DeleteObject` - Remove objects
- `s3:GetBucketTagging` - Read bucket tags
- `s3:PutBucketTagging` - Tag buckets with demo_id

### 5. IAM (Identity and Access Management)
**Resources Created:**
- App Runner instance role
- Policy allowing access to Secrets Manager

**Required Permissions:**
- `iam:CreateRole` - Create App Runner service role
- `iam:DeleteRole` - Destroy roles
- `iam:GetRole` - Query role details
- `iam:PassRole` - Allow App Runner to assume role
- `iam:AttachRolePolicy` - Attach managed policies
- `iam:DetachRolePolicy` - Remove managed policies
- `iam:PutRolePolicy` - Create inline policies
- `iam:DeleteRolePolicy` - Remove inline policies
- `iam:GetRolePolicy` - Read inline policies
- `iam:ListRolePolicies` - List inline policies
- `iam:ListAttachedRolePolicies` - List managed policies
- `iam:TagRole` - Tag roles with demo_id
- `iam:UntagRole` - Remove role tags

### 6. EC2/VPC (for RDS)
**Resources Created:**
- Security group for RDS (allows PostgreSQL traffic)
- Uses default VPC and subnets

**Required Permissions:**
- `ec2:DescribeVpcs` - Find default VPC
- `ec2:DescribeSubnets` - Find available subnets
- `ec2:DescribeSecurityGroups` - Check existing security groups
- `ec2:CreateSecurityGroup` - Create RDS security group
- `ec2:DeleteSecurityGroup` - Destroy security group
- `ec2:AuthorizeSecurityGroupIngress` - Allow inbound PostgreSQL (5432)
- `ec2:AuthorizeSecurityGroupEgress` - Allow outbound traffic
- `ec2:RevokeSecurityGroupIngress` - Remove inbound rules
- `ec2:RevokeSecurityGroupEgress` - Remove outbound rules
- `ec2:DescribeNetworkInterfaces` - Query network interfaces
- `ec2:CreateTags` - Tag security groups with demo_id
- `ec2:DeleteTags` - Remove tags
- `ec2:DescribeTags` - Read tags

### 7. Route53 (Optional - DNS)
**Resources Created:**
- Custom DNS records (only if `enable_route53 = true`)

**Required Permissions:**
- `route53:GetHostedZone` - Read hosted zone details
- `route53:ListHostedZones` - List available zones
- `route53:ChangeResourceRecordSets` - Create/update DNS records
- `route53:GetChange` - Check DNS change status
- `route53:ListResourceRecordSets` - List existing records

**Note:** Route53 is disabled by default (`enable_route53 = false`). App Runner provides default URLs.

## Deployment Modes

### AWS Mode (`deployment_mode = "aws"`)
- Creates all AWS resources listed above
- **Cost:** ~$37-42/month (RDS + 4 App Runner services)
- **Use Case:** Production-like demo, showcase AWS integrations

### Local Mode (`deployment_mode = "local"`)
- Skips ALL AWS resource creation
- Uses Docker Compose on localhost
- **Cost:** $0
- **Use Case:** Fast iteration, offline demos, cost-conscious testing

**In local mode, the AWS credentials stored in Harness are NOT used by the pipeline.**

## Security Best Practices

1. **Least Privilege:** The custom policy grants only the permissions needed for this demo
2. **Resource Scoping:** Consider adding `Resource` restrictions instead of `*` for production
3. **MFA:** Enable MFA on the AWS account
4. **Rotation:** Rotate access keys regularly
5. **Monitoring:** Enable CloudTrail to audit API calls
6. **Cleanup:** Delete the IAM user and resources after demo completion

## Cleanup

To remove the IAM user and policy:

```bash
# Get values from script output
USER_NAME="harness-bagel-store-deployer"
POLICY_NAME="HarnessBagelStoreDeploymentPolicy"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Delete access keys
aws iam list-access-keys --user-name "${USER_NAME}" --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
while read key_id; do
    aws iam delete-access-key --user-name "${USER_NAME}" --access-key-id "${key_id}"
done

# Detach policy
aws iam detach-user-policy \
    --user-name "${USER_NAME}" \
    --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

# Delete user
aws iam delete-user --user-name "${USER_NAME}"

# Delete policy
aws iam delete-policy --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"
```

## Alternative: Use Dummy Credentials for Local Mode

If you're only using `deployment_mode = "local"`, you can skip creating real AWS credentials:

```hcl
# In terraform/terraform.tfvars
deployment_mode = "local"

# These won't be used in local mode
aws_access_key_id = "DUMMY_KEY_FOR_LOCAL_MODE"
aws_secret_access_key = "DUMMY_SECRET_FOR_LOCAL_MODE"
```

The Harness pipeline checks the `DEPLOYMENT_TARGET` environment variable and routes to Docker Compose instead of AWS.

## Questions?

- **Why so many permissions?** Each AWS service (RDS, App Runner, S3, etc.) requires its own set of permissions
- **Can I reduce permissions?** Yes, but requires testing to ensure Terraform and Harness work correctly
- **What about IAM roles instead of users?** Good for production, but IAM users with access keys are simpler for demos
- **Do I need all these for local mode?** No, but Terraform still requires valid AWS credentials to initialize the AWS provider
