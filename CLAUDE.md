# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a demonstration repository showcasing coordinated application and database deployments using **Harness CD**, **GitHub Actions**, **Liquibase Secure 5.0.1**, and **AWS infrastructure**. The project deploys a Python Flask "Bagel Store" application with PostgreSQL database changes across four environments (dev, test, staging, prod).

**Key Pattern:** All resources are tagged with a unique `demo_id` to support multiple concurrent demo instances.

## Repository Structure

```
├── app/                          # Flask application
│   ├── src/                      # Application source code
│   │   ├── app.py                # Flask app factory
│   │   ├── routes.py             # Route handlers
│   │   ├── models.py             # Data models
│   │   ├── database.py           # Database utilities
│   │   └── templates/            # Jinja2 HTML templates
│   ├── tests/                    # Pytest + Playwright tests
│   ├── Dockerfile                # Docker image definition
│   ├── docker-compose.yml        # Local dev environment
│   ├── pyproject.toml            # Python dependencies (PEP 621)
│   └── uv.lock                   # Locked dependency versions
├── db/
│   └── changelog/
│       ├── changelog-master.yaml # Master changelog (YAML format)
│       ├── changesets/           # Individual changesets (formatted SQL)
│       │   ├── 001-create-products-table.sql
│       │   ├── 002-create-inventory-table.sql
│       │   ├── 003-create-orders-table.sql
│       │   ├── 004-create-order-items-table.sql
│       │   ├── 005-create-indexes.sql
│       │   ├── 006-seed-products.sql
│       │   └── 007-seed-inventory.sql
│       └── README.md             # Changeset documentation
├── terraform/                    # AWS infrastructure as code
│   ├── main.tf
│   ├── rds.tf                    # PostgreSQL RDS instance
│   ├── s3.tf                     # S3 buckets for flows and reports
│   ├── secrets.tf                # AWS Secrets Manager
│   ├── route53.tf                # DNS records
│   └── app-runner.tf             # App Runner services (4 environments)
├── harness/
│   ├── pipelines/
│   │   └── deploy-pipeline.yaml  # Remote pipeline definition
│   └── docker-compose.yml        # Harness Delegate
├── liquibase-flows/
│   ├── pr-validation-flow.yaml
│   ├── main-deployment-flow.yaml
│   └── liquibase.checks-settings.conf
├── .github/workflows/            # GitHub Actions CI/CD
│   ├── pr-validation.yml         # PR policy checks
│   ├── test-deployment.yml       # Deploy + system tests
│   └── main-ci.yml               # Build artifacts
├── scripts/
│   └── check-dependencies.sh     # Automated dependency checker
├── .claude/commands/
│   └── setup.md                  # AI-assisted setup command
└── SETUP.md                      # Complete setup guide
```

## First-Time Setup

**For new developers setting up the project:**

1. **Quick dependency check:**
   ```bash
   ./scripts/check-dependencies.sh
   ```

2. **AWS diagnostics (if deploying to AWS):**
   ```bash
   ./scripts/diagnose-aws.sh
   ```

3. **AI-assisted setup (Claude Code users):**
   - Type `setup` at the Claude Code prompt for guided setup

4. **Complete setup guide:**
   - See [SETUP.md](SETUP.md) for detailed platform-specific instructions
   - Covers Windows (WSL) and macOS
   - Includes AWS SSO vs access keys decision guide
   - Comprehensive AWS troubleshooting

## Local Development & Testing

For local development and testing of the Flask application, see [app/TESTING.md](app/TESTING.md).

**Quick Start:**
```bash
cd app
docker compose up --build  # Access at http://localhost:5001
```

**Important:** Port 5001 is used externally (macOS ControlCenter uses 5000).

## Diagnostic Scripts

### Dependency Checker

Run this to verify all required tools are installed with correct versions:

```bash
./scripts/check-dependencies.sh
```

**What it checks:**
- Docker & Docker Compose (version and daemon status)
- Terraform >= 1.0.0
- Git >= 2.0.0
- Python >= 3.11
- uv >= 0.1.0
- AWS CLI >= 2.0.0 (optional)
- Configuration files (.env, terraform.tfvars)
- Environment variables (LIQUIBASE_LICENSE_KEY for CI/CD)

**When to run:**
- First-time setup
- After installing/upgrading tools
- When experiencing tool-related issues
- Before asking for help

### AWS Diagnostics

Comprehensive AWS configuration diagnostics:

```bash
./scripts/diagnose-aws.sh
```

**What it checks:**
- AWS CLI installation and version
- All configured profiles (SSO, IAM credentials, assume role)
- Currently active profile (AWS_PROFILE env var)
- SSO session status (active, expired, not logged in)
- Authentication test (calls `aws sts get-caller-identity`)
- Required permissions (S3, Secrets Manager, RDS)
- Common configuration errors:
  - Typos in paths (`~/.aaws` instead of `~/.aws`)
  - Wrong file permissions
  - Conflicting environment variables
  - Expired SSO sessions

