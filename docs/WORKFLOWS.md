# GitHub Actions Workflows

Detailed documentation for all GitHub Actions workflows in the Bagel Store Demo project.

## Table of Contents

1. [Overview](#overview)
2. [PR Validation Workflow](#pr-validation-workflow)
3. [Test Deployment Workflow](#test-deployment-workflow)
4. [Main CI Workflow](#main-ci-workflow)
5. [Workflow Files Reference](#workflow-files-reference)
6. [Viewing Workflow Results](#viewing-workflow-results)

---

## Overview

Three workflows orchestrate the complete CI/CD pipeline with Liquibase policy checks and system tests.

### Workflow Summary

| Workflow | Trigger | Duration | Purpose |
|----------|---------|----------|---------|
| **pr-validation.yml** | Pull requests to main (changes to `db/changelog/` or `liquibase-flows/`) | ~2 min | Run Liquibase policy checks BEFORE deployment |
| **test-deployment.yml** | Pull requests to main (changes to `app/` or `db/changelog/`) | ~5 min | Deploy changelog to database and verify with system tests |
| **main-ci.yml** | Push to main branch (after PR merge) | ~3 min | Build and publish versioned artifacts |

---

## PR Validation Workflow

**File:** `.github/workflows/pr-validation.yml`

**Trigger:** Pull requests to main (changes to `db/changelog/` or `liquibase-flows/`)

**Purpose:** Run Liquibase policy checks BEFORE deployment

### What It Does

1. Starts PostgreSQL container (postgres:16)
2. Runs Liquibase PR validation flow file
3. Executes 12 BLOCKER-level policy checks
4. Uploads operation reports as artifacts
5. Adds PR comment with pass/fail status
6. Blocks merge if any BLOCKER check fails

### Required GitHub Secrets

- `LIQUIBASE_LICENSE_KEY` - Required for Flow and policy checks

### Key Pattern

- Uses local flow file: `/liquibase/flows/pr-validation-flow.yaml`
- Migrates to S3 when Terraform permissions resolved (see Phase 1 step 6 in requirements-design-plan.md)
- Uses `LIQUIBASE_COMMAND_*` environment variables (proven best practice)

### Configuration

```yaml
env:
  LIQUIBASE_COMMAND_URL: jdbc:postgresql://localhost:5432/bagelstore
  LIQUIBASE_COMMAND_USERNAME: postgres
  LIQUIBASE_COMMAND_PASSWORD: postgres
  LIQUIBASE_COMMAND_CHANGELOG_FILE: changelog-master.yaml
  LIQUIBASE_COMMAND_CHECKS_SETTINGS_FILE: /liquibase/flows/liquibase.checks-settings.conf
  LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
```

### Permissions

```yaml
permissions:
  contents: read
  pull-requests: write
```

---

## Test Deployment Workflow

**File:** `.github/workflows/test-deployment.yml`

**Trigger:** Pull requests to main (changes to `app/` or `db/changelog/`)

**Purpose:** Deploy changelog to database and verify with system tests

### What It Does

1. Creates .env file with random demo credentials (no secrets needed!)
2. Starts full Docker Compose (postgres + Flask app)
3. Deploys Liquibase changelog to dev database
4. Verifies deployment with bash checks
5. Runs pytest test suite (22 tests):
   - 7 deployment verification tests (NEW!)
   - 4 health check tests
   - 11 E2E shopping flow tests (Playwright)
6. Uploads test reports as artifacts
7. Adds PR comment with test results

### Required GitHub Secrets

- `LIQUIBASE_LICENSE_KEY` - ✅ **SET** (repository-level secret)

### Demo Credentials

Generated randomly per CI run using `openssl rand -base64 32` (no secrets needed)

### NEW Deployment Verification Tests

**File:** `test_liquibase_deployment.py`

1. ✅ Verifies databasechangelog table exists
2. ✅ Confirms all 9 changesets applied in correct order
3. ✅ Validates all tables created (products, inventory, orders, order_items)
4. ✅ Checks all 4 indexes created
5. ✅ Verifies foreign key constraints exist
6. ✅ Confirms seed data loaded correctly (5 products, 5 inventory)
7. ✅ Validates database tags applied (v1.0.0-baseline, v1.0.0)

### Test Validation

- Liquibase deployment validated with Python tests
- Database schema matches changelog exactly
- All seed data loaded correctly
- Flask app health checks pass
- Complete E2E shopping flow works

### Permissions

```yaml
permissions:
  contents: read
  pull-requests: write
```

---

## Main CI Workflow

**File:** `.github/workflows/main-ci.yml`

**Trigger:** Push to main branch (after PR merge)

**Purpose:** Build and publish versioned artifacts

### Two Parallel Jobs

#### Job A: Build Database Artifact

```bash
# 1. Extract version from git tag or commit SHA
# 2. Run Liquibase main deployment flow file
#    - Policy checks
#    - Validation
# 3. Create changelog tar.gz artifact in workflow (not in flow file)
# 4. Upload changelog tar.gz to GitHub Packages
# 5. Upload operation reports as artifacts
```

#### Job B: Build Application Docker Image

```bash
# 1. Extract version from git tag or commit SHA
# 2. Build Docker image
# 3. Tag: public.ecr.aws/l1v5b6d6/<demo_id>-bagel-store:<version>
# 4. Push to AWS Public ECR
# 5. Also tag as 'latest'
```

#### Job C: Trigger Harness Deployment (optional)

```bash
# Only runs if HARNESS_WEBHOOK_URL variable is configured
# Triggers Harness CD pipeline for dev environment deployment
```

### Optional GitHub Variables

- `DEMO_ID` - Demo instance identifier (defaults to "demo1")
- `HARNESS_WEBHOOK_URL` - For automatic Harness deployments

### Permissions

```yaml
permissions:
  contents: read
  packages: write  # For GHCR
```

---

## Workflow Files Reference

### PR Validation: `pr-validation.yml`

- **Permissions:** `contents: read`, `pull-requests: write`
- **Runs:** Policy checks only (no deployment)
- **Uses:** PostgreSQL service container
- **Mounts:** changelog, flows, reports

### Test Deployment: `test-deployment.yml`

- **Permissions:** `contents: read`, `pull-requests: write`
- **Runs:** Deploys changelog + runs 15 pytest tests
- **Uses:** Docker Compose (not service container)
- **Verifies:** changesets, products, inventory, indexes

### Main CI: `main-ci.yml`

- **Permissions:** `contents: read`, `packages: write`
- **Builds:** changelog tar.gz + Docker image
- **Triggers:** Harness webhook
- **Versioning:** From git tags

---

## Viewing Workflow Results

### Check Workflow Status

```bash
gh run list --workflow=pr-validation.yml
```

### View Latest Run

```bash
gh run view
```

### Download Artifacts (Reports)

```bash
gh run download <run-id>
```

### View Workflow Logs

```bash
gh run view <run-id> --log
```

---

## Local Flow Files (Temporary)

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

---

## Additional Resources

- **GitHub Actions Documentation:** https://docs.github.com/en/actions
- **Liquibase Flow Documentation:** https://docs.liquibase.com/commands/flow/home.html
- **Docker Compose in CI:** https://docs.docker.com/compose/ci/

For troubleshooting workflow issues, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
