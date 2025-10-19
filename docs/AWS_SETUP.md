# AWS Configuration Guide

Comprehensive guide for AWS configuration, including SSO, access keys, and troubleshooting.

## Table of Contents

1. [Authentication Methods](#authentication-methods)
2. [Configure AWS SSO](#configure-aws-sso)
3. [Configure IAM Access Keys](#configure-iam-access-keys)
4. [Common AWS Issues](#common-aws-issues)
5. [Terraform Security Best Practices](#terraform-security-best-practices)

---

## Authentication Methods

### Choose Your AWS Authentication Method

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **AWS SSO** | Enterprise/Organization accounts | Secure, temporary credentials, MFA support | Requires SSO setup, sessions expire |
| **IAM Access Keys** | Personal AWS accounts, CI/CD | Simple setup, long-lived | Less secure, manual rotation needed |

**Decision Guide:**
- ✅ **Use AWS SSO** if your organization uses AWS SSO
- ✅ **Use Access Keys** if you have a personal AWS account or simple setup
- ⚠️ Never commit access keys to Git

---

## Configure AWS SSO

### Prerequisites

- Your organization must have AWS SSO configured
- You need your SSO start URL (e.g., `https://mycompany.awsapps.com/start`)

### Setup Steps

**1. Run the SSO configuration wizard:**
```bash
aws configure sso
```

**2. Enter your organization's SSO details when prompted:**
```
SSO start URL: https://your-org.awsapps.com/start
SSO region: us-east-1
SSO registration scopes: sso:account:access
```

**3. Authentication:**
- A browser will open for authentication
- Log in with your organization credentials
- Approve the AWS CLI access request

**4. Select your AWS account and role from the list**

**5. Configure the CLI profile:**
```
CLI default client Region: us-east-1
CLI default output format: json
CLI profile name: my-project
```

**6. Log in to activate your SSO session:**
```bash
aws sso login --profile my-project
```

**7. Set as active profile:**
```bash
export AWS_PROFILE=my-project
```

Make permanent by adding to `~/.zshrc` or `~/.bashrc`:
```bash
echo 'export AWS_PROFILE=my-project' >> ~/.zshrc
```

**8. Verify it works:**
```bash
aws sts get-caller-identity
```

### SSO Session Management

**Login:**
```bash
aws sso login --profile <profile-name>
```

**Check session status:**
```bash
./scripts/setup/diagnose-aws.sh
```

**Session expiration:** SSO sessions typically expire after 8-12 hours. Re-run `aws sso login` when expired.

---

## Configure IAM Access Keys

### Prerequisites

- AWS account with IAM user created
- Access key ID and secret access key

### Create Access Keys

1. Log in to [AWS Console](https://console.aws.amazon.com)
2. Go to IAM → Users → Your User → Security Credentials
3. Click "Create access key" → Choose "Command Line Interface (CLI)"
4. Save the Access Key ID and Secret Access Key

### Configure AWS CLI

```bash
aws configure
```

Enter your credentials when prompted:
```
AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name: us-east-1
Default output format: json
```

### Verify Configuration

```bash
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAIOSFODNN7EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

---

## Common AWS Issues

**From actual user struggles - check these first:**

| Issue | Detection | Solution |
|-------|-----------|----------|
| **Typo in path** | `~/.aaws/` exists | `./scripts/setup/diagnose-aws.sh` detects this |
| **Expired SSO session** | "ExpiredToken" error | `aws sso login --profile <name>` |
| **Wrong profile active** | Commands use wrong account | `export AWS_PROFILE=<correct-profile>` |
| **Multiple configure attempts** | User confusion | See decision tree (SSO vs keys) above |
| **Missing credentials** | "Unable to locate credentials" | `./scripts/setup/diagnose-aws.sh` shows how to fix |

### Always Run Diagnostics First

```bash
./scripts/setup/diagnose-aws.sh
```

Script will show:
- ✓ All configured profiles
- ✓ Which profile is active
- ✓ SSO session status
- ✓ Exact command to fix issues

---

### Detailed Issue Solutions

**Problem:** AWS credentials not configured
```
Unable to locate credentials
```

**Solution:**
```bash
# Configure AWS credentials
aws configure sso  # For SSO
# Or
aws configure      # For access keys

# Verify
aws sts get-caller-identity

# If still not working
./scripts/setup/diagnose-aws.sh
```

---

**Problem:** SSO session expired
```
An error occurred (ExpiredToken) when calling the GetCallerIdentity operation
```

**Solution:**
```bash
# Login again
aws sso login --profile <your-profile-name>

# Verify
aws sts get-caller-identity
```

---

**Problem:** Wrong AWS profile active
```
Using credentials from a different account than expected
```

**Solution:**
```bash
# List all profiles
aws configure list-profiles

# Set the correct profile
export AWS_PROFILE=<profile-name>

# Verify which profile is active
./scripts/setup/diagnose-aws.sh
```

---

**Problem:** Typo in AWS config path
```
~/.aaws/credentials or ~/.aaws/config exists
```

**Solution:**
```bash
# The correct path is ~/.aws/ (not ~/.aaws/)
# Move files to correct location
mv ~/.aaws/* ~/.aws/
rmdir ~/.aaws
```

---

**Problem:** Invalid AWS permissions
```
AccessDenied errors when running AWS commands
```

**Solution:**
```bash
# Check which permissions you have
./scripts/setup/diagnose-aws.sh

# The script will test:
# - S3 access (required for Liquibase flows)
# - Secrets Manager access (required for DB credentials)
# - RDS access (required for database)

# Contact your AWS administrator if you're missing permissions
```

---

### SSO-Specific Issues

**Common SSO Issues:**

| Problem | Solution |
|---------|----------|
| "SSO session expired" | Run: `aws sso login --profile <profile-name>` |
| "No profile specified" | Set: `export AWS_PROFILE=<profile-name>` |
| "Invalid grant" error | Re-run: `aws configure sso` |

---

## Terraform Security Best Practices

### Environment-Specific Values

**IMPORTANT:** Never hardcode AWS environment-specific values in Terraform files.

**Always parameterize via variables:**
- ✅ Account identifiers/names
- ✅ VPC IDs (use `data.aws_vpc.default`)
- ✅ Subnet IDs (use `data.aws_subnets.default`)
- ✅ Security group IDs
- ✅ IAM role names/ARNs
- ✅ Region names

### How to Check

```bash
# Review all .tf files for hardcoded values
cd terraform
grep -r "vpc-\|sg-\|arn:aws:iam" *.tf

# Verify all environment-specific values are in variables.tf or terraform.tfvars
cat variables.tf terraform.tfvars.example

# Review default tags (should not include org-specific values)
grep -A5 "common_tags" variables.tf
```

### Pattern for Custom Tags

**variables.tf:**
```hcl
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project = "bagel-store-demo"
    # Do NOT include org/account-specific tags here
  }
}
```

**terraform.tfvars (user-provided):**
```hcl
common_tags = {
  Account     = "my-org-name"
  project     = "bagel-store-demo"
  cost_center = "engineering"
}
```

### Security Review Before Sharing

```bash
# Check for hardcoded AWS-specific values
cd terraform
grep -r "vpc-\|sg-\|arn:aws:iam" *.tf

# Verify all values are parameterized
cat variables.tf terraform.tfvars.example
```

---

## Additional Resources

- **AWS CLI Documentation:** https://docs.aws.amazon.com/cli/
- **AWS SSO Documentation:** https://docs.aws.amazon.com/singlesignon/
- **IAM Best Practices:** https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- **Terraform AWS Provider:** https://registry.terraform.io/providers/hashicorp/aws/

---

**For complete setup instructions, see [SETUP.md](../SETUP.md).**

**For troubleshooting AWS issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).**
