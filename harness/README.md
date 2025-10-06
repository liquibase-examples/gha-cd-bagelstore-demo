# Harness CD Configuration

This directory contains Harness Continuous Delivery configuration for the Bagel Store demo, including the Harness Delegate and deployment pipelines.

---

## 🎉 **FULLY AUTOMATED SETUP** 🎉

**All Harness resources are now created automatically via Terraform!**

✅ Environments (4) with AWS infrastructure details
✅ Secrets (GitHub PAT, AWS credentials, Liquibase license)
✅ Connectors (GitHub, AWS)
✅ Service (Bagel Store)
✅ Pipeline (Remote pipeline registration)

**What you need to do:**
1. Configure `terraform.tfvars` with your credentials
2. Run `terraform apply` in the `terraform/` directory
3. Start the Harness Delegate (see below)
4. **That's it!** The pipeline is ready to execute.

**What you DON'T need to do:**
❌ Manually create connectors in Harness UI
❌ Manually create secrets in Harness UI
❌ Manually create service in Harness UI
❌ Manually import pipeline in Harness UI
❌ Copy/paste infrastructure values between AWS and Harness

See the "Setup Instructions" section below for the simplified workflow.

---

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

## Setup Instructions (Simplified - Automated Workflow)

### Prerequisites

1. **Harness Account** - Sign up at https://app.harness.io (free tier works)
2. **Harness Organization & Project** - Create in Harness UI first
3. **Terraform Applied** - Complete `terraform apply` (creates all Harness resources automatically)

### Step-by-Step Setup

### 1. Create Harness Account (One-Time)

1. Go to https://app.harness.io
2. Sign up with GitHub OAuth or email
3. Create organization: `liquibase-demos` (or use existing)
4. Create project: `bagel-store-demo`
5. Note your **Account ID** (visible in URL: `https://app.harness.io/ng/account/YOUR_ACCOUNT_ID/...`)

### 2. Create Harness API Key (For Terraform - One-Time)

1. Navigate to: **Profile** → **My API Keys** → **New API Key**
2. Name: `terraform-automation`
3. Required scopes: Environment (View, Create/Edit), Connector (View, Create/Edit), Secret (View, Create/Edit), Service (View, Create/Edit), Pipeline (View, Create/Edit)
4. Copy the API key (starts with `pat.`)
5. Add to `terraform/terraform.tfvars`: `harness_api_key = "pat.xxxxxxx"`

### 3. Create Delegate Token (For Delegate - One-Time)

1. Navigate to: **Project Settings** → **Delegates** → **Tokens**
2. Click **New Token**
3. Name: `demo1-delegate-token`
4. Copy the token value (you won't see it again!)
5. Note your **Account ID**

### 4. Run Terraform (Creates ALL Harness Resources)

```bash
cd terraform
terraform apply
```

**This single command creates:**
- ✅ 4 Harness environments (dev, test, staging, prod) with AWS infrastructure details
- ✅ 4 Harness secrets (GitHub PAT, AWS credentials, Liquibase license)
- ✅ 2 Harness connectors (GitHub, AWS)
- ✅ 1 Harness service (Bagel Store)
- ✅ 1 Harness pipeline (Deploy Bagel Store - registered from Git)

**Verify in Harness UI:** Navigate to Environments, Secrets, Connectors, Services, and Pipelines to see all resources.

### 5. Configure Delegate Environment

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

### 6. Start Delegate

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

### 7. Verify Resources in Harness UI

**All resources created automatically by Terraform!** Verify they exist:

#### ✅ Environments
Navigate to: **Environments** → You should see 4 environments:
- `demo1_dev` (PreProduction)
- `demo1_test` (PreProduction)
- `demo1_staging` (PreProduction)
- `demo1_prod` (Production)

Each environment has 14 variables with AWS infrastructure details (RDS, App Runner, S3, etc.)

#### ✅ Secrets
Navigate to: **Project Settings** → **Secrets** → You should see 4 secrets:
- `github-pat`
- `aws-access-key-id`
- `aws-secret-access-key`
- `liquibase-license-key`

#### ✅ Connectors
Navigate to: **Project Settings** → **Connectors** → You should see 2 connectors:
- `github-bagel-store` (Status: Connected)
- `aws-bagel-store` (Status: Connected)

**Note:** If connectors show "Not Connected", check delegate status and network connectivity.

#### ✅ Service
Navigate to: **Services** → You should see:
- `Bagel Store` (Type: CustomDeployment)

#### ✅ Pipeline
Navigate to: **Pipelines** → You should see:
- `Deploy Bagel Store - demo1` (Remote pipeline from Git)

**Pipeline Runtime Inputs (Only 2 Required):**
- `VERSION`: Git tag version (e.g., v1.0.0)
- `GITHUB_ORG`: GitHub organization name

All infrastructure details come from environment variables - no manual input needed!

### 8. Configure Webhook Trigger (Optional)

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

### 9. Test Pipeline Execution

**🎉 The pipeline is ready to run immediately! 🎉**

All infrastructure details are pre-configured via environment variables from Terraform.

**Execute a deployment:**

1. Navigate to **Pipelines** → **Deploy Bagel Store - demo1**
2. Click **Run**
3. Provide **only 2 runtime inputs**:
   - **VERSION**: `v1.0.0` (or your version tag)
   - **GITHUB_ORG**: Your GitHub organization
4. Click **Run Pipeline**
5. Watch the deployment progress through all 4 stages:
   - Dev (automatic)
   - Test (requires approval)
   - Staging (requires approval)
   - Production (requires approval)

**The pipeline automatically uses environment variables:**
- `<+env.variables.jdbc_url>` - Database connection string
- `<+env.variables.app_runner_service_arn>` - App Runner service ARN
- `<+env.variables.rds_address>` - RDS endpoint
- `<+env.variables.demo_id>` - Demo instance identifier
- And 10 other variables - all pre-configured by Terraform!

**No manual infrastructure input needed!** ✨

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
