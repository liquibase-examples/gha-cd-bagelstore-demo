# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a demonstration repository showcasing coordinated application and database deployments using **Harness CD**, **GitHub Actions**, **Liquibase Secure 5.0.1**, and **AWS infrastructure**. The project deploys a Python Flask "Bagel Store" application with PostgreSQL database changes across four environments (dev, test, staging, prod).

**Key Pattern:** All resources are tagged with a unique `demo_id` to support multiple concurrent demo instances.

## Repository Structure

```
├── app/                          # Flask application
│   ├── src/                      # Application source code
│   ├── Dockerfile                # Docker image definition
│   ├── pyproject.toml            # Python dependencies (PEP 621)
│   └── uv.lock                   # Locked dependency versions
├── db/
│   └── changelog/
│       ├── changelog-master.yaml # Master changelog (YAML format)
│       └── changesets/           # SQL changesets (formatted SQL)
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
└── .github/workflows/
    ├── pr-validation.yml
    ├── main-ci.yml
    └── app-ci.yml
```

## Common Commands

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

# Run tests
uv run pytest
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

### Liquibase Testing
```bash
# Test locally with AWS Secrets Manager integration
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_REGION=us-east-1 \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://localhost:5432/dev \
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
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/pr-validation-flow.yaml
```

## Critical Implementation Requirements

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
- **DO NOT use custom property substitution** (e.g., `${VARIABLE}` in properties files)
- Required variables:
  ```yaml
  env:
    LIQUIBASE_COMMAND_URL: jdbc:postgresql://host:5432/database
    LIQUIBASE_COMMAND_USERNAME: username
    LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
    LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
  ```

### Changelog Format
- **Master changelog:** YAML format (NOT XML) - `changelog-master.yaml`
- **Individual changesets:** Formatted SQL files in `changesets/` directory
- Pattern source: `../liquibase-patterns/repos/postgres-flow-policy-demo`

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
   - Push to GitHub Container Registry

**Harness Deployment (Remote YAML pipeline):**
1. Fetch artifacts (changelog zip + Docker image)
2. Update database via Liquibase Docker container
3. Deploy application to App Runner
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

## Database Schema

Required tables:
- `products` - Bagel types (id, name, description, price)
- `inventory` - Stock levels (product_id, quantity, last_updated)
- `orders` - Customer orders (id, order_date, total_amount, status)
- `order_items` - Order line items (order_id, product_id, quantity, price)

No user management - single hardcoded user for authentication.

## Security & Secrets

**GitHub Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `HARNESS_WEBHOOK_URL`
- `DEMO_ID`
- `LIQUIBASE_LICENSE_KEY`

**Harness Secrets:**
- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`
- `GITHUB_PAT`

**AWS Tagging (all resources):**
- `demo_id`: Unique demo identifier
- `deployed_by`: AWS username
- `managed_by`: "terraform"
- `project`: "bagel-store-demo"

## Reference Patterns

This implementation leverages proven patterns from `../liquibase-patterns`:
- **postgres-flow-policy-demo** - Flow structure, policy checks, operation reports
- **dbt-example** - GitHub Actions setup, LIQUIBASE_COMMAND_* variables
- **Liquibase-workshop-repo** - PostgreSQL patterns, AWS integration

See [requirements-design-plan.md](requirements-design-plan.md) for complete system design.

## Cost Estimates

Running continuously: ~$37-42/month
- RDS db.t3.micro: ~$15-20
- App Runner (4 services, no auto-scaling): ~$20
- Route53: $0.50
- Secrets Manager: ~$2

**Run `terraform destroy` after demos to minimize costs.**

## Implementation Notes

When encountering errors:
- Liquibase version issues: Ensure minimum 4.32.0
- GitHub Actions failures: Verify action versions (v4 for checkout/upload-artifact)
- Environment variables not working: Use LIQUIBASE_COMMAND_* pattern exclusively
- Policy check failures: Review `liquibase.checks-settings.conf` for BLOCKER severity settings
- S3 access issues: Confirm AWS credentials and bucket permissions

For Python package conflicts: Use `pipx` for CLI tools, `uv` for project dependencies.
