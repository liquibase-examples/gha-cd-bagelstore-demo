# Local Deployment Mode

This guide covers the **local deployment mode** for the Harness-GHA-BagelStore demo, which runs all 4 environments (dev, test, staging, prod) on your laptop using Docker Compose instead of AWS infrastructure.

## Overview

Local deployment mode provides:

- **Zero AWS costs** - Everything runs in Docker containers
- **Fast setup** - 2 minutes vs. 30-minute Terraform apply
- **Same Harness workflow** - 4 stages, manual approvals, version promotion
- **Offline capability** - Demo without internet once images are pulled
- **Easy troubleshooting** - `docker compose logs` instead of CloudWatch

## Architecture Comparison

| Component | AWS Mode | Local Mode |
|-----------|----------|------------|
| **Database** | RDS PostgreSQL (4 databases) | 4 PostgreSQL containers (ports 5432-5435) |
| **Application** | 4 App Runner services | 4 Flask containers (ports 5001-5004) |
| **Secrets** | AWS Secrets Manager | Docker environment variables |
| **Flow Files** | S3 bucket | Local file mounts |
| **DNS** | Route53 custom domains | localhost:5001-5004 |
| **Deployment** | `aws apprunner update-service` | `docker compose up -d` |
| **Harness Pipeline** | ✅ Same (4 stages, approvals) | ✅ Same (4 stages, approvals) |
| **Versioning** | Pull from AWS Public ECR | Pull from AWS Public ECR |
| **Liquibase** | Docker container via Harness | Docker container via Harness |

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- Harness delegate running locally (see [harness/README.md](../harness/README.md))
- AWS credentials configured (for pulling images from AWS Public ECR)

### 1. Initial Setup

```bash
# Create .env file from template
cp .env.example .env

# Edit .env if needed (optional)
# - Change GITHUB_ORG if using a fork
# - Change DEMO_USERNAME/DEMO_PASSWORD for login credentials

# Start all 4 environments
docker compose -f docker-compose-demo.yml up -d

# Wait for services to be healthy (~30 seconds)
watch docker compose -f docker-compose-demo.yml ps
```

### 2. Verify All Environments Running

```bash
# Check deployment state
./scripts/deployment/show-deployment-state.sh
```

Expected output:
```
=== Local Deployment State ===

📄 .env file versions:
VERSION_DEV=latest
VERSION_PROD=latest
VERSION_STAGING=latest
VERSION_TEST=latest

🐳 Running containers:

Environment | Version        | Health | URL
----------- | -------------- | ------ | ----
dev         | latest         | ✅ OK  | http://localhost:5001
test        | latest         | ✅ OK  | http://localhost:5002
staging     | latest         | ✅ OK  | http://localhost:5003
prod        | latest         | ✅ OK  | http://localhost:5004
```

### 3. Access Applications

Open in browser:
- Dev: http://localhost:5001
- Test: http://localhost:5002
- Staging: http://localhost:5003
- Prod: http://localhost:5004

Login with credentials from `.env` (default: demo/password)

### 4. Configure Harness for Local Mode

In Harness UI, add environment variable to each environment (dev, test, staging, prod):

- **Variable Name**: `DEPLOYMENT_TARGET`
- **Type**: String
- **Value**: `local`

Alternatively, leave this variable unset - the pipeline defaults to `aws` mode.

### 5. Run Deployment Pipeline

In Harness UI:
1. Navigate to **Pipelines** → **Deploy Bagel Store**
2. Click **Run Pipeline**
3. Enter inputs:
   - **VERSION**: Version tag (e.g., `v1.0.0` or `latest`)
   - **GITHUB_ORG**: Your GitHub org (e.g., `recampbell`)
4. Click **Run**

The pipeline will:
- Deploy to dev (automatic)
- Wait for approval to deploy to test
- Deploy to test
- Wait for approval to deploy to staging
- Deploy to staging
- Wait for approval to deploy to prod
- Deploy to prod

## Version State Management

### How Version State Works

Local mode uses a `.env` file to track which version is deployed to each environment. This file persists across `docker compose down/up` cycles.

**Example `.env` file:**
```bash
GITHUB_ORG=recampbell
VERSION_DEV=v1.1.0
VERSION_TEST=v1.0.0
VERSION_STAGING=v1.0.0
VERSION_PROD=v1.0.0
DEMO_USERNAME=demo
DEMO_PASSWORD=password
```

### Harness Pipeline Updates `.env`

When Harness deploys a new version:

1. Pipeline updates `.env` file: `VERSION_DEV=v1.1.0`
2. Pulls new image: `docker compose pull app-dev`
3. Restarts service: `docker compose up -d --no-deps app-dev`
4. State persists in `.env` file

### Version Promotion Workflow

```bash
# Initial state
VERSION_DEV=latest
VERSION_TEST=latest
VERSION_STAGING=latest
VERSION_PROD=latest

# Deploy v1.0.0 to dev via Harness
VERSION_DEV=v1.0.0  # Updated by Harness
VERSION_TEST=latest
VERSION_STAGING=latest
VERSION_PROD=latest

# Promote to test (manual approval in Harness)
VERSION_DEV=v1.0.0
VERSION_TEST=v1.0.0  # Updated by Harness
VERSION_STAGING=latest
VERSION_PROD=latest

# Continue promoting through environments...
```

