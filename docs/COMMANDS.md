# Command Reference

Complete command reference for the Bagel Store Demo project.

## Table of Contents

1. [Git Workflow](#git-workflow)
2. [GitHub Actions Commands](#github-actions-commands)
3. [Terraform Commands](#terraform-commands)
4. [Docker Commands](#docker-commands)
5. [Python/uv Commands](#pythonuv-commands)
6. [Database Commands](#database-commands)
7. [Liquibase Commands](#liquibase-commands)
8. [Harness Delegate](#harness-delegate)
9. [Review Commands](#review-commands)

---

## Git Workflow

### Check Status and Review Changes

```bash
# Check status
git status

# Review changes
git diff <file>

# Check authorship before amending
git log -1 --format='%an %ae'
```

### Commit with Detailed Message

```bash
git add <files>
git commit -m "$(cat <<'EOF'
<multi-line commit message>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
git push
```

---

## GitHub Actions Commands

### Get Latest Run ID

```bash
gh run list --limit 1 --json databaseId --jq '.[0].databaseId'
```

### Watch Specific Run

```bash
# Use run ID from above
gh run watch <run-id> --exit-status
```

### View Failed Job Logs Only

```bash
gh run view <run-id> --log-failed
```

### Search Logs for Specific Errors

```bash
gh run view <run-id> --log | grep -B5 -A10 "ERROR\|Permission"
```

### Check Specific Step Output

```bash
gh run view <run-id> --log | grep -A5 "Create changelog artifact"
```

### List Recent Runs with Status

```bash
gh run list --limit 5
```

### CI/CD Debugging Pattern

```bash
# 1. Check git status and push changes
git status
git add <files>
git commit -m "Fix: description"
git push

# 2. Get latest run ID and watch
RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $RUN_ID --exit-status

# 3. If failed, check logs for errors
gh run view $RUN_ID --log-failed
gh run view $RUN_ID --log | grep -A10 "ERROR\|Permission denied"

# 4. Check specific step output
gh run view $RUN_ID --log | grep -A5 "Step name"
```

---

## Terraform Commands

### Initialize

```bash
terraform init
```

### Plan with demo_id

```bash
terraform plan -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
```

### Apply Infrastructure

```bash
terraform apply -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
```

### Destroy All Resources for a Demo Instance

```bash
terraform destroy -var="demo_id=demo1"
```

### Security Review Before Sharing

```bash
# Check for hardcoded AWS-specific values
cd terraform
grep -r "vpc-\|sg-\|arn:aws:iam" *.tf

# Verify all values are parameterized
cat variables.tf terraform.tfvars.example

# Review default tags (should not include org-specific values)
grep -A5 "common_tags" variables.tf
```

---

## Docker Commands

### Start Services in Background

```bash
docker compose up -d
```

### View All Logs

```bash
docker compose logs
```

### View Specific Service Logs

```bash
docker compose logs -f app
docker compose logs -f postgres
```

### Restart a Service

```bash
docker compose restart app
```

### Execute Command in Container

```bash
docker compose exec app python -c "print('Hello')"
docker compose exec postgres psql -U postgres -d dev
```

### Rebuild After Code Changes

```bash
docker compose up --build
```

### Rebuild Without Cache

*Required after import changes or template modifications*

```bash
docker compose build --no-cache
```

### Stop Services

```bash
docker compose stop
```

### Stop and Remove Containers

```bash
docker compose down
```

### Stop and Remove Containers + Volumes

```bash
docker compose down -v
```

---

## Python/uv Commands

### Sync Dependencies

```bash
cd app
uv sync
```

### Add New Dependency

```bash
uv add flask-cors
```

### Run App Locally (Without Docker)

```bash
uv run python src/app.py
```

### Run Tests

```bash
uv run pytest
```

### Run Tests with Specific Markers

```bash
uv run pytest -m health        # Health checks only
uv run pytest -m e2e          # E2E tests only
uv run pytest -m "not slow"   # Skip slow tests
```

### Run Tests with Visible Browser

```bash
uv run pytest --headed
```

### Rebuild Docker Image After Template Changes

*Templates are baked into image at build time*

```bash
docker compose build --no-cache
docker compose up -d
uv run pytest -m health  # Verify changes
```

---

## Database Commands

### Connect to Database

```bash
docker compose exec postgres psql -U postgres -d bagelstore
```

### Run SQL Query

```bash
docker compose exec postgres psql -U postgres -d bagelstore -c "SELECT * FROM products;"
```

### List All Tables

```bash
docker compose exec -T postgres psql -U postgres -d bagelstore -c "\dt"
```

### View Table Structure

```bash
docker compose exec -T postgres psql -U postgres -d bagelstore -c "\d products"
```

### Query Data

```bash
docker compose exec -T postgres psql -U postgres -d bagelstore -c "SELECT * FROM products;"
```

### Check Liquibase Changelog History

```bash
docker compose exec -T postgres psql -U postgres -d bagelstore -c "SELECT id, author, filename, dateexecuted FROM databasechangelog ORDER BY dateexecuted;"
```

### Drop Database (Reset for Testing)

```bash
docker compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS bagelstore;"
docker compose exec -T postgres psql -U postgres -c "CREATE DATABASE bagelstore;"
```

### Backup Database

```bash
docker compose exec postgres pg_dump -U postgres bagelstore > backup.sql
```

### Restore Database

```bash
docker compose exec -T postgres psql -U postgres -d bagelstore < backup.sql
```

---

## Liquibase Commands

### Validate Changelog Syntax

```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  validate
```

### Check Status (Dry Run)

```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  status --verbose
```

### Apply Changes

```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  update
```

### Rollback Last Change

```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e LIQUIBASE_LICENSE_KEY="${LIQUIBASE_LICENSE_KEY}" \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  rollback-count 1
```

### AWS Secrets Manager Integration (Production)

```bash
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
```

### Run Flow File from S3

```bash
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

---

## Harness Delegate

### Start Delegate

```bash
cd harness
docker compose up -d
```

### View Logs

```bash
docker compose logs -f harness-delegate
```

### Stop Delegate

```bash
docker compose down
```

---

## Review Commands

### Verify GitHub Actions Locally

```bash
# Check workflow syntax
cat .github/workflows/pr-validation.yml

# Verify Docker mount paths in workflows
grep -r "github.workspace" .github/workflows/

# Check environment variable patterns
grep -r "LIQUIBASE_COMMAND_" .github/workflows/
```

### Flow File Validation

```bash
# Verify flow file paths are absolute
grep -n "cd " liquibase-flows/*.yaml
grep -n "mkdir" liquibase-flows/*.yaml

# Check for relative path issues
grep -n "\.\." liquibase-flows/*.yaml  # Should find none
```

---

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

---

## Additional Resources

- **Setup:** [SETUP.md](../SETUP.md)
- **Testing:** [app/TESTING.md](../app/TESTING.md)
- **Database:** [db/changelog/README.md](../db/changelog/README.md)
- **Workflows:** [WORKFLOWS.md](WORKFLOWS.md)
- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