**When to run:**
- **ALWAYS** run this first for AWS issues
- After configuring AWS credentials
- When SSO session expires
- Before running Terraform
- When switching AWS profiles
- When encountering authentication errors

**Common scenarios this solves:**
- "Unable to locate credentials" → Shows how to configure
- "ExpiredToken" → Shows which profile to login with SSO
- "InvalidClientTokenId" → Identifies invalid credentials
- "Wrong account" → Shows active profile and how to switch
- "AccessDenied" → Tests specific permissions needed

## Setup Troubleshooting Workflow

When users report setup or configuration issues:

**1. Run diagnostics first (ALWAYS):**
```bash
# General issues
./scripts/check-dependencies.sh

# AWS-specific issues
./scripts/diagnose-aws.sh
```

**2. Common mistakes to check:**
- Typos: `~/.aaws` instead of `~/.aws`
- Wrong profile: `echo $AWS_PROFILE`
- Missing config files: `.env`, `terraform.tfvars`
- Liquibase license: `echo $LIQUIBASE_LICENSE_KEY`

**3. Documentation-first approach:**
- Setup issues → Point to SETUP.md specific section
- AWS SSO → SETUP.md "Option A: Configure AWS SSO"
- Testing → app/TESTING.md
- **Don't re-explain what's already documented**

**4. Interactive help:**
- Type `/setup` for AI-guided troubleshooting

## AWS Configuration Common Issues

**From actual user struggles - check these first:**

| Issue | Detection | Solution |
|-------|-----------|----------|
| **Typo in path** | `~/.aaws/` exists | `./scripts/diagnose-aws.sh` detects this |
| **Expired SSO session** | "ExpiredToken" error | `aws sso login --profile <name>` |
| **Wrong profile active** | Commands use wrong account | `export AWS_PROFILE=<correct-profile>` |
| **Multiple configure attempts** | User confusion | See SETUP.md decision tree (SSO vs keys) |
| **Missing credentials** | "Unable to locate credentials" | `./scripts/diagnose-aws.sh` shows how to fix |

**Always run diagnostics first:**
```bash
./scripts/diagnose-aws.sh
```

Script will show:
- ✓ All configured profiles
- ✓ Which profile is active
- ✓ SSO session status
- ✓ Exact command to fix issues

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

**How to check:**
```bash
# Review all .tf files for hardcoded values
cd terraform
grep -r "vpc-\|sg-\|arn:aws:iam" *.tf

# Verify all environment-specific values are in variables.tf or terraform.tfvars
cat variables.tf terraform.tfvars.example
```

**Pattern for custom tags:**
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

Users add their own via `terraform.tfvars`:
```hcl
common_tags = {
  Account     = "my-org-name"
  project     = "bagel-store-demo"
  cost_center = "engineering"
}
```

## Common Commands

### Common Review Commands

**Verify GitHub Actions Locally:**
```bash
# Check workflow syntax
cat .github/workflows/pr-validation.yml

# Verify Docker mount paths in workflows
grep -r "github.workspace" .github/workflows/

# Check environment variable patterns
grep -r "LIQUIBASE_COMMAND_" .github/workflows/
```

**Flow File Validation:**
```bash
# Verify flow file paths are absolute
grep -n "cd " liquibase-flows/*.yaml
grep -n "mkdir" liquibase-flows/*.yaml

# Check for relative path issues
grep -n "\.\." liquibase-flows/*.yaml  # Should find none
```

### Git Workflow
```bash
# Check status and review changes
git status
git diff <file>

# Check authorship before amending
git log -1 --format='%an %ae'

# Commit with detailed message
git add <files>
git commit -m "$(cat <<'EOF'
<multi-line commit message>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

### Terraform
```bash
# Initialize
terraform init

# Plan with demo_id
terraform plan -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"

# Apply infrastructure
terraform apply -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"

# Destroy all resources for a demo instance
terraform destroy -var="demo_id=demo1"
```

**Security review before sharing repository:**
```bash
# Check for hardcoded AWS-specific values
cd terraform
grep -r "vpc-\|sg-\|arn:aws:iam" *.tf

# Verify all values are parameterized
cat variables.tf terraform.tfvars.example