## Common Operations

### View Deployment State

```bash
./scripts/deployment/show-deployment-state.sh
```

Shows:
- Versions defined in `.env` file
- Running container versions (from `/version` endpoint)
- Health status of each environment
- URLs to access each environment

### View Logs

```bash
# All services
docker compose -f docker-compose-demo.yml logs -f

# Specific environment
docker compose -f docker-compose-demo.yml logs -f app-dev
docker compose -f docker-compose-demo.yml logs -f postgres-dev

# Last 50 lines
docker compose -f docker-compose-demo.yml logs --tail=50 app-dev
```

### Manual Deployment (Without Harness)

```bash
# Deploy v1.1.0 to dev manually
sed -i.bak 's/^VERSION_DEV=.*/VERSION_DEV=v1.1.0/' .env
docker compose -f docker-compose-demo.yml pull app-dev
docker compose -f docker-compose-demo.yml up -d --no-deps app-dev
```

### Reset All Environments

```bash
# Reset all to latest
./scripts/deployment/reset-local-environments.sh latest

# Reset all to specific version
./scripts/deployment/reset-local-environments.sh v1.0.0
```

### Stop All Environments

```bash
# Stop containers (preserves volumes and .env state)
docker compose -f docker-compose-demo.yml down

# Later, restart with same versions
docker compose -f docker-compose-demo.yml up -d
```

### Complete Reset (Delete All Data)

```bash
# Stop and remove volumes (deletes database data!)
docker compose -f docker-compose-demo.yml down -v

# Start fresh
cp .env.example .env
docker compose -f docker-compose-demo.yml up -d
```

## Troubleshooting

### Port Conflicts

**Error**: `bind: address already in use`

**Solution**: Another service is using ports 5001-5004 or 5432-5435.

```bash
# Find what's using the port
lsof -i :5001

# Kill the process
kill <PID>

# Or change ports in docker-compose-demo.yml
```

### Containers Not Starting

**Check container status:**
```bash
docker compose -f docker-compose-demo.yml ps
```

**Check logs for errors:**
```bash
docker compose -f docker-compose-demo.yml logs app-dev
docker compose -f docker-compose-demo.yml logs postgres-dev
```

**Common issues:**
- PostgreSQL not healthy yet - wait 30 seconds
- Image pull failure - check AWS credentials and ECR access
- Out of disk space - `docker system prune`

### Version Not Updating

**Symptoms**: Deployed new version but old version still running

**Diagnosis:**
```bash
# Check .env file
cat .env | grep VERSION_DEV

# Check running container
curl http://localhost:5001/version
```

**Solutions:**
```bash
# Force pull new image
docker compose -f docker-compose-demo.yml pull app-dev

# Force recreate container
docker compose -f docker-compose-demo.yml up -d --force-recreate --no-deps app-dev

# Clear Docker image cache (use your actual image name)
docker rmi public.ecr.aws/l1v5b6d6/demo1-bagel-store:v1.1.0
docker compose -f docker-compose-demo.yml pull app-dev
docker compose -f docker-compose-demo.yml up -d --no-deps app-dev
```

### Health Check Failures

**Error**: `❌ Health check failed after 30 attempts`

**Check application logs:**
```bash
docker compose -f docker-compose-demo.yml logs app-dev
```

**Common causes:**
- Database connection failure - check postgres-dev is running
- Image pulled but service not restarted
- Application crash on startup

**Solutions:**
```bash
# Restart postgres first
docker compose -f docker-compose-demo.yml restart postgres-dev

# Then restart app
docker compose -f docker-compose-demo.yml restart app-dev

# Check connectivity
docker compose -f docker-compose-demo.yml exec app-dev ping postgres-dev
```

### Liquibase Connection Errors

**Error**: `Connection refused` or `Network not found`

**Cause**: Liquibase container cannot reach postgres containers on Docker network.

**Solution**: Verify network name matches docker-compose-demo.yml:

```bash
# List networks
docker network ls | grep bagel

# Expected network name:
# harness-gha-bagelstore_bagel-network

# Pipeline uses:
--network harness-gha-bagelstore_bagel-network
```

If network name differs, update Harness pipeline step.

### .env File Lost

**Symptoms**: After `docker compose down`, all environments reset to `latest`

**Cause**: `.env` file was deleted or not in repository root.

**Solution:**
```bash
# Recreate from template
cp .env.example .env

# Manually set versions to match previous state
# (Check deployment history in Harness for version info)
```

## Network Architecture

### Docker Network

All services run on a bridge network: `bagel-network`

```
┌─────────────────────────────────────────────────┐
│          bagel-network (bridge)                  │
│                                                  │
│  postgres-dev:5432  ←→  app-dev:5000            │
│  postgres-test:5432 ←→  app-test:5000           │
│  postgres-staging:5432 ←→ app-staging:5000      │
│  postgres-prod:5432 ←→  app-prod:5000           │
│                                                  │
│  ↓ (Liquibase runs on same network)             │
│  liquibase-container                             │
└─────────────────────────────────────────────────┘
         ↓ port mappings
    localhost:5001-5004
    localhost:5432-5435
```

