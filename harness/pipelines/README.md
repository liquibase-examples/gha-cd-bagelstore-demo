# Harness Deployment Pipeline

This directory contains the Harness CD pipeline configuration for deploying the Bagel Store application and database across four environments.

## Pipeline Overview

**Pipeline Name:** Deploy Bagel Store
**Pipeline File:** `deploy-pipeline.yaml` (Remote pipeline stored in Git)
**Deployment Type:** Custom Deployment (coordinated database + application)

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions CI (main branch)                            │
│  • Builds Docker image → ghcr.io                            │
│  • Creates changelog artifact → GitHub Packages             │
│  • Triggers Harness webhook                                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  Harness CD Pipeline (this file)                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Stage 1: Deploy to Dev (Automatic)                 │    │
│  │  1. Fetch changelog from GitHub Packages           │    │
│  │  2. Update database via Liquibase                  │    │
│  │  3. Deploy app to App Runner                       │    │
│  │  4. Health check                                   │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ⏸️  Manual Approval Required                       │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Stage 2: Deploy to Test                            │    │
│  │  (same steps as Dev, targeting test env)           │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ⏸️  Manual Approval Required                       │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Stage 3: Deploy to Staging                         │    │
│  │  (same steps as Dev, targeting staging env)        │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ⏸️  Manual Approval Required                       │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │ Stage 4: Deploy to Production                      │    │
│  │  (same steps as Dev, targeting prod env)           │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Pipeline Variables

The pipeline uses **minimal runtime inputs** - infrastructure details are automatically provided via **Harness Environment Variables** (configured by Terraform).

### Runtime Input Variables (User Provides)

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `VERSION` | String | Yes | Git tag version (e.g., v1.0.0) |
| `GITHUB_ORG` | String | Yes | GitHub organization name |

### Environment Variables (Terraform Provides)

Each environment (dev, test, staging, prod) automatically gets 14 variables from Terraform:

| Variable | Example Value | Usage in Pipeline |
|----------|---------------|-------------------|
| `rds_endpoint` | `bagel-store-demo1-rds.xxx.rds.amazonaws.com:5432` | Database connection |
| `rds_address` | `bagel-store-demo1-rds.xxx.rds.amazonaws.com` | Host only |
| `rds_port` | `5432` | Port only |
| `database_name` | `dev` / `test` / `staging` / `prod` | Environment-specific DB |
| `jdbc_url` | `jdbc:postgresql://host:5432/dev` | Complete JDBC URL |
| `app_runner_service_arn` | `arn:aws:apprunner:...` | Service deployment |
| `app_runner_service_url` | `xxx.us-east-1.awsapprunner.com` | Health checks |
| `app_runner_service_id` | `abc123` | Service identification |
| `app_runner_service_name` | `bagel-store-demo1-dev` | Service name |
| `liquibase_flows_bucket` | `bagel-store-demo1-liquibase-flows` | Flow files |
| `operation_reports_bucket` | `bagel-store-demo1-operation-reports` | Reports |
| `demo_id` | `demo1` | Demo instance ID |
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `dev` / `test` / `staging` / `prod` | Environment name |
| `dns_record` | `dev-demo1.example.com` | DNS (if enabled) |

**Pipeline references these via:** `<+env.variables.variable_name>`

**Example:**
```yaml
# Liquibase command in pipeline
--url=<+env.variables.jdbc_url>
--username='${awsSecretsManager:<+env.variables.demo_id>/rds/username}'

# App Runner deployment
--service-arn <+env.variables.app_runner_service_arn>
--region <+env.variables.aws_region>
```

## Stage Details

### Stage 1: Deploy to Dev (Automatic)

**Trigger:** Webhook from GitHub Actions
**Approval:** None (automatic deployment)
**Environment:** `dev`

**Steps:**
1. **Fetch Changelog Artifact**
   - Downloads changelog zip from GitHub Packages
   - URL: `https://maven.pkg.github.com/{org}/{repo}/bagel-store-changelog/{version}/...`
   - Authentication: Uses `github_pat` secret
   - Extracts to `/tmp/changelog`

2. **Update Database**
   - Runs `liquibase/liquibase-secure:5.0.1` Docker container
   - Mounts changelog directory
   - Connects to dev database using: `<+env.variables.jdbc_url>`
   - Credentials from AWS Secrets Manager: `${awsSecretsManager:<+env.variables.demo_id>/rds/username}`
   - Executes: `liquibase update`

