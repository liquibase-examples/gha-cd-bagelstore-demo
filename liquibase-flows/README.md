# Liquibase Flow Files and Policy Checks

Liquibase flow files and policy checks configuration for the Bagel Store demo. These files orchestrate database validation, policy enforcement, and artifact creation.

## Files

### Flow Files

- **[pr-validation-flow.yaml](pr-validation-flow.yaml)** - Pull request validation flow
- **[main-deployment-flow.yaml](main-deployment-flow.yaml)** - Main branch deployment flow

### Configuration

- **[liquibase.checks-settings.conf](liquibase.checks-settings.conf)** - Policy checks configuration with 12 BLOCKER checks

## Flow File Pattern

Both flow files follow the postgres-flow-policy-demo pattern with structured stages:

### Stage 1: Verify
- **connect** - Validate database connectivity
- **validate** - Check changelog syntax
- **status** - Show pending changes

### Stage 2: PolicyChecks
- **checks show** - Display enabled checks
- **checks run** - Execute policy checks with BLOCKER severity (exit code 4)

### Stage 3: CreateArtifact (main-deployment only)
- Package changelog as zip file for deployment

### endStage
- Display summary and list generated reports

## Policy Checks

All 12 policy checks are configured with **BLOCKER severity** (exit code 4):

### Destructive Changes
1. **ChangeDropColumnWarn** - Prevents dropping columns
2. **ChangeDropTableWarn** - Prevents dropping tables
3. **ChangeTruncateTableWarn** - Prevents truncating tables

### Data Type and Schema
4. **ModifyDataTypeWarn** - Warns on data type modifications
5. **TableColumnLimit** - Enforces max 50 columns per table

### Rollback and Recovery
6. **RollbackRequired** - Ensures changesets have rollback capability

### Security and Permissions
7. **SqlGrantAdminWarn** - Detects GRANT with ADMIN OPTION
8. **SqlGrantOptionWarn** - Detects GRANT with GRANT OPTION
9. **SqlGrantWarn** - Detects GRANT statements
10. **SqlRevokeWarn** - Detects REVOKE statements

### Performance and Best Practices
11. **CheckTablesForIndex** - Ensures tables have appropriate indexes
12. **SqlSelectStarWarn** - Detects SELECT * statements

**Impact:** Any violation blocks PR merge and stops CI pipeline.

## Usage

### Local Testing with Flow Files

For local development, mount flow files from your workspace:

```bash
# Test PR validation flow (local mounts)
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -v $(pwd)/liquibase-flows:/liquibase/flows \
  -e LIQUIBASE_COMMAND_URL=jdbc:postgresql://localhost:5432/dev \
  -e LIQUIBASE_COMMAND_USERNAME=postgres \
  -e LIQUIBASE_COMMAND_PASSWORD=password \
  -e LIQUIBASE_LICENSE_KEY=$LIQUIBASE_LICENSE_KEY \
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=/liquibase/flows/pr-validation-flow.yaml
```

### GitHub Actions Integration

GitHub Actions uses local mounts for faster execution (no S3 access needed):

```yaml
- name: Run Liquibase PR Validation Flow
  env:
    LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
    LIQUIBASE_COMMAND_URL: jdbc:postgresql://localhost:5432/dev
    LIQUIBASE_COMMAND_USERNAME: postgres
    LIQUIBASE_COMMAND_PASSWORD: postgres
    LIQUIBASE_COMMAND_CHANGELOG_FILE: changelog-master.yaml
    LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE: /liquibase/flows/liquibase.checks-settings.conf
  run: |
    docker run --rm \
      --network host \
      -v ${{ github.workspace }}/db/changelog:/liquibase/changelog \
      -v ${{ github.workspace }}/liquibase-flows:/liquibase/flows \
      -e LIQUIBASE_LICENSE_KEY \
      -e LIQUIBASE_COMMAND_URL \
      -e LIQUIBASE_COMMAND_USERNAME \
      -e LIQUIBASE_COMMAND_PASSWORD \
      -e LIQUIBASE_COMMAND_CHANGELOG_FILE \
      -e LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE \
      -w /liquibase/changelog \
      liquibase/liquibase-secure:5.0.1 \
      flow \
      --flow-file=/liquibase/flows/pr-validation-flow.yaml
```

### Harness CD Pipeline - S3 Flow Files (Private Bucket)

**The S3 bucket is private and requires IAM authentication.**

Harness CD pipelines access flow files from S3 using AWS credentials. Liquibase Secure 5.0.1+ natively supports S3 URLs with IAM authentication:

