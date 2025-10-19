# Local Script Testing Guide

Test Harness deployment scripts locally without triggering the full GitHub Actions + Harness pipeline.

## Quick Start

```bash
cd harness/scripts
./test-scripts-locally.sh all dev
```

## Overview

The `test-scripts-locally.sh` framework allows you to:
- ✅ Test scripts directly in the delegate container
- ✅ Use real AWS resources (RDS, App Runner, S3, Secrets Manager)
- ✅ Debug issues faster (no waiting for GHA + Harness)
- ✅ Iterate on script changes immediately
- ✅ Test individual scripts or the full deployment flow

## Prerequisites

### 1. Delegate Running
```bash
cd harness
docker compose up -d
docker ps | grep harness-delegate-psr  # Should show "Up"
```

### 2. Environment Configuration

Create `harness/.env` with credentials:
```bash
# Required for script testing
DEMO_ID=psr
GITHUB_PAT=ghp_xxxxx  # GitHub Personal Access Token
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=xxxxx
LIQUIBASE_LICENSE_KEY=xxxxx
```

**Security Note:** `harness/.env` is in `.gitignore` - never commit credentials!

### 3. AWS Resources Available

The scripts need these AWS resources (created by Terraform):
- RDS PostgreSQL instance
- App Runner services (dev/test/staging/prod)
- S3 bucket with flow files
- AWS Secrets Manager secrets for RDS credentials

## Usage

### Test Individual Scripts

```bash
# Test changelog artifact download
./test-scripts-locally.sh fetch-changelog-artifact

# Test database update
./test-scripts-locally.sh update-database dev

# Test application deployment
./test-scripts-locally.sh deploy-application dev

# Test health check
./test-scripts-locally.sh health-check dev

# Test instance reporting
./test-scripts-locally.sh fetch-instances dev
```

### Test Full Deployment Flow

```bash
# Run all 5 scripts in sequence for dev environment
./test-scripts-locally.sh all dev

# Test staging environment
./test-scripts-locally.sh all staging
```

## How It Works

The test framework:

1. **Reads configuration** from `harness/.env` and git state
2. **Builds JSON parameters** matching what Harness provides
3. **Executes scripts** inside the delegate container using `docker exec`
4. **Uses real AWS resources** (same as production pipeline)

### Simulated Harness Environment

The script creates the same parameters that Harness passes:

```bash
# AWS Parameters (infrastructure info)
{
  "jdbc_url": "jdbc:postgresql://...:5432/dev",
  "aws_region": "us-east-1",
  "liquibase_flows_bucket": "bagel-store-psr-liquibase-flows",
  "rds_endpoint": "bagel-store-psr-rds.us-east-1.rds.amazonaws.com",
  "app_runner_service_arn": "arn:aws:apprunner:...",
  ...
}

# Secrets (credentials)
{
  "aws_access_key_id": "AKIA...",
  "aws_secret_access_key": "xxxxx",
  "liquibase_license_key": "xxxxx"
}
# Note: DB credentials fetched via Liquibase native AWS Secrets Manager
```

## Development Workflow

### Fast Iteration Cycle

1. **Edit script** (e.g., `update-database.sh`)
2. **Test locally**:
   ```bash
   ./test-scripts-locally.sh update-database dev
   ```
3. **Debug issues** by checking script output
4. **Repeat** until working
5. **Commit** and push when ready

**Time savings:** ~2 minutes (local test) vs ~10 minutes (full GHA + Harness pipeline)

### Example: Debugging Database Connection

```bash
# Test just the database update step
./test-scripts-locally.sh update-database dev

# Look for errors
# - AWS Secrets Manager resolution
# - Liquibase flow file validation
# - Database connectivity
# - Policy check failures

# Edit script if needed
vim harness/scripts/update-database.sh

# Test again immediately
./test-scripts-locally.sh update-database dev
```

## Troubleshooting

### Script Not Found

```bash
# Verify scripts are mounted in delegate
docker exec harness-delegate-psr ls -la /opt/harness-delegate/scripts/

# If missing, restart delegate
cd harness && docker compose restart
```

### GitHub PAT Missing

```bash
# Error: "⚠️  Warning: GITHUB_PAT not set"
# Add to harness/.env:
echo "GITHUB_PAT=ghp_xxxxx" >> harness/.env
```

### AWS Credentials Missing

```bash
# Error: Secrets show "PLACEHOLDER"
# Add to harness/.env:
cat >> harness/.env <<EOF
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=xxxxx
LIQUIBASE_LICENSE_KEY=xxxxx
EOF
```

### AWS Resources Not Found