3. **Deploy Application**
   - Updates App Runner service via AWS CLI
   - Service ARN from: `<+env.variables.app_runner_service_arn>`
   - Image: `ghcr.io/{org}/bagel-store:{version}`
   - Environment variables:
     - `DATABASE_URL`: PostgreSQL connection string (uses Secrets Manager + env vars)
     - `FLASK_ENV`: `production`
     - `APP_VERSION`: Pipeline version variable

4. **Health Check**
   - Polls App Runner service URL from: `<+env.variables.app_runner_service_url>`
   - Waits for HTTP 200 response
   - Timeout: 5 minutes (30 attempts × 10 seconds)
   - Also checks `/version` endpoint for verification

**Duration:** ~5-10 minutes

### Stage 2: Deploy to Test (Manual Approval)

**Trigger:** Manual approval after Dev deployment
**Approval:** Required (1 approver minimum)
**Environment:** `test`

**Approval Message:**
```
Please review and approve deployment to TEST environment.

Version: {version}
Demo ID: {demo_id}

Changes will be applied to test database and application.
```

**Steps:** Same as Stage 1, but targeting `test` database and App Runner service

**Duration:** Depends on approval time + ~5-10 minutes execution

### Stage 3: Deploy to Staging (Manual Approval)

**Trigger:** Manual approval after Test deployment
**Approval:** Required (1 approver minimum)
**Environment:** `staging`

**Approval Message:**
```
Please review and approve deployment to STAGING environment.

Version: {version}
Demo ID: {demo_id}

This is the final pre-production environment.
```

**Steps:** Same as Stage 1, but targeting `staging` database and App Runner service

**Duration:** Depends on approval time + ~5-10 minutes execution

### Stage 4: Deploy to Production (Manual Approval)

**Trigger:** Manual approval after Staging deployment
**Approval:** Required (1 approver minimum)
**Environment:** `prod`

**Approval Message:**
```
⚠️ PRODUCTION DEPLOYMENT

Please carefully review before approving deployment to PRODUCTION.

Version: {version}
Demo ID: {demo_id}

This will apply database changes and deploy to production environment.
```

**Steps:** Same as Stage 1, but targeting `prod` database and App Runner service

**Duration:** Depends on approval time + ~5-10 minutes execution

## Deployment Workflow

### Full Deployment (Dev → Test → Staging → Prod)

1. **Developer merges PR to main**
2. **GitHub Actions CI runs:**
   - Builds Docker image
   - Creates changelog artifact
   - Triggers Harness webhook with VERSION parameter
3. **Harness deploys to Dev automatically**
4. **Presenter/operator approves Test deployment**
5. **Harness deploys to Test**
6. **Presenter/operator approves Staging deployment**
7. **Harness deploys to Staging**
8. **Presenter/operator approves Production deployment**
9. **Harness deploys to Production**
10. **All environments running same VERSION**

**Total Time (if approved immediately):** ~20-40 minutes

### Partial Deployment (Dev only)

If you only want to deploy to Dev for testing:

1. **Trigger pipeline with VERSION**
2. **Wait for Dev stage to complete**
3. **Do NOT approve Test deployment**
4. **Pipeline pauses at approval gate**

### Rollback Strategy

Currently, the pipeline does not include automated rollback steps. To rollback:

1. **Identify previous working version** (e.g., v1.0.0)
2. **Re-run pipeline** with previous VERSION
3. **Approve through environments** as normal
4. **Liquibase will skip already-applied changesets** (idempotent)

**Note:** For Phase 6, consider adding rollback steps using Liquibase rollback commands.

## Execution Examples

### Trigger via Webhook (from GitHub Actions)

GitHub Actions sends webhook:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"VERSION": "v1.0.0"}' \
  "$HARNESS_WEBHOOK_URL"
