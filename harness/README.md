# Harness CD Configuration

This directory contains Harness Continuous Delivery configuration for the Bagel Store demo, including the Harness Delegate and deployment pipelines.

## Overview

**Harness CD** orchestrates deployments across four environments (dev, test, staging, prod) with:
- Automatic deployment to dev
- Manual approval gates for test, staging, and prod
- Coordinated database (Liquibase) and application (App Runner) deployments
- Integration with GitHub Actions for CI/CD workflow

## Architecture

```
GitHub Actions (CI)
    ↓
    Builds artifacts (Docker image + changelog zip)
    ↓
    Triggers Harness webhook
    ↓
Harness CD Pipeline (this directory)
    ↓
    Uses Harness Delegate (docker-compose.yml)
    ↓
    Deploys to AWS (RDS + App Runner)
```

### Terraform Integration (Zero Manual Configuration)

This demo uses the **Harness Terraform Provider** to eliminate manual environment configuration:

**Traditional Approach (Manual):**
1. ❌ Run Terraform to create AWS infrastructure
2. ❌ Manually create Harness environments in UI
3. ❌ Manually copy/paste AWS outputs (RDS endpoint, ARNs, etc.) into Harness
4. ❌ High chance of typos or stale values
5. ❌ Must repeat for every demo instance

**This Demo (Automated):**
1. ✅ Run Terraform **once** to create both AWS infrastructure AND Harness environments
2. ✅ Terraform automatically populates environment variables with AWS outputs
3. ✅ Pipeline references `<+env.variables.variable_name>` (no manual input!)
4. ✅ Single source of truth - infrastructure changes automatically sync to Harness
5. ✅ Perfect for multi-instance demos (each `demo_id` = separate environments)

**Implementation Files:**
- `terraform/harness-provider.tf` - Harness Terraform Provider configuration
- `terraform/harness-environments.tf` - Creates 4 environments with 14 variables each
- `pipelines/deploy-pipeline.yaml` - References environment variables (not runtime inputs)

**Benefits:**
- Zero manual copy/paste
- No stale infrastructure references
- Instant multi-instance support
- Infrastructure as Code for both AWS and Harness

## Directory Structure

```
harness/
├── docker-compose.yml      # Harness Delegate configuration
├── .env.example            # Template for delegate credentials
├── .env                    # Your credentials (gitignored)
├── artifacts/              # Temporary artifact storage (created by delegate)
├── README.md               # This file
└── pipelines/
    ├── deploy-pipeline.yaml    # Main deployment pipeline (Remote)
    └── README.md               # Pipeline documentation
```

## Prerequisites

1. **Harness Account**
   - Sign up at https://app.harness.io
   - Free edition supports this demo

2. **Harness Organization & Project**
   - Create organization (e.g., "liquibase-demos")
   - Create project (e.g., "bagel-store-demo")

3. **AWS Infrastructure**
   - Complete Phase 1: Terraform deployment
   - RDS instance with 4 databases
   - App Runner services for 4 environments
   - S3 buckets for artifacts
   - AWS Secrets Manager with credentials
   - ✅ **Harness environments automatically configured by Terraform** (see `terraform/harness-environments.tf`)

4. **Docker**
   - Docker installed locally
   - Docker Compose v2+

## Setup Instructions

### 1. Create Harness Account

1. Go to https://app.harness.io
2. Sign up with GitHub OAuth or email
3. Create organization: `liquibase-demos`
4. Create project: `bagel-store-demo`
5. Note your **Account ID** (visible in URL or Settings)

### 2. Create Delegate Token