```bash
# AWS MODE - Authenticated S3 access
docker run --rm \
  -v /tmp/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=<aws-access-key> \
  -e AWS_SECRET_ACCESS_KEY=<aws-secret-key> \
  -e AWS_REGION=us-east-1 \
  -e LIQUIBASE_LICENSE_KEY=<license-key> \
  -e LIQUIBASE_COMMAND_URL=jdbc:postgresql://rds-endpoint:5432/dev \
  -e LIQUIBASE_COMMAND_USERNAME='${awsSecretsManager:demo1/rds/username}' \
  -e LIQUIBASE_COMMAND_PASSWORD='${awsSecretsManager:demo1/rds/password}' \
  -e LIQUIBASE_COMMAND_CHANGELOG_FILE=changelog-master.yaml \
  -e LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE=s3://bagel-store-demo1-liquibase-flows/liquibase.checks-settings.conf \
  -w /liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/main-deployment-flow.yaml
```

**Key Points:**
- S3 bucket is **private** - no public access
- Requires `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables
- Liquibase automatically authenticates to S3 using AWS SDK
- Both flow files and checks-settings.conf can use S3 URLs
- Demonstrates production-ready security pattern

## Operation Reports

Both flows generate HTML operation reports:

### PR Validation Reports
- `pr-connection-report.html` - Database connection validation
- `pr-validation-report.html` - Changelog syntax validation
- `pr-status-report.html` - Pending changes status
- `pr-policy-report.html` - Policy check results

### Main Deployment Reports
- `main-connection-report.html`
- `main-validation-report.html`
- `main-status-report.html`
- `main-policy-report.html`

Reports are automatically uploaded to S3:
```
s3://bagel-store-<demo_id>-operation-reports/reports/<run-number>/
```

## S3 Deployment (Private Bucket)

Terraform automatically uploads these files to a **private S3 bucket**:

```hcl
# S3 bucket is private with IAM-based access control
resource "aws_s3_bucket_public_access_block" "liquibase_flows" {
  bucket = aws_s3_bucket.liquibase_flows[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "pr_validation_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "pr-validation-flow.yaml"
  source = "liquibase-flows/pr-validation-flow.yaml"
}

resource "aws_s3_object" "main_deployment_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "main-deployment-flow.yaml"
  source = "liquibase-flows/main-deployment-flow.yaml"
}

resource "aws_s3_object" "policy_checks_config" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "liquibase.checks-settings.conf"
  source = "liquibase-flows/liquibase.checks-settings.conf"
}
```

**Access Control:**
- Bucket is **private** - no public access allowed
- Access requires valid AWS credentials (IAM user or role)
- Liquibase Secure 5.0.1+ handles S3 authentication automatically via AWS SDK

## Global Variables

### pr-validation-flow.yaml
- `ENV: "PR"`
- `REPORTS_PATH: "reports"`
- `POLICY_REPORT: "pr-policy-report.html"`
- `VALIDATION_REPORT: "pr-validation-report.html"`

### main-deployment-flow.yaml
- `ENV: "MAIN"`
- `REPORTS_PATH: "reports"`
- `VERSION: "${VERSION:-latest}"`
- Artifact naming: `bagel-store-changelog-${VERSION}.zip`

## Exit Codes

- **0** - Success (all checks passed)
- **4** - BLOCKER severity violation (pipeline fails)

## Customization

To modify policy checks:

1. Edit [liquibase.checks-settings.conf](liquibase.checks-settings.conf)
2. Run `terraform apply` to upload to S3
3. Test with local flow execution

To add new flow stages:

1. Add stage definition to flow YAML
2. Follow pattern: action type → command → args
3. Enable reports for observability

## References

- [Liquibase Flow Documentation](https://docs.liquibase.com/commands/flow/home.html)
- [Liquibase Policy Checks](https://docs.liquibase.com/commands/policy-checks/home.html)
- [postgres-flow-policy-demo](../../../liquibase-patterns/repos/postgres-flow-policy-demo/) - Pattern source
- [AWS Secrets Manager Integration](https://docs.liquibase.com/tools-integrations/extensions/secrets-managers/aws-secrets-mgr.html)

## Next Steps

After creating flow files:

1. Run `terraform apply` to upload to S3
2. Configure GitHub Actions workflows to reference S3 URLs
3. Create Liquibase changelogs in `db/changelog/`
4. Test PR validation locally
5. Submit test PR to verify policy checks enforcement