```bash
# Error: RDS instance not found, App Runner service not found
# Run Terraform to create resources:
cd terraform
terraform apply
```

### Permission Denied

```bash
# Make test script executable
chmod +x harness/scripts/test-scripts-locally.sh
```

## Viewing Detailed Output

### Script Logs

All script output appears in your terminal in real-time.

### Delegate Logs

Watch delegate logs in another terminal:
```bash
docker logs -f harness-delegate-psr
```

### Liquibase Flow Logs

If `update-database.sh` is running, you'll see:
- Flow file validation
- Policy check results
- Database connection status
- SQL execution details

## Differences from Production

| Aspect | Local Testing | Production Pipeline |
|--------|---------------|---------------------|
| **Trigger** | Manual script execution | GitHub Actions webhook |
| **Execution** | Your terminal | Harness UI |
| **Credentials** | `harness/.env` file | Harness Secrets Manager |
| **Artifacts** | Must exist in GitHub Packages | Created by GHA |
| **Duration** | ~2-5 minutes | ~10-15 minutes |
| **Visibility** | Terminal output | Harness execution logs |

## Advanced Usage

### Test Specific Environment

```bash
# Test dev
./test-scripts-locally.sh all dev

# Test staging
./test-scripts-locally.sh all staging

# Test production (be careful!)
./test-scripts-locally.sh all prod
```

### Override Version

Edit the script to test a specific version:
```bash
# In test-scripts-locally.sh, change:
VERSION="v1.2.3"  # Instead of auto-detecting from git
```

### Dry Run Mode

To see commands without executing:
```bash
# Add this after line 167 in test-scripts-locally.sh:
echo "DRY RUN MODE - Commands shown but not executed"
exit 0
```

### Test with Local Changes

Scripts are mounted read-only, so changes require delegate restart:
```bash
# 1. Edit script
vim harness/scripts/update-database.sh

# 2. Restart delegate to reload scripts
cd harness && docker compose restart

# 3. Test
cd scripts && ./test-scripts-locally.sh update-database dev
```

## Integration with Git Workflow

### Before Committing

```bash
# 1. Make script changes
vim harness/scripts/deploy-application.sh

# 2. Test locally
./test-scripts-locally.sh deploy-application dev

# 3. If working, commit
git add harness/scripts/deploy-application.sh
git commit -m "Fix: Improve deployment error handling"

# 4. Push
git push
```

### After Template Changes

If you change the Harness template YAML:
```bash
# 1. Commit template changes
git add .harness/.../Coordinated_DB_App_Deployment/v1_0.yaml
git commit -m "Update: Add new deployment step"
git push

# 2. Refresh template in Harness UI
# (Navigate to Templates → Refresh)

# 3. Then test via Harness pipeline
# OR test scripts locally if template only changed parameter passing
```

## Reference

### Script Arguments

Each script has specific arguments. See `harness/scripts/README.md` for details.

**Quick reference:**
```bash
fetch-changelog-artifact.sh <VERSION> <GITHUB_ORG> <GITHUB_PAT>
update-database.sh <ENV> <DEMO_ID> <TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
deploy-application.sh <ENV> <VERSION> <ORG> <TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
health-check.sh <ENV> <VERSION> <TARGET> <SERVICE_URL>
fetch-instances.sh <ENV> <TARGET> <SERVICE_NAME> <SERVICE_URL>
```

### Environment Variables

Scripts use these environment variables (set by test framework):
- `VERSION` - Git tag or commit SHA
- `DEMO_ID` - Demo instance identifier (e.g., "psr")
- `DEPLOYMENT_TARGET` - "aws" or "local"
- `ENVIRONMENT` - "dev", "test", "staging", or "prod"

### JSON Parameter Structure

See `test-scripts-locally.sh` lines 27-59 for complete JSON structure.

## Tips

1. **Test incrementally** - Test individual scripts before running `all`
2. **Watch delegate logs** - Run `docker logs -f harness-delegate-psr` in another terminal
3. **Check AWS resources** - Verify RDS, App Runner, S3 exist before testing
4. **Use version control** - Commit working changes before experimenting
5. **Document failures** - Note error messages to help debug production issues

## Getting Help

If you encounter issues:

1. **Check prerequisites** - Delegate running, credentials configured
2. **View script source** - Scripts are in `harness/scripts/*.sh`
3. **Check documentation** - See `harness/scripts/README.md`
4. **Review logs** - Delegate logs show detailed execution
5. **Compare with production** - Check Harness execution logs

---

**Pro Tip:** Keep this terminal open while developing:
```bash
watch -n 5 'docker ps --filter name=harness-delegate'
```

This shows delegate status and restarts in real-time.