### Port Mappings

| Service | Container Port | Host Port | External URL |
|---------|----------------|-----------|--------------|
| postgres-dev | 5432 | 5432 | postgresql://localhost:5432/dev |
| postgres-test | 5432 | 5433 | postgresql://localhost:5433/test |
| postgres-staging | 5432 | 5434 | postgresql://localhost:5434/staging |
| postgres-prod | 5432 | 5435 | postgresql://localhost:5435/prod |
| app-dev | 5000 | 5001 | http://localhost:5001 |
| app-test | 5000 | 5002 | http://localhost:5002 |
| app-staging | 5000 | 5003 | http://localhost:5003 |
| app-prod | 5000 | 5004 | http://localhost:5004 |

### Network Name for Liquibase

When running Liquibase from Harness delegate:

```bash
docker run --rm \
  --network harness-gha-bagelstore_bagel-network \
  -v /tmp/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://postgres-dev:5432/dev \
  --username=postgres \
  --password=postgres \
  update
```

Key points:
- Network name: `harness-gha-bagelstore_bagel-network` (repo name + network name)
- Hostname: `postgres-<environment>` (not localhost)
- Port: `5432` (internal container port, not mapped port)

## Switching Between AWS and Local Modes

### Option 1: Separate Demo Instances

Run both modes simultaneously:

**AWS Mode:**
- Harness environments: `demo1-dev`, `demo1-test`, `demo1-staging`, `demo1-prod`
- Environment variable: `DEPLOYMENT_TARGET=aws` (or unset)

**Local Mode:**
- Harness environments: `local-dev`, `local-test`, `local-staging`, `local-prod`
- Environment variable: `DEPLOYMENT_TARGET=local`

### Option 2: Toggle on Same Environments

Switch deployment target for existing environments:

```bash
# Switch to local mode
# In Harness UI, set DEPLOYMENT_TARGET=local for all environments

# Switch back to AWS mode
# In Harness UI, set DEPLOYMENT_TARGET=aws (or remove variable)
```

**Warning**: Switching modes does not migrate data between RDS and local PostgreSQL.

## Cost Comparison

### AWS Mode
- **Monthly**: ~$37-42 running continuously
  - RDS db.t3.micro: $15-20
  - App Runner (4 services): ~$20
  - Route53: $0.50
  - Secrets Manager: ~$2
- **Setup time**: 15-30 minutes
- **Teardown**: `terraform destroy`

### Local Mode
- **Monthly**: $0
- **Setup time**: 2 minutes
- **Teardown**: `docker compose down`

**Recommendation**: Use local mode for development/testing, AWS mode for production-like demos.

## Best Practices

### 1. Backup .env File

```bash
# Before major changes
cp .env .env.backup

# Restore if needed
cp .env.backup .env
```

### 2. Regular Image Updates

```bash
# Pull latest images weekly
docker compose -f docker-compose-demo.yml pull
docker compose -f docker-compose-demo.yml up -d
```

### 3. Monitor Disk Usage

```bash
# Check disk usage
docker system df

# Clean up unused images/volumes
docker system prune -a --volumes
```

### 4. Document Version History

Keep a log of deployed versions:

```bash
# Add to deployment notes
echo "$(date) - Deployed v1.1.0 to dev" >> deployment-log.txt
```

### 5. Test Locally Before AWS

1. Test changes in local mode first
2. Validate database migrations work
3. Then deploy to AWS for production-like validation

## Integration with Harness

### Pipeline Conditional Logic

The pipeline detects `DEPLOYMENT_TARGET` environment variable:

```yaml
# Default to AWS if not set
DEPLOYMENT_TARGET="${DEPLOYMENT_TARGET:-aws}"

if [ "$DEPLOYMENT_TARGET" = "aws" ]; then
  # AWS deployment logic
else
  # Local deployment logic
fi
```

### Required Harness Secrets

Even in local mode, you need:
- `liquibase_license_key` - Required for policy checks
- `github_pat` - Optional, for private repos

You do **NOT** need AWS credentials for local mode:
- `aws_access_key_id` - Only for AWS mode
- `aws_secret_access_key` - Only for AWS mode

## Limitations

Local mode has these limitations compared to AWS mode:

1. **No AWS Secrets Manager** - Uses plaintext postgres credentials
2. **No Route53 DNS** - Uses localhost URLs
3. **No S3 storage** - Flow files loaded from local filesystem
4. **Single machine** - Cannot distribute across multiple hosts
5. **No managed backups** - Use `docker compose exec postgres-prod pg_dump`

## Next Steps

- **Production demos**: See [AWS_SETUP.md](AWS_SETUP.md) for AWS mode
- **CI/CD workflows**: See [WORKFLOWS.md](WORKFLOWS.md)
- **Troubleshooting**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Harness setup**: See [harness/README.md](../harness/README.md)
