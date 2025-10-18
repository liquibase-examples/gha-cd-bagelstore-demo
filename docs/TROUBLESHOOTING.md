# Troubleshooting Guide

Comprehensive troubleshooting guide for the Bagel Store Demo project.

## Table of Contents

1. [Diagnostic Scripts](#diagnostic-scripts)
2. [Setup Issues](#setup-issues)
3. [Common Workflow Issues](#common-workflow-issues)
4. [Application Issues](#application-issues)
5. [Getting Help](#getting-help)

---

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

---

## Setup Issues

### Setup Troubleshooting Workflow

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
- AWS SSO → See docs/AWS_SETUP.md
- Testing → app/TESTING.md
- **Don't re-explain what's already documented**

**4. Interactive help:**
- Type `/setup` for AI-guided troubleshooting

### Docker Issues

**Problem:** Docker daemon not running
```
Cannot connect to the Docker daemon
```

**Solution:**
- **macOS/Windows:** Start Docker Desktop from Applications
- **Linux:** `sudo systemctl start docker`

---

**Problem:** Port 5001 already in use
```
Error starting userland proxy: listen tcp4 0.0.0.0:5001: bind: address already in use
```

**Solution:**
```bash
# Find process using the port
lsof -ti:5001

# Kill the process
lsof -ti:5001 | xargs kill
```

---

**Problem:** Permission denied when running Docker
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
- **Linux:** Add user to docker group: `sudo usermod -aG docker $USER` (then log out/in)
- **macOS/Windows:** Docker Desktop should handle permissions automatically

---

**Problem:** Docker cache issues

**Symptom:** Code changes not reflected in running container.

**Fix:**
```bash
# Stop containers
docker compose down

# Rebuild without cache
docker compose build --no-cache

# Start fresh
docker compose up
```

---

### Python/uv Issues

**Problem:** uv command not found
```
bash: uv: command not found
```

**Solution:**
```bash
# Reinstall uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Restart terminal or source profile
source ~/.bashrc  # or ~/.zshrc on macOS
```

---

**Problem:** Python version too old
```
Python 3.9.x found, but >= 3.11 required
```

**Solution:**
- Install Python 3.11+ using platform-specific instructions (see SETUP.md)
- Ensure `python3 --version` shows 3.11+

---

### Terraform Issues

**Problem:** Terraform command not found
```
bash: terraform: command not found
```

**Solution:**
- Install Terraform using platform-specific instructions (see SETUP.md)
- Verify: `terraform --version`

---

## Common Workflow Issues

### Harness Pipeline Import Failures

#### Error: "infrastructureDefinitions should be present in stage"

**Symptom:** Pipeline import fails with error: `Invalid yaml error: infrastructureDefinitions or infrastructureDefinition should be present in stage [pipeline.stages.Deploy_to_XXX]. Please add it and try again.`

**Root Cause:** Missing infrastructure definition YAML files in `.harness/` directory

**Solution:**

1. **Verify infrastructure YAMLs exist:**
   ```bash
   find .harness -name "*infra*.yaml"
   ```

   Should show 4 files (for demo_id=psr):
   ```
   .harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_dev/infras/psr_dev_infra.yaml
   .harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_test/infras/psr_test_infra.yaml
   .harness/orgs/default/projects/bagel_store_demo/envs/PreProduction/psr_staging/infras/psr_staging_infra.yaml
   .harness/orgs/default/projects/bagel_store_demo/envs/Production/psr_prod/infras/psr_prod_infra.yaml
   ```

2. **If missing, they were incorrectly deleted.** Restore from Git history:
   ```bash
   git log --all --full-history -- '.harness/*infra*'
   # Find last commit before deletion, then restore each file:
   git show COMMIT_SHA:.harness/path/to/psr_dev_infra.yaml > .harness/orgs/.../psr_dev/infras/psr_dev_infra.yaml
   ```

3. **Verify YAML format in each file:**
   Each file must have empty `templateRef`:
   ```yaml
   spec:
     customDeploymentRef:
       templateRef: ""  # MUST be empty string, not "Custom" or any other value
   ```

4. **Commit and push the restored files:**
   ```bash
   git add .harness/
   git commit -m "Restore infrastructure definition YAMLs"
   git push
   ```

**Why this happens:**
- Harness Git Experience requires infrastructure definitions in BOTH places:
  - ✅ Terraform creates them in Harness (for runtime execution)
  - ✅ YAML files in `.harness/` (for import validation)
- Previous AI sessions sometimes incorrectly deleted these YAMLs thinking Terraform alone was sufficient

**Prevention:**
- Always run `./scripts/verify-harness-entities.sh` before attempting pipeline import
- Check `.gitignore` doesn't accidentally ignore `.harness/` directory

---

#### Error: Pipeline uses `deployToAll: true` pattern

**Symptom:** Pipeline fails validation during import even though infrastructure definitions exist

**Root Cause:** `deployToAll: true` works at runtime but fails Harness import validation

**Solution:**

Update pipeline YAML to use explicit infrastructure definition references:

**Change from:**
```yaml
environment:
  environmentRef: psr_dev
  deployToAll: true
```

**Change to:**
```yaml
environment:
  environmentRef: psr_dev
  infrastructureDefinitions:
    - identifier: psr_dev_infra
```

Repeat for all 4 stages (dev, test, staging, prod) to match their respective infrastructure definitions.

---

### Harness Webhook Trigger Issues

#### Error: "No custom trigger found for webhook token"

**Symptom:** GitHub Actions webhook trigger step shows success but logs contain:
```json
{"status":"ERROR","code":"INVALID_REQUEST","message":"Invalid request: No custom trigger found for the used custom webhook token: XXXXX"}
```

**Root Cause:** Webhook URL in GitHub doesn't match the trigger created in Harness

**Solution:**

1. **Get current webhook URL from Harness:**
   ```bash
   ./scripts/get-webhook-url.sh
   ```

   Expected output:
   ```
   https://app.harness.io/gateway/pipeline/api/webhook/custom/TOKEN_HERE/v3?accountIdentifier=...
   ```

2. **Update GitHub VARIABLE (NOT secret!):**
   ```bash
   gh variable set HARNESS_WEBHOOK_URL --body "PASTE_FULL_URL_HERE"
   ```

3. **Verify it's a variable (not secret):**
   ```bash
   gh variable list | grep HARNESS_WEBHOOK_URL
   ```

4. **If you accidentally set it as a secret, remove it:**
   ```bash
   gh secret delete HARNESS_WEBHOOK_URL
   gh variable set HARNESS_WEBHOOK_URL --body "URL_HERE"
   ```

**Common mistake:** Setting `HARNESS_WEBHOOK_URL` as a secret instead of variable. The workflow uses `vars.HARNESS_WEBHOOK_URL` which only reads variables, not secrets.

---

#### Webhook trigger stays in QUEUED state

**Symptom:** Trigger is created, webhook is called, but pipeline execution never starts (stays QUEUED forever)

**Root Cause:** Missing Pipeline Reference Branch configuration in trigger

**Solution:**

1. **Edit the trigger in Harness UI:**
   - Go to: Pipelines → Deploy Bagel Store → Triggers → GitHub_Actions_CI
   - Click Edit

2. **Set Pipeline Reference Branch:**
   - Go to "Pipeline Input" tab
   - Find "Pipeline Reference Branch" field
   - Enter: `<+trigger.branch>`

3. **Why this is required:**
   - For Git Experience (remote pipelines), Harness needs to know which Git branch to fetch the pipeline from
   - `<+trigger.branch>` uses the `branch` field from webhook payload
   - Without this, Harness cannot resolve the pipeline location

4. **Verify webhook payload includes branch:**
   ```bash
   # Check workflow sends branch field
   grep -A 5 '"branch"' .github/workflows/main-ci.yml
   ```

---

### CI/CD Debugging Workflow

**Pattern for debugging failed GitHub Actions:**

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

### Common Error Patterns

**Liquibase/GitHub Actions Errors:**
- `zip: command not found` → Use `tar -czf` instead
- `Permission denied` when writing → Check Docker mount permissions (create artifacts in workflow, not container)
- `Invalid UUID string` → Check `liquibase.checks-settings.conf` format (must use UUIDs, not shortNames)
- `expected '<document start>'` → Checks settings file must be YAML format

**GitHub Actions Workflow Issues:**

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

---

## Application Issues

### ModuleNotFoundError: No module named 'src'

**Symptom:**
```
ModuleNotFoundError: No module named 'src'
```

**Cause:** Using absolute imports (`from src.routes`) instead of relative imports in Docker context.

**Fix:**
1. Change imports to relative: `from routes import bp`
2. Rebuild without cache: `docker compose build --no-cache`
3. Restart: `docker compose up`

**Files to check:**
- `app/src/app.py`
- `app/src/routes.py`

See [app/TESTING.md](../app/TESTING.md) for detailed import patterns.

---

### Port 5000 Already in Use

**Symptom:**
```
bind: address already in use
```

**Cause:** macOS ControlCenter uses port 5000 for AirPlay Receiver.

**Fix:** Already handled in `docker-compose.yml`:
```yaml
ports:
  - "5001:5000"  # External:Internal
```

Access app at http://localhost:5001 (not 5000).

**To check what's using a port:**
```bash
lsof -i :5000 | grep LISTEN
```

---

### Database Connection Errors

**Symptom:**
```
could not connect to server: Connection refused
```

**Fix:**
1. Ensure PostgreSQL container is healthy:
   ```bash
   docker compose ps
   # Look for "healthy" status on postgres service
   ```

2. Check PostgreSQL logs:
   ```bash
   docker compose logs postgres
   ```

3. Restart database:
   ```bash
   docker compose restart postgres
   ```

---

### Playwright "Ref not found" Errors

**Symptom:**
```
Error: Ref e16 not found in the current page snapshot
```

**Cause:** Page state changed between snapshot and interaction.

**Fix:** Take a fresh snapshot before interacting:
```python
browser.snapshot()  # Fresh snapshot
browser.type("element", "text")  # Then interact
```

---

### Flask App Crashes on Startup

**Common Causes:**
1. **Missing dependencies** - Run `uv sync` and rebuild
2. **Import errors** - Check relative vs absolute imports
3. **Database not ready** - Check healthcheck in docker-compose.yml

**Debug steps:**
```bash
# View detailed logs
docker compose logs app

# Check if database is ready
docker compose exec postgres pg_isready

# Rebuild and restart
docker compose down
docker compose up --build
```

---

### Permission Denied Errors

**Symptom:**
```
ERROR: permission denied while trying to connect to Docker daemon
```

**Fix:** Ensure Docker daemon is running and user has permissions:
```bash
# macOS - ensure Docker Desktop is running
open -a Docker

# Linux - add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

---

### Tests Failing After First Run

**Problem:**
```
FAILED tests/test_e2e_shopping.py::test_login_success
```

**Solution:**
```bash
# Rebuild containers without cache
docker compose build --no-cache
docker compose up -d

# Re-run tests
uv run pytest
```

---

### Liquibase Version Issues

**Problem:** Version errors or missing features

**Solution:**
- Ensure minimum Liquibase 4.32.0 for Flow and policy checks
- Verify in GitHub Actions workflows
- Use exact version in `liquibase/setup-liquibase@v1`

---

### Policy Check Failures

**Problem:** BLOCKER severity check failed

**Solution:**
- Review the policy check documentation in [db/changelog/README.md](../db/changelog/README.md)
- Modify changeset to comply with check
- Common fixes:
  - Add `--rollback` statement
  - Avoid `SELECT *`
  - Don't use `DROP TABLE` in normal changesets
  - Include indexes for new tables

---

## Getting Help

### 1. Check documentation

- [app/TESTING.md](../app/TESTING.md) - Testing troubleshooting
- [CLAUDE.md](../CLAUDE.md) - Common issues and solutions
- [README.md](../README.md) - Architecture and workflows
- [SETUP.md](../SETUP.md) - Complete setup guide

### 2. Use automated checkers

```bash
# General dependency check
./scripts/check-dependencies.sh

# AWS-specific diagnostics
./scripts/diagnose-aws.sh
```

### 3. AI-assisted help (Claude Code users)

- Type `setup` for guided setup assistance
- Describe your issue for troubleshooting help

### 4. Review logs

```bash
# Application logs
docker compose logs app

# Database logs
docker compose logs postgres

# All logs
docker compose logs
```

### 5. Reset environment

```bash
# Stop and remove all containers
docker compose down

# Remove volumes (WARNING: deletes database data)
docker compose down -v

# Rebuild from scratch
docker compose up --build
```

---

For Python package conflicts: Use `pipx` for CLI tools, `uv` for project dependencies.