```

### Manual Execution (from Harness UI)

1. Navigate to **Pipelines** → **Deploy Bagel Store**
2. Click **Run**
3. Provide runtime inputs:
   - `VERSION`: `v1.0.0`
   - `RDS_ENDPOINT`: (from Terraform outputs)
   - `GITHUB_ORG`: Your GitHub org
4. Click **Run Pipeline**
5. Monitor execution in real-time

### Execute Specific Stage Only

The pipeline allows individual stage execution:

1. Open pipeline in Harness UI
2. Click **⋮** (three dots) on specific stage
3. Select **Run Stage**
4. Provide stage-specific inputs
5. Stage executes independently

**Use cases:**
- Re-deploy to Test without re-deploying Dev
- Hotfix production without touching other environments

## Monitoring & Debugging

### View Pipeline Execution

1. Navigate to **Pipelines** → **Deploy Bagel Store**
2. Click on specific execution in history
3. View step-by-step execution with logs

### View Step Logs

1. Click on any step (e.g., "Update Database")
2. View real-time console output
3. Search logs with Ctrl+F
4. Download logs for offline analysis

### Common Issues

#### Issue: "Changelog artifact not found"

**Symptoms:** Step "Fetch Changelog Artifact" fails with 404

**Solutions:**
- Verify VERSION exists in GitHub Packages
- Check `github_pat` secret has `read:packages` scope
- Ensure GitHub Actions successfully uploaded artifact

#### Issue: "Liquibase update failed"

**Symptoms:** Step "Update Database" fails

**Solutions:**
- Check RDS endpoint is correct
- Verify AWS Secrets Manager has credentials
- Check Liquibase license key is valid
- Review changelog syntax errors

#### Issue: "App Runner service not found"

**Symptoms:** Step "Deploy Application" fails

**Solutions:**
- Verify App Runner services exist (from Terraform)
- Check service name matches pattern: `bagel-store-{demo_id}-{env}`
- Ensure AWS credentials have App Runner permissions

#### Issue: "Health check timeout"

**Symptoms:** Step "Health Check" fails after 5 minutes

**Solutions:**
- Check App Runner service is running in AWS console
- Verify image was pulled successfully
- Check application logs in App Runner
- Ensure `/health` endpoint is working

## Pipeline Metrics

**Success Criteria:**
- ✅ All 4 stages complete successfully
- ✅ Health checks pass in all environments
- ✅ Database changesets applied correctly
- ✅ Application version matches deployed version

**Typical Execution Times:**
- Dev deployment: 5-10 minutes
- Test deployment: 5-10 minutes (+ approval time)
- Staging deployment: 5-10 minutes (+ approval time)
- Prod deployment: 5-10 minutes (+ approval time)

**Failure Modes:**
- Artifact not available
- Database connection failure
- Liquibase changeset error
- App Runner deployment failure
- Health check timeout

## Security Considerations

### Secrets Used

| Secret Name | Type | Usage | Notes |
|-------------|------|-------|-------|
| `github_pat` | Text | GitHub Packages access | Needs `repo`, `read:packages` |
| `aws_access_key_id` | Text | AWS CLI commands | Minimal IAM permissions |
| `aws_secret_access_key` | Text | AWS CLI commands | Stored securely in Harness |
| `liquibase_license_key` | Text | Liquibase Pro features | Required for policy checks |

### Credential Flow

```
Pipeline Step
    ↓
Harness Secret (encrypted at rest)
    ↓
Delegate (in-memory only)
    ↓
Docker Container / AWS CLI (environment variable)
    ↓
External Service (RDS, S3, etc.)
```

**Note:** Credentials never written to disk or logs

### AWS Secrets Manager Integration

Liquibase uses native AWS Secrets Manager syntax:
```
--username='${awsSecretsManager:demo1/rds/username}'
--password='${awsSecretsManager:demo1/rds/password}'
```

**Benefits:**
- No hardcoded credentials in pipeline
- Automatic credential rotation support
- Centralized secret management
- Audit trail for secret access

## Demo Presentation

### Recommended Presentation Flow

1. **Show PR with database change** (GitHub)
2. **Show GitHub Actions CI** (building artifacts)
3. **Show Harness Pipeline triggered** (webhook)
4. **Watch Dev deployment** (automatic)
5. **Approve Test deployment** (manual gate)
6. **Watch Test deployment** (coordinated DB + app)
7. **Show Test environment working** (browser)
8. **Approve Staging deployment** (manual gate)
9. **Approve Production deployment** (final manual gate)
10. **Show all environments running same version**

**Key Talking Points:**
- Coordinated database + application deployment
- Manual approval gates for safety
- AWS Secrets Manager integration
- Liquibase policy checks (enforced in GitHub Actions)
- Same artifact deployed to all environments

## Future Enhancements (Phase 6)

**Potential improvements:**
- [ ] Add automated rollback steps
- [ ] Add smoke tests after deployment
- [ ] Add Slack/Teams notifications
- [ ] Add deployment approval with Jira integration
- [ ] Add blue/green deployment strategy
- [ ] Add canary deployment for production
- [ ] Add deployment metrics dashboards
- [ ] Add automated performance tests

## Additional Resources

- [Harness CD Documentation](https://developer.harness.io/docs/continuous-delivery/)
- [Harness Pipeline YAML Reference](https://developer.harness.io/docs/platform/pipelines/harness-yaml-quickstart/)
- [Harness Approvals](https://developer.harness.io/docs/platform/approvals/approvals-tutorial/)
- [Harness Secrets Management](https://developer.harness.io/docs/platform/secrets/secrets-management/harness-secret-manager-overview/)
