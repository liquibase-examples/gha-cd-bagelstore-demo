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

```bash
# Test PR validation flow
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -v $(pwd)/liquibase-flows:/liquibase/flows \
  -e LIQUIBASE_COMMAND_URL=jdbc:postgresql://localhost:5432/dev \
  -e LIQUIBASE_COMMAND_USERNAME=postgres \
  -e LIQUIBASE_COMMAND_PASSWORD=password \
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=/liquibase/flows/pr-validation-flow.yaml
```

### GitHub Actions Integration

Flow files are uploaded to S3 by Terraform and referenced via S3 URLs:

```yaml
- name: Run PR Validation
  env:
    LIQUIBASE_COMMAND_URL: jdbc:postgresql://${{ secrets.RDS_ENDPOINT }}/dev
    LIQUIBASE_COMMAND_USERNAME: ${{ secrets.DB_USERNAME }}
    LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
    LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
  run: |
    liquibase flow \
      --flow-file=s3://bagel-store-${{ vars.DEMO_ID }}-liquibase-flows/pr-validation-flow.yaml
```

### Using AWS Secrets Manager

Liquibase Secure 5.0.1 natively integrates with AWS Secrets Manager:

```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  -e AWS_REGION=us-east-1 \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://rds-endpoint:5432/dev \
  --username='${awsSecretsManager:demo1/rds/username}' \
  --password='${awsSecretsManager:demo1/rds/password}' \
  --changeLogFile=changelog-master.yaml \
  flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/pr-validation-flow.yaml
```

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

## S3 Deployment

Terraform automatically uploads these files to S3:

```hcl
resource "aws_s3_object" "pr_validation_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "pr-validation-flow.yaml"
  source = "liquibase-flows/pr-validation-flow.yaml"
}

resource "aws_s3_object" "policy_checks_config" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "liquibase.checks-settings.conf"
  source = "liquibase-flows/liquibase.checks-settings.conf"
}
```

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
