# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a demonstration repository showcasing coordinated application and database deployments using **Harness CD**, **GitHub Actions**, **Liquibase Secure 5.0.1**, and **AWS infrastructure**. The project deploys a Python Flask "Bagel Store" application with PostgreSQL database changes across four environments (dev, test, staging, prod).

**Key Pattern:** All resources are tagged with a unique `demo_id` to support multiple concurrent demo instances.

## Repository Structure

```
├── app/                          # Flask application
│   ├── src/                      # Application source code
│   ├── tests/                    # Pytest + Playwright tests
│   ├── Dockerfile                # Docker image definition
│   ├── docker-compose.yml        # Local dev environment
│   └── pyproject.toml            # Python dependencies (PEP 621)
├── db/changelog/                 # Liquibase changesets
│   ├── changelog-master.yaml     # Master changelog (YAML format)
│   └── changesets/               # Individual changesets (formatted SQL)
├── terraform/                    # AWS infrastructure as code
├── harness/                      # Harness CD pipelines
├── liquibase-flows/              # Flow files and policy checks
├── .github/workflows/            # GitHub Actions CI/CD
├── scripts/                      # Diagnostic and helper scripts
└── docs/                         # Detailed documentation
```

## First-Time Setup

**Quick start:**
1. Run dependency checker: `./scripts/check-dependencies.sh`
2. Configure local environment: `cd app && cp .env.example .env`
3. Start application: `docker compose up --build`

**For detailed setup:**
- See [SETUP.md](SETUP.md) for platform-specific installation
- See [docs/AWS_SETUP.md](docs/AWS_SETUP.md) for AWS configuration
- Type `/setup` at Claude Code prompt for AI-assisted guidance

## AI Documentation Reference Rules

**IMPORTANT:** Before working on specific areas, automatically read the relevant documentation:

### When Working On Specific Areas

- **AWS/Infrastructure issues** → Read [docs/AWS_SETUP.md](docs/AWS_SETUP.md) first
  - AWS SSO, credentials, common AWS errors

- **GitHub Actions workflows** → Reference [docs/WORKFLOWS.md](docs/WORKFLOWS.md)
  - Workflow architecture, debugging, environment variables

- **Testing (unit, integration, E2E)** → Consult [app/TESTING.md](app/TESTING.md)
  - 15 test cases, fixtures, Playwright patterns

- **Database changes/changesets** → Review [db/changelog/README.md](db/changelog/README.md)
  - Changeset format, policy checks, validation rules

- **Terraform errors/changes** → Check [terraform/README.md](terraform/README.md)
  - Resource architecture, multi-instance pattern, DNS configuration

- **Application architecture** → Read [app/README.md](app/README.md)
  - Flask Blueprint structure, routing, templates

- **Flow files and policy checks** → See [liquibase-flows/README.md](liquibase-flows/README.md)
  - Flow file patterns, globalVariables, absolute paths

- **Harness CD pipelines** → Review [harness/README.md](harness/README.md) and [harness/pipelines/README.md](harness/pipelines/README.md)
  - Delegate setup, connector configuration, pipeline architecture