1. Navigate to: **Project Settings** → **Delegates** → **Tokens**
2. Click **New Token**
3. Name: `demo1-delegate-token`
4. Copy the token value (you won't see it again!)
5. Note your **Account ID**

### 3. Configure Delegate Environment

```bash
cd harness
cp .env.example .env
```

Edit `.env` and set:
```bash
DEMO_ID=demo1
HARNESS_ACCOUNT_ID=your-account-id-here
HARNESS_DELEGATE_TOKEN=your-token-here
```

### 4. Start Delegate

```bash
docker compose up -d
```

**Verify delegate is running:**
```bash
docker compose ps
docker compose logs -f harness-delegate
```

**Check connection in Harness UI:**
1. Navigate to: **Project Settings** → **Delegates**
2. Look for delegate named `demo1-delegate`
3. Status should be **Connected** (green)
4. May take 2-3 minutes for initial connection

### 5. Create Connectors

Harness uses **Connectors** to access external systems.

#### A. GitHub Connector (for changelog artifacts)

1. Navigate to: **Project Settings** → **Connectors** → **New Connector**
2. Select **Code Repositories** → **GitHub**
3. Configure:
   - **Name:** `github-bagel-store`
   - **URL Type:** Repository
   - **Connection Type:** HTTP
   - **GitHub Repository URL:** `https://github.com/YOUR_ORG/harness-gha-bagelstore`
4. **Credentials:**
   - **Username:** Your GitHub username
   - **Personal Access Token:** Create new secret
     - Click **Create or Select a Secret**
     - Name: `github-pat`
     - Token: Your GitHub PAT with scopes: `repo`, `read:packages`
5. **API Access:**
   - Enable **API access**
   - Token: Use same `github-pat` secret
6. **Connectivity Mode:**
   - Select **Connect through Harness Delegate**
   - Delegate Selector: `demo1`
7. Click **Save and Continue**
8. Test connection (should succeed)

#### B. AWS Connector (for infrastructure access)

1. Navigate to: **Project Settings** → **Connectors** → **New Connector**
2. Select **Cloud Providers** → **AWS**
3. Configure:
   - **Name:** `aws-bagel-store`
   - **Credentials:**
     - Select **AWS Access Key**
     - **Access Key:** Create secret `aws-access-key-id`
     - **Secret Key:** Create secret `aws-secret-access-key`
   - **Default Region:** `us-east-1` (or your region)
4. **Connectivity Mode:**
   - Select **Connect through Harness Delegate**
   - Delegate Selector: `demo1`
5. Click **Save and Continue**
6. Test connection (should succeed)

#### C. Docker Registry Connector (optional - images are public)

Only needed if you make images private later.

1. Navigate to: **Project Settings** → **Connectors** → **New Connector**
2. Select **Artifact Repositories** → **Docker Registry**
3. Configure:
   - **Name:** `github-container-registry`
   - **Provider Type:** Other
   - **URL:** `https://ghcr.io`
   - **Authentication:** Anonymous (since images are public)
4. Click **Save**

### 6. Create Harness Secrets

Store sensitive values as Harness Secrets (used in pipeline):

1. Navigate to: **Project Settings** → **Secrets**
2. Create the following secrets:

| Secret Name | Type | Value | Description |
|-------------|------|-------|-------------|
| `github-pat` | Text | Your GitHub PAT | For accessing GitHub Packages |
| `aws-access-key-id` | Text | AWS Access Key | For AWS deployments |
| `aws-secret-access-key` | Text | AWS Secret Key | For AWS deployments |

### 7. Import Remote Pipeline

1. Navigate to: **Pipelines** → **Create a Pipeline**
2. **Name:** `Deploy Bagel Store - demo1`
3. **Setup:** Select **Remote**
4. Configure Git details:
   - **Git Connector:** Select `github-bagel-store`
   - **Repository:** `harness-gha-bagelstore`
   - **Git Branch:** `main`
   - **YAML Path:** `harness/pipelines/deploy-pipeline.yaml`
5. Click **Start**
6. Harness will load the pipeline from GitHub

### 8. Verify Environments (Auto-Configured by Terraform)

**No manual configuration needed!** Terraform automatically created 4 environments with all AWS infrastructure details.

**Verify environments exist:**

1. Navigate to: **Environments** (in left sidebar)
2. You should see 4 environments (created by Terraform):
   - `demo1_dev` (PreProduction)
   - `demo1_test` (PreProduction)
   - `demo1_staging` (PreProduction)
   - `demo1_prod` (Production)

**Each environment contains 14 variables:**
- Database: `rds_endpoint`, `rds_address`, `rds_port`, `database_name`, `jdbc_url`
- App Runner: `app_runner_service_arn`, `app_runner_service_url`, `app_runner_service_id`, `app_runner_service_name`
- S3: `liquibase_flows_bucket`, `operation_reports_bucket`
- Config: `demo_id`, `aws_region`, `environment`, `dns_record`

**Pipeline variables (minimal - most are now in environments):**

| Variable Name | Type | Default Value | Description |
|---------------|------|---------------|-------------|
| `VERSION` | String | Runtime input | Git tag version (e.g., v1.0.0) |
| `GITHUB_ORG` | String | Runtime input | GitHub organization name |

### 9. Configure Webhook Trigger

Allow GitHub Actions to trigger Harness deployments:

1. In Harness pipeline, go to **Triggers**
2. Click **New Trigger** → **Webhook**
3. Configure:
   - **Name:** `github-main-ci-trigger`
   - **Webhook Type:** Custom
   - **Payload Type:** JSON
   - **Method:** POST
4. Copy the webhook URL (looks like: `https://app.harness.io/gateway/pipeline/api/webhook/custom/...`)
5. Add to GitHub Secrets:
   ```bash
   gh secret set HARNESS_WEBHOOK_URL --body "your-webhook-url"
   ```

### 10. Test Pipeline Execution

The pipeline is now ready to run! Infrastructure details are automatically available via environment variables.

**Test a deployment:**

1. Navigate to **Pipelines** → **Deploy Bagel Store - demo1**
2. Click **Run**
3. Provide runtime inputs:
   - **VERSION**: `v1.0.0` (or your version tag)
   - **GITHUB_ORG**: Your GitHub organization
4. Watch the deployment progress through all 4 stages

**The pipeline automatically uses:**
- `<+env.variables.jdbc_url>` - Database connection string
- `<+env.variables.app_runner_service_arn>` - App Runner service ARN
- `<+env.variables.demo_id>` - Demo instance identifier
- And 11 other environment variables (no manual input needed!)

## Delegate Management

### View Logs
```bash
docker compose logs -f harness-delegate
```

### Restart Delegate
```bash
docker compose restart harness-delegate
```

### Stop Delegate
```bash
docker compose down
```

### Update Delegate
```bash
docker compose pull
docker compose up -d
```

### Health Check
```bash
docker compose ps
# Should show "healthy" status
```

## Troubleshooting

### Delegate Not Connecting

**Symptoms:** Delegate shows "Disconnected" in Harness UI

**Solutions:**
1. Check logs: `docker compose logs harness-delegate`
2. Verify `ACCOUNT_ID` and `DELEGATE_TOKEN` in `.env`
3. Check internet connectivity
4. Verify no firewall blocking `app.harness.io`

### Docker Socket Permission Denied

**Symptoms:** Pipeline fails with "permission denied" when running Docker

**Solutions:**
1. Ensure `/var/run/docker.sock` is mounted in docker-compose.yml
2. On Linux, add user to docker group:
   ```bash
   sudo usermod -aG docker $USER
   newgrp docker
   ```

### AWS Connection Failed

**Symptoms:** Pipeline fails connecting to AWS resources

**Solutions:**
1. Verify AWS connector credentials in Harness Secrets
2. Check AWS IAM permissions for the credentials
3. Test AWS CLI locally with same credentials:
   ```bash
   aws sts get-caller-identity --profile your-profile
   ```

### Liquibase Container Fails

**Symptoms:** Database update step fails

**Solutions:**
1. Check RDS endpoint is correct (from Terraform outputs)
2. Verify AWS Secrets Manager has correct credentials
3. Test Liquibase locally:
   ```bash
   docker run --rm \
     -v $(pwd)/../db/changelog:/liquibase/changelog \
     -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
     -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
     -e AWS_REGION=us-east-1 \
     liquibase/liquibase-secure:5.0.1 \
     --url=jdbc:postgresql://RDS_ENDPOINT:5432/dev \
     --username='${awsSecretsManager:demo1/rds/username}' \
     --password='${awsSecretsManager:demo1/rds/password}' \
     --changeLogFile=changelog-master.yaml \
     validate
   ```

## Pipeline Execution

See [pipelines/README.md](pipelines/README.md) for detailed pipeline documentation and execution workflow.

## Architecture Decisions

### Why Docker Delegate?

- **Consistency:** Same execution environment locally and in CI/CD
- **Isolation:** Delegate doesn't interfere with host system
- **Portability:** Easy to move between machines
- **Docker-in-Docker:** Can run Liquibase containers

### Why Remote Pipeline?

- **Version Control:** Pipeline YAML stored in Git
- **Code Review:** Changes reviewed via Pull Requests
- **GitOps:** Single source of truth for all configuration
- **Collaboration:** Team can see and modify pipeline

### Why Manual Approvals?

- **Safety:** Prevent accidental production deployments
- **Compliance:** Human verification before prod changes
- **Demo Control:** Presenter controls promotion timing

## Cost Considerations

**Harness Delegate:**
- Free (runs on your machine)
- No cloud costs

**Harness CD Free Edition:**
- Up to 5 services
- Up to 100 service instances
- Community support

**Total Harness Cost:** $0 for this demo

## Security Best Practices

1. **Never commit `.env` file** - it's in `.gitignore`
2. **Rotate tokens regularly** - especially delegate tokens
3. **Use least-privilege IAM** - AWS credentials should have minimal permissions
4. **Review pipeline changes** - treat pipeline YAML like application code
5. **Audit deployments** - Harness provides full audit trail

## Next Steps

After delegate is running:
1. Review [pipelines/README.md](pipelines/README.md) for pipeline details
2. Test webhook trigger from GitHub Actions
3. Execute manual deployment to dev environment
4. Practice promotion workflow (dev → test → staging → prod)

## Additional Resources

- [Harness Developer Hub](https://developer.harness.io/)
- [Harness CD Documentation](https://developer.harness.io/docs/continuous-delivery/)
- [Harness Delegate Documentation](https://developer.harness.io/docs/platform/delegates/delegate-concepts/delegate-overview/)
- [Harness University (Free Training)](https://university.harness.io/)