# Review default tags (should not include org-specific values)
grep -A5 "common_tags" variables.tf
```

### GitHub Actions CI/CD

**Overview:** Three workflows orchestrate the complete CI/CD pipeline with Liquibase policy checks and system tests.

#### Workflow: PR Validation (pr-validation.yml)
**Trigger:** Pull requests to main (changes to `db/changelog/` or `liquibase-flows/`)

**Purpose:** Run Liquibase policy checks BEFORE deployment

```bash
# What it does:
# 1. Starts PostgreSQL container (postgres:16)
# 2. Runs Liquibase PR validation flow file
# 3. Executes 12 BLOCKER-level policy checks
# 4. Uploads operation reports as artifacts
# 5. Adds PR comment with pass/fail status
# 6. Blocks merge if any BLOCKER check fails
```

**Required GitHub Secrets:**
- `LIQUIBASE_LICENSE_KEY` - Required for Flow and policy checks

**Key Pattern:**
- Uses local flow file: `/liquibase/flows/pr-validation-flow.yaml`
- Migrates to S3 when Terraform permissions resolved (see Phase 1 step 6)
- Uses `LIQUIBASE_COMMAND_*` environment variables (proven best practice)

#### Workflow: Test Deployment (test-deployment.yml)
**Trigger:** Pull requests to main (changes to `app/` or `db/changelog/`)

**Purpose:** Deploy changelog to database and verify with system tests

```bash
# What it does:
# 1. Creates .env file with random demo credentials (no secrets needed!)
# 2. Starts full Docker Compose (postgres + Flask app)
# 3. Deploys Liquibase changelog to dev database
# 4. Verifies deployment with bash checks
# 5. Runs pytest test suite (22 tests):
#    - 7 deployment verification tests (NEW!)
#    - 4 health check tests
#    - 11 E2E shopping flow tests (Playwright)
# 6. Uploads test reports as artifacts
# 7. Adds PR comment with test results
```

**Required GitHub Secrets:**
- `LIQUIBASE_LICENSE_KEY` - ✅ **SET** (repository-level secret)

**Demo Credentials:** Generated randomly per CI run using `openssl rand -base64 32` (no secrets needed)

**NEW Deployment Verification Tests** (`test_liquibase_deployment.py`):
1. ✅ Verifies databasechangelog table exists
2. ✅ Confirms all 9 changesets applied in correct order
3. ✅ Validates all tables created (products, inventory, orders, order_items)
4. ✅ Checks all 4 indexes created
5. ✅ Verifies foreign key constraints exist
6. ✅ Confirms seed data loaded correctly (5 products, 5 inventory)
7. ✅ Validates database tags applied (v1.0.0-baseline, v1.0.0)

**Test Validation:**
- Liquibase deployment validated with Python tests
- Database schema matches changelog exactly
- All seed data loaded correctly
- Flask app health checks pass
- Complete E2E shopping flow works

#### Workflow: Main CI (main-ci.yml)
**Trigger:** Push to main branch (after PR merge)

**Purpose:** Build and publish versioned artifacts

**Two parallel jobs:**

**Job A: Build Database Artifact**
```bash
# 1. Extract version from git tag or commit SHA
# 2. Run Liquibase main deployment flow file
#    - Policy checks
#    - Validation
#    - Create changelog zip artifact
# 3. Upload changelog zip to GitHub Packages
# 4. Upload operation reports as artifacts
```

**Job B: Build Application Docker Image**
```bash
# 1. Extract version from git tag or commit SHA
# 2. Build Docker image
# 3. Tag: ghcr.io/<org>/<demo_id>-bagel-store:<version>
# 4. Push to GitHub Container Registry (public)
# 5. Also tag as 'latest'
```

**Job C: Trigger Harness Deployment (optional)**
```bash
# Only runs if HARNESS_WEBHOOK_URL variable is configured
# Triggers Harness CD pipeline for dev environment deployment
```

**Optional GitHub Variables:**
- `DEMO_ID` - Demo instance identifier (defaults to "demo1")
- `HARNESS_WEBHOOK_URL` - For automatic Harness deployments

#### Local Flow Files (Temporary)
**Current State:**
- Flow files stored in `liquibase-flows/` directory
- Mounted locally in Liquibase Docker container
- Policy checks file: `liquibase.checks-settings.conf`

**Migration to S3 (when Terraform Phase 1 complete):**
```yaml
# Before (local):
--flow-file=/liquibase/flows/pr-validation-flow.yaml

# After (S3):
--flow-file=s3://bagel-store-${DEMO_ID}-liquibase-flows/pr-validation-flow.yaml
```

See `requirements-design-plan.md` Phase 1 step 6 for migration checklist.

#### Viewing Workflow Results
```bash
# Check workflow status
gh run list --workflow=pr-validation.yml

# View latest run
gh run view

# Download artifacts (reports)
gh run download <run-id>

# View workflow logs
gh run view <run-id> --log
```

#### Common Workflow Issues

**"Liquibase license key required"**
- Ensure `LIQUIBASE_LICENSE_KEY` secret is set in GitHub repository
- Get free trial: https://www.liquibase.com/trial

**"Policy check BLOCKER violation"**
- Review operation reports in workflow artifacts
- See `liquibase.checks-settings.conf` for check definitions
- All 12 checks must pass (severity 4 = BLOCKER)

**"PostgreSQL connection failed"**
- Check service health in workflow logs
- Verify `pg_isready` command succeeds
- May need to increase wait time in workflow

**"Docker network not found"**
- In test-deployment workflow, uses Docker Compose network name
- Network: `app_bagel-network` (defined in docker-compose.yml)
- Liquibase must use this network to connect to postgres

**"Tests failed after changelog deployment"**
- Check Liquibase deployment verification step
- Ensure all 9 changesets applied successfully
- Verify seed data loaded (5 products, 5 inventory records)
- Review Flask app logs in workflow output

### Python Application (using uv)
```bash
cd app

