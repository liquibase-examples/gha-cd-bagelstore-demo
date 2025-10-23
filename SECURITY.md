# Security & Secrets

## GitHub Secrets (Required for CI/CD)

These secrets must be configured in GitHub repository settings:

- `AWS_ACCESS_KEY_ID` - AWS credentials for S3 and Secrets Manager
- `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `LIQUIBASE_LICENSE_KEY` - **Required!** Liquibase Pro/Secure license
- `HARNESS_WEBHOOK_URL` - Harness pipeline webhook
- `DEMO_ID` - Demo instance identifier (e.g., "demo1")

**How to set:**
```bash
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set LIQUIBASE_LICENSE_KEY
```

## Harness Secrets (Required for Deployment)

These secrets are managed via Harness UI or Terraform:

- `github_pat` - GitHub Personal Access Token (scopes: `repo`, `read:packages`)
- `aws_access_key_id` - AWS Access Key for deployments
- `aws_secret_access_key` - AWS Secret Key for deployments
- `liquibase_license_key` - Liquibase Pro/Secure license key

**Terraform creates these automatically** when you run `terraform apply` (see [terraform/README.md](terraform/README.md)).

## Security-Sensitive Files

### Never commit these

Files in `.gitignore` that contain credentials:

- `app/.env` - Local database credentials
- `terraform/*.tfvars` - Infrastructure secrets (AWS credentials, demo IDs)
- `harness/.env` - Harness delegate credentials and API keys

**Verify gitignore is working:**
```bash
git check-ignore -v app/.env terraform/terraform.tfvars harness/.env
```

### Always commit these

Template files with placeholder values:

- `app/.env.example` - Template for local development
- `terraform/terraform.tfvars.example` - Infrastructure configuration template
- `harness/.env.example` - Harness delegate configuration template

## Pre-Commit Security Checks

Before committing, run these checks:

```bash
# Verify no secrets in staged files
git diff --staged | grep -i "password\|secret\|token\|key"

# Check .gitignore is working
git check-ignore -v app/.env terraform/terraform.tfvars harness/.env
```

## Obtaining Credentials

### Liquibase License Key

- **Where to get:** https://www.liquibase.com/trial
- **Required for:** Flow files, policy checks, CI/CD workflows
- **Environment variable:** `LIQUIBASE_LICENSE_KEY`

### GitHub Personal Access Token

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token
3. Scopes: `repo`, `read:packages`
4. Copy token (shown only once!)
5. Add to Harness Secrets as `github_pat`

### AWS Credentials

See [docs/AWS_SETUP.md](docs/AWS_SETUP.md) for AWS SSO and credentials configuration.

### Harness API Token

1. Harness UI → Profile icon (top right) → **My Profile**
2. **My API Keys** → **+ API Key**
3. Name it (e.g., "debug-api-key") → **Save**
4. **+ Token** → Name it → Set expiration (30 days recommended)
5. **Generate Token** → **Copy immediately** (shown only once!)
6. Add to `harness/.env`: `HARNESS_API_KEY=pat.xxxxx.yyyyy.zzzzz`

## Security Best Practices

### Terraform Files

- ❌ No hardcoded AWS account names or IDs
- ❌ No hardcoded VPC/subnet/security group IDs
- ❌ No organization-specific values in `default` blocks
- ✅ All secrets use variables (never hardcoded)
- ✅ `terraform.tfvars.example` includes all required variables

### Application Files

- ❌ No credentials in code
- ✅ Use `.env` files for local development
- ✅ Use AWS Secrets Manager for production
- ✅ `.env.example` exists with placeholders

## Incident Response

If secrets are accidentally committed:

1. **Immediately rotate the exposed credentials**
2. Remove from Git history using `git filter-branch` or BFG Repo-Cleaner
3. Force push to remote (destructive operation - coordinate with team)
4. Verify new credentials are configured in GitHub Secrets and Harness
5. Document incident and update security checklist if needed

## Questions?

- See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow
- See [docs/AWS_SETUP.md](docs/AWS_SETUP.md) for AWS-specific security
- See [harness/README.md](harness/README.md) for Harness secrets management