- **Any errors or issues** → Start with [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
  - Diagnostic scripts, common errors, solutions

**Pattern:** Read documentation BEFORE suggesting changes or answering questions about these areas.

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

### Liquibase GitHub Actions Configuration

**ALWAYS use these exact versions:**

```yaml
- uses: actions/checkout@v4  # NOT v3 (deprecated)
- uses: liquibase/setup-liquibase@v1
  with:
    version: '4.32.0'  # Minimum 4.32.0
    edition: 'pro'     # Required for Flow and policy checks
- uses: actions/upload-artifact@v4  # NOT v3
- uses: aws-actions/configure-aws-credentials@v4
```

**Environment Variables - CRITICAL:**
- **MUST use `LIQUIBASE_COMMAND_*` environment variables in GitHub Actions**
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

### Flow File Path Requirements

**CRITICAL:** Flow files execute inside Docker containers with specific mount points.

**Docker mount structure (GitHub Actions):**
```bash
-v ${{ github.workspace }}/db/changelog:/liquibase/changelog
-v ${{ github.workspace }}/liquibase-flows:/liquibase/flows
-v ${{ github.workspace }}/reports:/liquibase/reports
-w /liquibase  # Working directory
```

**Artifact Creation Pattern:**
- ❌ Do NOT create artifacts in flow files (Docker permission issues)
- ✅ Create artifacts in GitHub Actions workflow after flow completes
- Flow files are for validation/checks only
- Why: Docker volume mounts have permission issues - container user cannot write to mounted directories

### Changelog Format

- **Master changelog:** YAML format (NOT XML) - `changelog-master.yaml`
- **Individual changesets:** Formatted SQL files in `changesets/` directory

### Python Dependency Management

**Use `uv` instead of `pip`:**

```bash
cd app
uv sync              # Install dependencies
uv add <package>     # Add new package
uv run python src/app.py  # Run application
uv run pytest        # Run tests
```

Benefits: 10-100x faster than pip, reproducible builds via `uv.lock`

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
- **Fix Applied:** main-deployment-flow.yaml uses absolute paths

### GitHub Actions Workflow Design
- **PR Validation:** Policy checks only (fast feedback, ~2 min)
- **Test Deployment:** Full validation (deploy + 15 tests, ~5 min)
- **Main CI:** Artifact creation only (no database deployment)
- **Rationale:** Separation of concerns, parallel execution, clear failure points

## Quick Reference

### Local Development
```bash
cd app
docker compose up --build     # Start app (http://localhost:5001)
uv run pytest                 # Run tests
docker compose build --no-cache  # Rebuild after template changes
```

### Database Development
```bash
# Create changeset in db/changelog/changesets/
# Update db/changelog/changelog-master.yaml
# Test locally (see db/changelog/README.md)
```

### CI/CD Debugging
```bash
# Get latest run and watch
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $RUN_ID --exit-status
gh run view $RUN_ID --log-failed
```

### Harness Delegate
```bash
cd harness
docker compose up -d          # Start delegate
docker compose logs -f        # View logs
docker compose ps             # Check status
docker compose down           # Stop delegate
```

See [docs/COMMANDS.md](docs/COMMANDS.md) for complete reference.

## Documentation Index

### Core Documentation
- **[README.md](README.md)** - Project overview and architecture
- **[SETUP.md](SETUP.md)** - Complete setup guide (Windows, macOS, Linux)
- **[requirements-design-plan.md](requirements-design-plan.md)** - System design

### Application & Testing
- **[app/README.md](app/README.md)** - Application architecture
- **[app/TESTING.md](app/TESTING.md)** - Comprehensive testing guide (15 tests)

### Database
- **[db/changelog/README.md](db/changelog/README.md)** - Changeset documentation and policy checks

### Infrastructure & Operations
- **[terraform/README.md](terraform/README.md)** - AWS infrastructure
- **[docs/AWS_SETUP.md](docs/AWS_SETUP.md)** - AWS SSO, credentials, common issues
- **[docs/WORKFLOWS.md](docs/WORKFLOWS.md)** - GitHub Actions workflows
- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Complete command reference
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Diagnostic scripts and solutions

### Flow Files
- **[liquibase-flows/README.md](liquibase-flows/README.md)** - Flow file documentation

### Harness CD
- **[harness/README.md](harness/README.md)** - Delegate setup, connectors, secrets
- **[harness/pipelines/README.md](harness/pipelines/README.md)** - Pipeline architecture and execution

## Security & Secrets

### GitHub Secrets (Required for CI/CD)
- `AWS_ACCESS_KEY_ID` - AWS credentials for S3 and Secrets Manager
- `AWS_SECRET_ACCESS_KEY` - AWS credentials
- `LIQUIBASE_LICENSE_KEY` - **Required!** Liquibase Pro/Secure license
- `HARNESS_WEBHOOK_URL` - Harness pipeline webhook
- `DEMO_ID` - Demo instance identifier (e.g., "demo1")

### Harness Secrets (Required for Deployment)
- `github_pat` - GitHub Personal Access Token (scopes: `repo`, `read:packages`)
- `aws_access_key_id` - AWS Access Key for deployments
- `aws_secret_access_key` - AWS Secret Key for deployments
- `liquibase_license_key` - Liquibase Pro/Secure license key

### Security-Sensitive Files

**Never commit these:**
- `app/.env` - Local credentials (in .gitignore)
- `terraform/*.tfvars` - Infrastructure secrets (in .gitignore)
- `harness/.env` - Harness delegate credentials (in .gitignore)

**Always commit these:**
- `app/.env.example` - Template with placeholders
- `terraform/terraform.tfvars.example` - Infrastructure template
- `harness/.env.example` - Harness delegate template

**Check:** `git check-ignore -v <file>` to verify gitignore status

## Development Workflow

### Phase Completion Checklist
When completing a phase:
1. Test locally using Docker Compose (see [app/TESTING.md](app/TESTING.md))
2. Run automated tests if changes affect UI or database
3. Update documentation if patterns change
4. Commit with descriptive message
5. Push to trigger CI/CD workflows

### File Organization
- **App code**: `app/src/` - Flask application with Blueprint architecture
- **Database**: `db/changelog/` - Master YAML + SQL changesets
- **Infrastructure**: `terraform/` - All AWS resources
- **CI/CD**: `.github/workflows/` - GitHub Actions
- **Deployment**: `harness/` - Harness pipelines and delegate
- **Flow files**: `liquibase-flows/` - Uploaded to S3 by Terraform

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

## Getting Help

### 1. Check Documentation
Start with the [Documentation Index](#documentation-index) above

### 2. Run Diagnostic Scripts
```bash
./scripts/check-dependencies.sh  # General issues
./scripts/diagnose-aws.sh        # AWS-specific issues
```

### 3. AI-Assisted Help
- Type `/setup` for guided setup assistance
- See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues

### 4. Review Logs
```bash
docker compose logs app       # Application logs
docker compose logs postgres  # Database logs
```