# Initialize project (first time)
uv init --name bagel-store --python 3.11

# Add dependencies
uv add flask psycopg2-binary python-dotenv

# Install all dependencies (creates uv.lock)
uv sync

# Install with dev dependencies
uv sync --extra dev

# Run application locally
uv run python src/app.py

# Run tests (see app/TESTING.md for details)
uv run pytest

# Rebuild Docker image after template changes
# (Templates are baked into image at build time)
docker compose build --no-cache
docker compose up -d
uv run pytest -m health  # Verify changes
```

### Harness Delegate
```bash
cd harness

# Start delegate
docker compose up -d

# View logs
docker compose logs -f harness-delegate

# Stop delegate
docker compose down
```

### Database Development Workflow

**Complete workflow for adding a new changeset:**

```bash
# 1. Ensure PostgreSQL is running
docker compose ps postgres  # Should show "healthy"

# 2. Create bagelstore database (first time only)
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE bagelstore;"

# 3. Create changeset file (increment number)
cat > db/changelog/changesets/008-add-product-category.sql << 'EOF'
--liquibase formatted sql
--changeset demo:008-add-product-category

-- Add category field to products table
ALTER TABLE products ADD COLUMN category VARCHAR(50) DEFAULT 'standard';

--rollback ALTER TABLE products DROP COLUMN category;
EOF

# 4. Update master changelog
# Edit db/changelog/changelog-master.yaml
# Add before the final version tag:
  - include:
      file: changesets/008-add-product-category.sql
      relativeToChangelogFile: true

# 5. Validate syntax
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  validate

# 6. Apply changeset (if validation passes)
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  update

# 7. Verify database change
docker compose exec -T postgres psql -U postgres -d bagelstore -c "\d products"

# 8. Commit changes
git add db/changelog/
git commit -m "Add category field to products table"
```

**Changeset Requirements:**
1. **Always include `--rollback`** - Required by RollbackRequired policy check
2. **Avoid `SELECT *`** - Triggers SqlSelectStarWarn check
3. **Don't DROP/TRUNCATE tables** - Triggers BLOCKER checks
4. **Include indexes** - Required by CheckTablesForIndex
5. **Update master changelog** - Add reference in `db/changelog/changelog-master.yaml`

**Naming Convention:** `NNN-descriptive-name.sql`
- `NNN` = Three-digit sequential number (001, 002, etc.)
- Use kebab-case for names
- Example: `008-add-product-category.sql`

**Complete Documentation:** See [db/changelog/README.md](db/changelog/README.md) for:
- Detailed changeset patterns
- Policy check compliance
- Rollback examples
- Troubleshooting guide

### Database Verification Commands

```bash
# List all tables
docker compose exec -T postgres psql -U postgres -d bagelstore -c "\dt"

# View table structure
docker compose exec -T postgres psql -U postgres -d bagelstore -c "\d products"

# Query data
docker compose exec -T postgres psql -U postgres -d bagelstore -c "SELECT * FROM products;"

# Check Liquibase changelog history
docker compose exec -T postgres psql -U postgres -d bagelstore -c "SELECT id, author, filename, dateexecuted FROM databasechangelog ORDER BY dateexecuted;"

# Drop database (reset for testing)
docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS bagelstore;"
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE bagelstore;"
```

### Liquibase Testing

```bash
# Local testing (requires LIQUIBASE_LICENSE_KEY environment variable)
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  validate

# AWS Secrets Manager integration (production)
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_REGION=us-east-1 \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://rds-endpoint:5432/dev \
  --username='${awsSecretsManager:demo1/rds/username}' \
  --password='${awsSecretsManager:demo1/rds/password}' \
  --changeLogFile=changelog-master.yaml \
  validate

# Run flow file from S3
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_REGION=us-east-1 \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/pr-validation-flow.yaml
```

### After Template Changes

Templates are **baked into Docker images** at build time:

```bash
# Must rebuild without cache
docker compose build --no-cache
docker compose up -d

# Verify changes applied
curl http://localhost:5001/login | grep "Demo Credentials"
uv run pytest -m health
```

### Testing Credentials Flow

```bash
# 1. Test environment variable loading
cd app
source .env
echo $DEMO_PASSWORD  # Verify it's set

# 2. Test application loads them
docker compose up -d
docker compose logs app | grep -i "error\|password"

