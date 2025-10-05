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

## Local Development & Testing

For local development and testing of the Flask application, see [app/TESTING.md](app/TESTING.md).

**Quick Start:**
```bash
cd app
docker compose up --build  # Access at http://localhost:5001
```

**Important:** Port 5001 is used externally (macOS ControlCenter uses 5000).

## Common Commands

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
# Source of truth: app/src/routes.py:12
DEMO_USER = {'username': 'demo', 'password': 'B@gelSt0re2025!Demo'}
```
```html
<!-- Must match: app/src/templates/login.html:30 -->
<p>Password: <code>B@gelSt0re2025!Demo</code></p>
```

### Route URL Reference

Quick reference for test development and understanding flows:

- `/` - Homepage (product catalog)
- `/login` - GET: login form, POST: authenticate
- `/logout` - Clear session
- `/cart` - View shopping cart
- `/cart/add/<product_id>` - Add item to cart (POST)
- `/cart/remove/<product_id>` - Remove item (POST)
- `/checkout` - Checkout page (requires authentication)
- `/checkout/place-order` - Create order (POST)
- `/order/<int:order_id>` - Order confirmation (note: `/order/` not `/order-confirmation/`)
- `/health` - Health check endpoint

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

**GitHub Secrets:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `HARNESS_WEBHOOK_URL`
- `DEMO_ID`
- `LIQUIBASE_LICENSE_KEY`

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