# 3. Test full login flow
uv run pytest tests/test_e2e_shopping.py::test_login_success -v
```

## Security-Sensitive Files

**Never commit these:**
- `app/.env` - Local credentials (in .gitignore)
- `terraform/*.tfvars` - Infrastructure secrets (in .gitignore)
- Any file with actual passwords, API keys, or tokens

**Always commit these:**
- `app/.env.example` - Template with placeholders
- `terraform/terraform.tfvars.example` - Infrastructure template
- Documentation referencing environment variables

**When in doubt:** Use `git check-ignore -v <file>` to verify gitignore status

## Critical Implementation Requirements

### Liquibase Deployment Pattern

**IMPORTANT: Liquibase is NOT installed locally**

- Runs via Docker containers: `liquibase/liquibase-secure:5.0.1`
- Used in GitHub Actions workflows
- License key via environment variable: `LIQUIBASE_LICENSE_KEY`
- **Never** try to install Liquibase CLI locally

**License key requirements:**
- Required for CI/CD (GitHub Actions)
- Required for Flow files and policy checks (12 BLOCKER checks)
- Must be in GitHub Secrets
- Get free trial: https://www.liquibase.com/trial
- Check locally: `./scripts/check-dependencies.sh` (shows if set)
- Verify: `echo $LIQUIBASE_LICENSE_KEY`

### Liquibase GitHub Actions Configuration

**ALWAYS use these exact versions and settings:**

```yaml
- uses: actions/checkout@v4  # NOT v3 (deprecated)

- uses: liquibase/setup-liquibase@v1  # NOT older versions
  with:
    version: '4.32.0'  # Minimum 4.32.0 (NOT 4.29.0)
    edition: 'pro'     # Required for Flow and policy checks

- uses: actions/upload-artifact@v4  # NOT v3 (causes failures)

- uses: aws-actions/configure-aws-credentials@v4
```

**Environment Variables - CRITICAL:**
- **MUST use `LIQUIBASE_COMMAND_*` environment variables in GitHub Actions**
- **Use LIQUIBASE_COMMAND_* for all configuration**
- **Exception:** Flow files can use `${VARIABLE}` syntax for globalVariables
- **Pattern:** Environment variables override properties files
- Required variables:
  ```yaml
  env:
    LIQUIBASE_COMMAND_URL: jdbc:postgresql://host:5432/database
    LIQUIBASE_COMMAND_USERNAME: username
    LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
    LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE: /liquibase/flows/liquibase.checks-settings.conf
    LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
  ```

**GitHub Actions Permissions (REQUIRED):**
- PR workflows: `contents: read`, `pull-requests: write`
- Main/deploy workflows: `contents: read`, `packages: write` (for GHCR)

### GitHub Actions Workflow Requirements

**Critical workflow requirements:**
- Explicit `permissions:` block (contents: read, pull-requests: write for PR workflows)
- `LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE` environment variable
- Absolute paths in Docker containers (`/liquibase/changelog`, `/liquibase/artifacts`)
- Version extraction pattern from git tags (fallback to `dev-$(git rev-parse --short HEAD)`)

**Flow file execution context:**
- Workflows run from repository root
- Docker containers mount at `/liquibase/`
- Flow files execute with working directory context
- Shell commands in flows MUST use absolute paths: `/liquibase/changelog`, `/liquibase/artifacts`

### GitHub Actions Workflow Files Reference

Quick reference for workflow structure:

**PR Validation:** `pr-validation.yml`
- Permissions: `contents: read`, `pull-requests: write`
- Runs policy checks only (no deployment)
- Uses PostgreSQL service container
- Mounts: changelog, flows, reports

**Test Deployment:** `test-deployment.yml`
- Permissions: `contents: read`, `pull-requests: write`
- Deploys changelog + runs 15 pytest tests
- Uses Docker Compose (not service container)
- Verifies: changesets, products, inventory, indexes

**Main CI:** `main-ci.yml`
- Permissions: `contents: read`, `packages: write`
- Builds artifacts: changelog zip + Docker image
- Triggers Harness webhook
- Versioning from git tags

### Flow File Path Requirements

**CRITICAL:** Flow files execute inside Docker containers with specific mount points.

**Docker mount structure (GitHub Actions):**
```bash
-v ${{ github.workspace }}/db/changelog:/liquibase/changelog
-v ${{ github.workspace }}/liquibase-flows:/liquibase/flows
-v ${{ github.workspace }}/reports:/liquibase/reports
-v ${{ github.workspace }}/artifacts:/liquibase/artifacts
-w /liquibase  # Working directory
```

**Shell commands in flow files MUST use absolute paths:**
```yaml
# ✅ Correct
- type: shell
  command: |
    mkdir -p /liquibase/artifacts
    cd /liquibase/changelog
    zip -r /liquibase/artifacts/output.zip .

# ❌ Wrong (relative paths fail)
- type: shell
  command: |
    mkdir -p artifacts
    cd db/changelog
    zip -r ../../artifacts/output.zip .
```

**Why:** Working directory is `/liquibase`, not repository root.

### Changelog Format
- **Master changelog:** YAML format (NOT XML) - `changelog-master.yaml`
- **Individual changesets:** Formatted SQL files in `changesets/` directory

### Flow File Structure
All flow files must follow this staged structure:
1. **Verify** - Connection validation, syntax check, status
2. **PolicyChecks** - Run policy checks with BLOCKER severity
3. **Deploy/CreateArtifact** - Execute changes or build artifacts
4. **endStage** - Cleanup and summary reporting

Enable operation reports:
```yaml
globalArgs: { reports-enabled: "true", reports-path: "reports", reports-name: "report.html" }
```

### Policy Checks
- **12 checks enabled** with **BLOCKER severity** (exit code 4)
- Configuration file: `liquibase.checks-settings.conf`
- Stored in S3: `s3://bagel-store-<demo_id>-liquibase-flows/liquibase.checks-settings.conf`
- Any violation **blocks PR merge** and **stops CI pipeline**

Key checks:
- ChangeDropColumnWarn, ChangeDropTableWarn, ChangeTruncateTableWarn
- CheckTablesForIndex, ModifyDataTypeWarn, RollbackRequired
- SqlGrantAdminWarn, SqlGrantOptionWarn, SqlGrantWarn, SqlRevokeWarn
- SqlSelectStarWarn, TableColumnLimit (50 columns max)

### Python Dependency Management

**Use `uv` instead of `pip` or `requirements.txt`:**

Benefits:
- 10-100x faster than pip
- Reproducible builds via `uv.lock`
- Follows PEP 621 standards
- Automatic virtual environment management

**pyproject.toml structure:**
```toml
[project]
name = "bagel-store"
version = "1.0.0"
requires-python = ">=3.11"
dependencies = [
    "flask>=3.0.0",
    "psycopg2-binary>=2.9.9",
    "python-dotenv>=1.0.0",
]
```

**Dockerfile pattern:**
```dockerfile
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY src/ ./src/
ENV PATH="/app/.venv/bin:$PATH"
CMD ["uv", "run", "python", "src/app.py"]
```

## Architecture & Workflows

### Multi-Instance Support
- Each demo uses unique `demo_id` (e.g., `demo1`, `customer-abc`)
- All AWS resources tagged with `demo_id`
- Naming pattern: `bagel-store-<demo_id>-<resource-type>`
- Docker images: `ghcr.io/<org>/<demo_id>-bagel-store:<version>`
- DNS: `<env>-<demo_id>.bagel-demo.example.com`

### Environments
1. **dev** - Auto-deployed on merge to main
2. **test** - Manual promotion via Harness
3. **staging** - Manual promotion via Harness
4. **prod** - Manual promotion via Harness

All environments share:
- Same RDS instance (4 databases: dev, test, staging, prod)
- Same versioned artifacts (Docker image + changelog zip)
- DNS via Route53
- Credentials via AWS Secrets Manager

### CI/CD Workflow

**PR Validation:**
1. `actions/checkout@v4`
2. `liquibase/setup-liquibase@v1` with edition: 'secure'
3. Download flow and policy checks from S3
4. Execute `pr-validation-flow.yaml`
   - Verify connection and syntax
   - Run policy checks (BLOCKER severity)
5. Upload operation report to S3: `reports/<run-number>/pr-validation-report.html`
6. Upload report as GitHub Actions artifact
7. Report status to PR

**Main Branch CI (after merge):**
1. **Database workflow:**
   - Execute `main-deployment-flow.yaml`
   - Run policy checks and validation
   - Create changelog zip artifact
   - Upload to GitHub Packages
   - Upload operation report to S3
   - Trigger Harness webhook
2. **Application workflow:**
   - Extract version from git tag
   - Build Docker image
   - Tag: `ghcr.io/<org>/<demo_id>-bagel-store:<version>`
   - Push to GitHub Container Registry as **public** image

**Harness Deployment (Remote YAML pipeline):**
1. Fetch changelog zip from GitHub Packages
2. Pull public Docker image from GitHub Container Registry (no auth needed)
3. Update database via Liquibase Docker container
4. Deploy application to App Runner
4. Health check
5. Manual approval for next environment

### AWS Integration

**Secrets Manager:**
- `<demo_id>/rds/username` - Database username
- `<demo_id>/rds/password` - Database password

**Liquibase native integration:**
```bash
--username='${awsSecretsManager:<demo_id>/rds/username}'
--password='${awsSecretsManager:<demo_id>/rds/password}'
```

**S3 Buckets:**
- `bagel-store-<demo_id>-liquibase-flows` (public) - Flow files and policy checks
- `bagel-store-<demo_id>-operation-reports` (private) - CI/CD reports

**Flow files uploaded via Terraform:**
```hcl
resource "aws_s3_object" "pr_validation_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "pr-validation-flow.yaml"
  source = "${path.module}/../liquibase-flows/pr-validation-flow.yaml"
  etag   = filemd5("${path.module}/../liquibase-flows/pr-validation-flow.yaml")
}
```

### Versioning
- **Git tags** define versions (e.g., `v1.0.0`)
- Docker images and changelog zips use same version tag
- Harness references version when deploying
- Both app and database promoted together

## Testing

The application includes comprehensive automated tests using pytest + Playwright for browser automation.

**Quick start:**
```bash
cd app
docker compose up -d
uv run pytest
```

**IMPORTANT!!! For complete testing documentation, see [app/TESTING.md](app/TESTING.md).**

### Test Structure

- `app/tests/` - All automated tests (15 tests total)
  - `conftest.py` - Shared pytest fixtures
  - `test_health_check.py` - System health validation (4 tests)
  - `test_e2e_shopping.py` - Complete user flows (11 tests)

### Key Test Fixtures

Available in `conftest.py` for test development:
- `wait_for_services` - Auto-waits for Docker services to be healthy
- `db_connection` - PostgreSQL connection for database validation
- `authenticated_page` - Pre-logged-in browser session
- `clean_cart` - Clears session cart between tests
- `clean_test_orders` - Cleans up test orders from database

### Test Commands

```bash
# Run all tests
uv run pytest

# Run specific markers
uv run pytest -m health        # Health checks only
uv run pytest -m e2e          # E2E tests only
uv run pytest -m "not slow"   # Skip slow tests

# Debug with visible browser
uv run pytest --headed
```

### When Tests Might Break

- After template changes (requires `docker compose build --no-cache`)
- After route URL changes (check templates for hardcoded URLs)
- If demo credentials in `routes.py` don't match `login.html`

**Important:** Tests use the actual Docker Compose environment (not mocks), validating real database operations and full user flows.

## Application Development Patterns

### Template and Route Synchronization

**CRITICAL:** Templates are baked into Docker images at build time.

When changing demo credentials, route URLs, or template content:

1. **Check both locations:**
   - Route handler: `app/src/routes.py` (e.g., `DEMO_USER` constant)
   - Template display: `app/src/templates/*.html` (demo credentials, URLs)

2. **Rebuild required:**
   ```bash
   docker compose build --no-cache
   docker compose up -d
   ```

3. **Verify with tests:**
   ```bash
   cd app && uv run pytest -m health
   ```

**Example - Demo credentials:**
```python
# Source of truth: app/src/routes.py - Loaded from environment variables
DEMO_USERNAME = os.getenv('DEMO_USERNAME')
DEMO_PASSWORD = os.getenv('DEMO_PASSWORD')
```
```html
<!-- Must match: app/src/templates/login.html - Username shown, password from .env -->
<p>Username: <code>{{ demo_username }}</code></p>
<p><em>Password: Set in your local .env file</em></p>
```

**Note:** Demo credentials are NO LONGER hardcoded. They must be set in `.env` file (not committed to Git).

### Route URL Reference

Quick reference for test development and understanding flows:

- `/` - Homepage (product catalog)
- `/login` - GET: login form, POST: authenticate
- `/logout` - Clear session
- `/cart` - View shopping cart
- `/cart/add/<product_id>` - Add item to cart (POST)
- `/cart/remove/<product_id>` - Remove item (POST)
- `/checkout` - Checkout page (GET, requires authentication)
- `/checkout/place-order` - Create order (POST, requires authentication)
- `/order/<int:order_id>` - Order confirmation (note: `/order/` not `/order-confirmation/`)
- `/health` - Health check endpoint (database connectivity test)
- `/version` - Version info endpoint (returns app version, environment, demo_id)

See [app/TESTING.md](app/TESTING.md) for test examples using these routes.

## Database Schema

Required tables:
- `products` - Bagel types (id, name, description, price)
- `inventory` - Stock levels (product_id, quantity, last_updated)
- `orders` - Customer orders (id, order_date, total_amount, status)
- `order_items` - Order line items (order_id, product_id, quantity, price)

No user management - single hardcoded user for authentication.

## Python Import Patterns in Docker

When running Flask app in Docker:
- WORKDIR is `/app`, code is in `/app/src/`
- Python runs from `/app/src/` context
- **Use relative imports** in application code:
  ```python
  # ✅ Correct
  from routes import bp
  from database import execute_query
  from models import Product

  # ❌ Wrong (fails in Docker)
  from src.routes import bp
  from src.database import execute_query
  ```
- After changing imports, rebuild with `docker compose build --no-cache`

**Verification:** See [app/TESTING.md](app/TESTING.md) for automated tests that validate import patterns and detailed troubleshooting.

## Security & Secrets

**GitHub Secrets (Required for CI/CD):**
- `AWS_ACCESS_KEY_ID` - AWS credentials for S3 and Secrets Manager
- `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `LIQUIBASE_LICENSE_KEY` - **Required!** Liquibase Pro/Secure license for Flow files and policy checks
  - Get free trial: https://www.liquibase.com/trial
  - Used by GitHub Actions workflows for PR validation and main CI
- `HARNESS_WEBHOOK_URL` - Harness pipeline webhook
- `DEMO_ID` - Demo instance identifier (e.g., "demo1")

**Harness Secrets:**
- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`
- `GITHUB_PAT` (for changelog artifacts from GitHub Packages only)

**Note:** Docker images are **public** on GitHub Container Registry - no authentication needed for pulling.

**AWS Tagging (all resources):**
- `demo_id`: Unique demo identifier
- `deployed_by`: AWS username
- `managed_by`: "terraform"
- `project`: "bagel-store-demo"

## Architecture Decision Records (ADRs)

### Why Docker Container Execution for Liquibase?
- **Decision:** Run Liquibase via Docker container, not `liquibase/setup-liquibase@v1`
- **Reason:** Consistent across local dev and CI/CD
- **Trade-off:** Requires explicit Docker mount management

### Why LIQUIBASE_COMMAND_* Environment Variables?
- **Decision:** Use `LIQUIBASE_COMMAND_*` exclusively in GitHub Actions
- **Reason:** Proven best practice pattern
- **Exception:** Flow files use `${VARIABLE}` syntax for globalVariables

### Why Absolute Paths in Flow Files?
- **Decision:** All shell commands in flow files use absolute paths (`/liquibase/*`)
- **Reason:** Working directory is `/liquibase`, not repository root
- **Learned:** October 2025 session debugging artifact creation
- **Fix Applied:** main-deployment-flow.yaml lines 77-85

### GitHub Actions Workflow Design
- **PR Validation:** Policy checks only (fast feedback, ~2 min)
- **Test Deployment:** Full validation (deploy + 15 tests, ~5 min)
- **Main CI:** Artifact creation only (no database deployment)
- **Rationale:** Separation of concerns, parallel execution, clear failure points

See [requirements-design-plan.md](requirements-design-plan.md) for complete system design.

## Quick Reference - File Locations

**GitHub Actions:**
- `.github/workflows/pr-validation.yml` - Policy checks (2 min)
- `.github/workflows/test-deployment.yml` - Full validation (5 min)
- `.github/workflows/main-ci.yml` - Artifact build

**Liquibase Flow Files:**
- `liquibase-flows/pr-validation-flow.yaml` - PR validation stages
- `liquibase-flows/main-deployment-flow.yaml` - Artifact creation
- `liquibase-flows/liquibase.checks-settings.conf` - 12 BLOCKER checks

**Key Paths (Inside Docker):**
- `/liquibase/changelog` - Master changelog and changesets
- `/liquibase/flows` - Flow files and checks config
- `/liquibase/reports` - Operation reports (HTML)
- `/liquibase/artifacts` - Changelog zip files

## Cost Estimates

Running continuously: ~$37-42/month
- RDS db.t3.micro: ~$15-20
- App Runner (4 services, no auto-scaling): ~$20
- Route53: $0.50
- Secrets Manager: ~$2

**Run `terraform destroy` after demos to minimize costs.**

## Code Review & Security Checklist

### Before Committing Infrastructure Changes

**Terraform files (.tf, .tfvars.example):**
- [ ] No hardcoded AWS account names or IDs
- [ ] No hardcoded VPC/subnet/security group IDs
- [ ] No organization-specific values in `default` blocks
- [ ] All secrets use variables (never hardcoded)
- [ ] `terraform.tfvars.example` includes all required variables

**Application files:**
- [ ] No credentials in code (use `.env` files)
- [ ] `.env.example` exists with placeholders
- [ ] Secrets use environment variables or AWS Secrets Manager

**Git safety:**
```bash
# Verify .gitignore is working
git check-ignore -v app/.env terraform/terraform.tfvars

# Check for accidentally staged secrets
git diff --staged | grep -i "password\|secret\|token\|key"
```

## Development Workflow

### Phase Completion Checklist
When completing a phase:
1. Test locally using Docker Compose (see [app/TESTING.md](app/TESTING.md))
2. Run automated Playwright tests if UI changes
3. Update CLAUDE.md with new patterns/commands learned
4. Update requirements-design-plan.md with implementation details
5. Commit with descriptive message including phase number
6. Push to trigger CI/CD workflows

### File Organization Patterns
- **App code**: `app/src/` - Flask application with Blueprint architecture
- **Database**: `db/changelog/` - Master YAML + SQL changesets
- **Infrastructure**: `terraform/` - All AWS resources
- **CI/CD**: `.github/workflows/` - GitHub Actions
- **Deployment**: `harness/` - Harness pipelines and delegate
- **Flow files**: `liquibase-flows/` - Uploaded to S3 by Terraform

## Troubleshooting

### Common Issues

**ModuleNotFoundError: No module named 'src'**
- Cause: Using absolute imports (`from src.routes`) in Docker
- Fix: Use relative imports (`from routes`) and rebuild with `--no-cache`

**Port 5000 already in use**
- Cause: macOS ControlCenter uses port 5000
- Fix: App already configured for port 5001 externally

**Docker cache issues**
- Fix: `docker compose build --no-cache && docker compose up`

**Liquibase version issues**
- Ensure minimum 4.32.0 for Flow and policy checks

**GitHub Actions failures**
- Verify action versions (v4 for checkout/upload-artifact)
- Use LIQUIBASE_COMMAND_* environment variables exclusively

**Policy check failures**
- Review `liquibase.checks-settings.conf` for BLOCKER severity settings

**S3 access issues**
- Confirm AWS credentials and bucket permissions

For detailed troubleshooting, see [app/TESTING.md](app/TESTING.md).

For Python package conflicts: Use `pipx` for CLI tools, `uv` for project dependencies.
