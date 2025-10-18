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

## Diagnostic Approach

**CRITICAL: When encountering errors, follow this approach to avoid wasting time:**

1. **Don't assume error logs = failure** - Services can be fully functional despite error logs
2. **Verify external state FIRST** - Check UI dashboards, API responses, actual service connectivity
3. **Check for environmental issues** - Wrong names, stale locks, timeouts, configuration mismatches
4. **Read project-specific docs** - See "AI Documentation Reference Rules" below
5. **Use diagnostic scripts** - `./scripts/diagnose-*.sh`

**Example That Will Save You 10+ Minutes:**
- ❌ **Wrong:** "Harness delegate logs show errors → delegate is broken → debug token format"
- ✅ **Right:** "Check Harness UI first → delegate shows 'Connected' → errors are non-fatal → focus on actual problem"

**Pattern:** Delegate showing `remote-stackdriver-log-submitter` errors or `DecoderException` in logs while showing "Connected" in Harness UI means it's **working fine** (errors are telemetry/logging issues, not core functionality).

## Script-First Policy (CRITICAL)

**BEFORE making ANY Harness API call or diagnostic query, you MUST check for existing scripts.**

This is the #1 most common mistake: manually constructing curl commands when a working script already exists.

### Discovery Checklist (Execute in Order)

1. **Check scripts directory FIRST:**
   ```bash
   ls -la scripts/*.sh | grep -E "pipeline|execution|trigger|template|harness"
   ```

2. **Read "Available Harness Scripts" section** in this file (below)

3. **Verify working directory:**
   ```bash
   pwd  # Should be /Users/recampbell/workspace/harness-gha-bagelstore
   ```

4. **Try the script:**
   ```bash
   ./scripts/get-pipeline-executions.sh
   # or
   bash scripts/get-pipeline-executions.sh  # If permissions issue
   ```

5. **If script fails, DEBUG before giving up:**
   - Check working directory: `pwd`
   - Check file exists: `ls -la scripts/<script-name>.sh`
   - Check permissions: Should have `x` bit
   - Try explicit bash: `bash scripts/<script-name>.sh`
   - Read script to understand requirements
   - **FIX the issue, don't skip to manual approach**

6. **ONLY use manual curl/API if:**
   - No script exists for this operation
   - Script is confirmed broken and cannot be fixed
   - You document WHY you're not using a script

### Available Harness Scripts (Full Reference)

**Pipeline Monitoring & Debugging:**
- `get-pipeline-executions.sh` - **START HERE** for "what's the latest execution?" queries
- `get-execution-details.sh <exec_id>` - Get detailed execution info and stage status
- `get-stage-logs.sh <exec_id> <stage_name>` - Get logs for specific pipeline stage
- `get-execution-graph.sh <exec_id>` - Get full execution graph with all nodes

**Configuration & Setup:**
- `verify-harness-entities.sh` - Verify all Harness resources exist (templates, pipelines, etc.)
- `update-trigger.sh` - Update trigger configuration (Input Set + Pipeline Branch)
- `get-webhook-url.sh` - Get webhook URL for GitHub Actions trigger
- `get-inputset.sh` - Get input set configuration

**Templates & Git Sync:**
- `get-template.sh <template_name>` - Get template YAML from Harness
- `compare-template-with-git.sh` - Compare Harness template with Git version
- `refresh-template.sh` - Manually sync template from Git
- `force-refresh-template.sh` - Force refresh template (bypass cache)
- `validate-template.sh` - Validate template YAML syntax

**Diagnostics:**
- `check-harness-resources.sh` - Check status of all Harness resources
- `test-git-connector.sh` - Test GitHub connector connectivity
- `test-pipeline-import.sh` - Test pipeline import from Git
- `diagnose-aws.sh` - AWS-specific diagnostic checks

**Local Deployment:**
- `show-deployment-state.sh` - Show current deployment state (all environments)
- `reset-local-environments.sh` - Reset local Docker environments

**AWS/Infrastructure:**
- `create-harness-aws-user.sh` - Create AWS IAM user for Harness delegate
- `check-dependencies.sh` - Verify all required tools installed

### Example - WRONG Approach

```bash
# ❌ WRONG: Immediately jump to manual curl
curl -s "https://app.harness.io/pipeline/api/..." -H "x-api-key: ${HARNESS_API_KEY}"
# Fails with "blank argument" error
# Waste 10 minutes debugging variable scoping
# Never realize ./scripts/get-pipeline-executions.sh exists
```

### Example - CORRECT Approach

```bash
# ✅ CORRECT: Check for script first
ls scripts/*execution*.sh
# Found: get-pipeline-executions.sh, get-execution-details.sh, get-execution-graph.sh

./scripts/get-pipeline-executions.sh
# ✅ Works! Shows formatted table with all executions
# ✅ Shows trigger configuration issues
# ✅ Provides Harness UI link
# ✅ Saved 10 minutes vs manual curl
```

### If Script Fails - Debug First!

```bash
# Script attempt
./scripts/get-pipeline-executions.sh
# Error: "no such file or directory"

# ✅ DEBUG (don't skip this!):
pwd  # Am I in the right directory?
ls -la scripts/get-pipeline-executions.sh  # Does it exist? What permissions?
bash scripts/get-pipeline-executions.sh  # Try explicit bash invocation

# Only after debugging can you determine if script is truly unusable
```

### Why This Matters - Historical Pattern

**What keeps happening:**
1. ❌ Need pipeline execution status
2. ❌ Immediately start writing curl command
3. ❌ Hit "blank argument" error (variable scoping issue)
4. ❌ Try 5+ different curl variations
5. ❌ Waste 10-15 minutes debugging
6. ❌ Never realize `get-pipeline-executions.sh` already exists and works

**What should happen:**
1. ✅ Need pipeline execution status
2. ✅ Check `ls scripts/*execution*.sh`
3. ✅ Find and run `./scripts/get-pipeline-executions.sh`
4. ✅ Get answer in 5 seconds

**Time saved:** 10-15 minutes per query × multiple queries per session = significant productivity gain

## API-First Pattern (CRITICAL)

**ALWAYS use APIs before suggesting manual UI changes** - This is a hard requirement.

### Priority Order for Making Changes

1. **✅ FIRST: Check for API method**
   - Search https://apidocs.harness.io/ for relevant endpoints
   - Look in `scripts/` for existing automation scripts
   - Use Harness API to GET, PUT, POST, DELETE resources

2. **✅ SECOND: Create automation script**
   - If API exists but no script, create one in `scripts/`
   - Document in `scripts/README.md`
   - Make it reusable for future issues

3. **❌ LAST RESORT: Manual UI changes**
   - Only suggest UI changes when:
     - No API endpoint exists
     - API is documented as requiring feature flags
     - One-time setup that won't be repeated

### Harness-Specific API Patterns

**CRITICAL: Parse YAML, not JSON fields**

Many Harness resources (triggers, pipelines, templates) store configuration in `.data.yaml`:

```bash
# ❌ WRONG - JSON fields return null
curl ... | jq '.data.inputSetRefs'  # Returns null

# ✅ CORRECT - Parse YAML field
curl ... | jq -r '.data.yaml' | grep "inputSetRefs:"
```

**Example: Trigger Configuration**
- JSON fields `.data.inputSetRefs` and `.data.pipelineBranchName` return `null`
- Actual config is in `.data.yaml` YAML string
- Must parse YAML to get actual values

**CRITICAL: Reading Environment Variables from .env Files**

**ALWAYS read the .env file FIRST before attempting to use variables from it.**

Common mistake pattern:
```bash
# ❌ WRONG - Blindly source and use variable in one command
source harness/.env && curl ... -H "x-api-key: ${HARNESS_API_KEY}"
# Fails with "blank argument" if sourcing doesn't work as expected
```

Correct approach:
```bash
# ✅ CORRECT - Read file first to verify contents
Read harness/.env  # Verify variable exists and see its value

# Then use the value directly in command
HARNESS_API_KEY="pat.xxxxx.yyyyy.zzzzz"
curl ... -H "x-api-key: ${HARNESS_API_KEY}"
```

Why this matters:
- Verifying file contents first avoids failed command attempts
- You can see if the variable exists and has the correct format
- Authentication tokens are sensitive - empty variables cause cryptic errors
- Saves time by eliminating trial-and-error debugging

**Available Scripts:**
- `scripts/get-pipeline-executions.sh` - Query pipeline runs, includes trigger validation
- `scripts/update-trigger.sh` - Update trigger via API (Input Set + Pipeline Branch)
- `scripts/verify-harness-entities.sh` - Verify all Harness resources exist

**API Endpoint Reference:** See `scripts/README.md` for complete Harness API documentation

### CustomDeployment Infrastructure Pattern

**Quick Summary:**
- This repo uses a minimal CustomDeployment template (`Custom` v1.0) for validation only
- Actual deployment logic lives in Step Group Template (`Coordinated_DB_App_Deployment`)
- Infrastructure definitions reference `Custom` template to satisfy Harness requirements

**Critical Requirements:**
- ❌ **DO NOT** set `templateRef: ""` (empty string) - causes `INVALID_REQUEST` at Infrastructure step
- ✅ **DO** reference the `Custom` v1.0 template
- ⚠️ **CustomDeployment templates CANNOT be stored in Git** - must create manually in Harness UI

**When working with CustomDeployment templates, read:** [docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md](docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md)
- Required fields: `instancename`, `instancesListPath`, `execution`
- Manual creation process
- Complete template structure
- Common errors and solutions

### Why This Matters

**Historical mistakes to avoid:**
1. ❌ Not checking `scripts/` directory before manually constructing API calls
2. ❌ Giving up on scripts after one failure instead of debugging the issue (pwd, permissions, bash invocation)
3. ❌ Telling user to manually fix trigger in UI when `scripts/update-trigger.sh` exists
4. ❌ Parsing `.data.inputSetRefs` JSON field instead of `.data.yaml` YAML field
5. ❌ Not checking https://apidocs.harness.io/ before suggesting manual changes

**Correct workflow:**
1. ✅ Problem: "Trigger needs Input Set configured"
2. ✅ Check: `scripts/update-trigger.sh` exists
3. ✅ Solution: "Run `./scripts/update-trigger.sh`"
4. ✅ Document: Update `scripts/README.md` if new pattern discovered

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

- **Harness pipeline/trigger import issues** → Read [docs/HARNESS_MANUAL_SETUP.md](docs/HARNESS_MANUAL_SETUP.md)
  - Complete step-by-step import process (template, pipeline, input set, trigger)
  - Webhook trigger configuration with Pipeline Reference Branch
  - GitHub variable vs secret setup
  - Common import errors and solutions

- **Harness CustomDeployment templates** → Reference [docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md](docs/HARNESS_CUSTOMDEPLOYMENT_GUIDE.md)
  - When creating/debugging CustomDeployment templates
  - Required fields (`instancename`, `instancesListPath`, `execution`)
  - Why templates cannot be stored in Git (manual creation required)
  - `INVALID_REQUEST` errors at Infrastructure step

- **Harness pipeline monitoring/debugging** → Consult [docs/HARNESS_API_WORKFLOWS.md](docs/HARNESS_API_WORKFLOWS.md)
  - Getting pipeline execution details via API
  - Finding failed steps and error messages
  - Infrastructure definition verification
  - Common error patterns and diagnostics

- **Any errors or issues** → Start with [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
  - Diagnostic scripts, common errors, solutions
  - Harness pipeline import failures (infrastructure YAMLs, deployToAll pattern)
  - Webhook trigger issues (wrong token, QUEUED state)

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

### Why Support Both AWS and Local Deployment Modes?
- **Decision:** Support both AWS (App Runner) and local (Docker Compose) deployment targets
- **Rationale:**
  - AWS mode demonstrates production-like infrastructure and AWS integrations
  - Local mode enables fast iteration, zero cost, and offline demos
  - Same Harness pipeline works for both (conditional logic based on `DEPLOYMENT_TARGET` variable)
  - Users choose based on their needs (demo vs. AWS showcase)
- **Implementation:**
  - Single Harness pipeline with `DEPLOYMENT_TARGET` environment variable
  - Conditional shell scripts in pipeline steps (AWS vs. local logic)
  - Both modes pull same artifacts from ghcr.io (consistent versioning)
  - Version state persists in `.env` file for local mode
- **Trade-offs:**
  - Adds conditional complexity to pipeline YAML
  - Local mode loses AWS-specific features (Secrets Manager, Route53)
  - **Benefit:** Dramatically lowers barrier to entry for demos (2 min setup vs. 30 min)

### Why Hybrid Harness Management (Terraform + Manual)?
- **Decision:** Manage core Harness resources in Terraform, Git-based resources (template, pipeline, trigger) manually
- **Rationale:**
  - **Terraform is EXCELLENT for**: Environments (with AWS outputs), Secrets, Connectors, Service
  - **Terraform is PROBLEMATIC for**: Remote templates/pipelines (require feature flags, timeouts, import issues)
  - Templates and pipelines already in Git anyway (true GitOps)
  - 10 minutes of one-time manual setup vs 2+ days waiting for Harness Support feature flags
- **What's in Terraform (11 resources):**
  - 4 Environments (auto-populated with 14 AWS infrastructure outputs) - **CRITICAL VALUE**
  - 4 Secrets (GitHub PAT, AWS credentials, Liquibase license)
  - 2 Connectors (GitHub, AWS)
  - 1 Service definition
- **What's Manual (3 resources):**
  - 1 Step Group Template (remote, pointing to `harness/templates/deployment-steps.yaml`)
  - 1 Pipeline (remote, pointing to `harness/pipelines/deploy-pipeline.yaml`)
  - 1 Webhook Trigger (maps GitHub Actions to pipeline)
- **Implementation:**
  - Run `terraform apply` for infrastructure + core Harness resources (1 minute)
  - Follow [docs/HARNESS_MANUAL_SETUP.md](docs/HARNESS_MANUAL_SETUP.md) for one-time GitOps setup (10 minutes)
  - All future template/pipeline changes happen via Git commits (pull requests)
- **Trade-offs:**
  - ✅ Eliminates timeout/feature flag issues
  - ✅ True GitOps workflow (changes via Git, not Terraform)
  - ✅ Keeps high-value Terraform resources (AWS → Harness integration)
  - ⚠️ One-time manual setup required
  - ⚠️ Template/pipeline not in Terraform state (but version-controlled in Git)

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

### GitHub Actions Path Filters

**IMPORTANT:** The `main-ci.yml` workflow has path filters and will NOT trigger on empty commits:

```yaml
paths:
  - 'app/**'
  - 'db/changelog/**'
  - 'liquibase-flows/**'
  - '.github/workflows/main-ci.yml'
```

**To trigger the workflow:**

```bash
# Option 1: Rerun last workflow
gh run list --workflow=main-ci.yml --limit 1 --json databaseId --jq '.[0].databaseId'
gh run rerun <run_id>

# Option 2: Touch a file in monitored path
touch app/README.md && git add app/README.md && git commit -m "Test trigger" && git push
```

### Harness API Authentication

**Harness CLI is installed** at `~/bin/harness` (version 0.0.29). However, CLI doesn't support inputset/trigger commands - use API instead.

**HARNESS_API_KEY Location:**
- Stored in `harness/.env` file (gitignored, local only)
- Used for API calls and CLI authentication
- Example: `HARNESS_API_KEY=pat.xxxxx.yyyyy.zzzzz`

**All Harness API calls require authentication:**

```bash
# Load API key from harness/.env
source harness/.env
curl -X GET 'https://app.harness.io/...' -H "x-api-key: ${HARNESS_API_KEY}"
```

**To create an API token:**
1. In Harness UI, click profile icon (top right) → **My Profile**
2. Go to **"My API Keys"** section → **"+ API Key"**
3. Name it (e.g., "debug-api-key") → **"Save"**
4. Click **"+ Token"** → Name it → Set expiration (30 days recommended)
5. Click **"Generate Token"**
6. **IMPORTANT:** Copy token immediately (shown only once!)
7. Add to `harness/.env`: `HARNESS_API_KEY=pat.xxxxx.yyyyy.zzzzz`

**Example API call:**
```bash
source harness/.env
curl -X GET \
  'https://app.harness.io/pipeline/api/inputSets/webhook_default?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&pipelineIdentifier=Deploy_Bagel_Store&branch=main' \
  -H "x-api-key: ${HARNESS_API_KEY}"
```

### Harness Git Experience - Manual Sync Required

**IMPORTANT: No Webhook Configured**

This project uses Harness Git Experience (remote templates, pipelines, infrastructure definitions stored in Git), but **webhook auto-sync is NOT configured** due to GitHub permissions limitations.

**What This Means:**
- Git changes (templates, pipelines, infrastructure definitions) **do NOT auto-sync** to Harness
- After `git push`, you must **manually refresh** entities in Harness UI
- Harness will not detect changes until you trigger a manual sync

**Manual Sync Procedure After Git Push:**

1. **Templates** (e.g., `Custom` deployment template, `Coordinated_DB_App_Deployment` step group):
   - Navigate to: **Project Setup** → **Templates**
   - Click on template name → Click **Refresh** icon (circular arrow)
   - Harness auto-syncs templates from `.harness/orgs/default/projects/bagel_store_demo/templates/`

2. **Infrastructure Definitions** (4 files: `psr_dev_infra`, `psr_test_infra`, `psr_staging_infra`, `psr_prod_infra`):
   - Navigate to: **Environments** → Select environment (e.g., `psr-dev`)
   - Click **Infrastructure Definitions** tab
   - Click infrastructure name → Click **Refresh** icon
   - Or delete and re-import: **+ Infrastructure** → **YAML** → Paste updated YAML

3. **Pipelines**:
   - Navigate to: **Pipelines** → `Deploy_Bagel_Store`
   - Click **Refresh** icon in top right corner

**Verification:**
```bash
# After manual sync, verify changes applied
./scripts/verify-harness-entities.sh

# Check specific infrastructure definition
source harness/.env
curl -s "https://app.harness.io/gateway/ng/api/infrastructures/psr_dev_infra?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=psr_dev" \
  -H "x-api-key: ${HARNESS_API_KEY}" | jq -r '.data.infrastructure.yaml'
```

**Why Webhook Not Configured:**
- Requires GitHub Admin permissions to configure webhooks
- Alternatively: Configure GitHub App integration (also requires admin permissions)

### Harness Delegate
```bash
cd harness
docker compose up -d          # Start delegate
docker compose logs -f        # View logs (ignore Stackdriver/logging errors)
docker compose ps             # Check container status

# IMPORTANT: Verify delegate connectivity in Harness UI (NOT just logs!)
# Harness UI: Project Settings → Delegates → Look for "Connected" + recent heartbeat
# Delegate can show error logs while being fully functional

docker compose down           # Stop delegate
```

### Local Deployment Mode (NEW)
```bash
# Start all 4 environments
docker compose -f docker-compose-demo.yml up -d

# View deployment state
./scripts/show-deployment-state.sh

# Deploy specific version to dev (manual)
sed -i.bak 's/^VERSION_DEV=.*/VERSION_DEV=v1.1.0/' .env && rm -f .env.bak
docker compose -f docker-compose-demo.yml pull app-dev
docker compose -f docker-compose-demo.yml up -d --no-deps app-dev

# View logs
docker compose -f docker-compose-demo.yml logs -f app-dev
docker compose -f docker-compose-demo.yml logs -f postgres-dev

# Reset all to latest
./scripts/reset-local-environments.sh latest

# Stop all
docker compose -f docker-compose-demo.yml down
```

See [docs/COMMANDS.md](docs/COMMANDS.md) and [docs/LOCAL_DEPLOYMENT.md](docs/LOCAL_DEPLOYMENT.md) for complete reference.

## Common Gotchas

### Harness Delegate: Error Logs ≠ Failure

**CRITICAL PATTERN TO RECOGNIZE:**

1. **Delegate showing errors but actually working**:
   - Error pattern: `DecoderException: Illegal hexadecimal character p` from `remote-stackdriver-log-submitter`
   - Error pattern: `Failed to initialize token generator`
   - Error pattern: `EncryptDecryptException` in logging/telemetry threads
   - **These are non-fatal** - Stackdriver logging errors are cosmetic
   - Delegate can be **fully functional** with these errors in logs

2. **How to verify actual delegate status**:
   - ✅ **Correct:** Check Harness UI → Project Settings → Delegates
   - Look for: "Connected" status + recent heartbeat (< 1 min)
   - ❌ **Wrong:** Assume delegate is broken because of error logs
   - ❌ **Wrong:** Spend time debugging token format/encoding

3. **Root cause of these errors**:
   - Telemetry/logging system issues (remote-stackdriver-log-submitter thread)
   - Does NOT affect core delegate functionality
   - Delegate can communicate with Harness Manager perfectly fine

### Terraform + Harness Integration

1. **Repository renames impact Terraform**:
   - Harness terraform provider fetches templates from GitHub
   - If repo renamed, update `terraform.tfvars` (local, gitignored file)
   - Change `github_repo` variable to match new repo name
   - Terraform will **timeout** trying to fetch from old repo name
   - Remember: `terraform.tfvars` is NOT committed (contains secrets)

2. **Stale terraform locks after timeouts**:
   - Timeouts (especially with Harness provider) leave lock files
   - Location: `terraform/.terraform.tfstate.lock.info`
   - Check lock: `cat terraform/.terraform.tfstate.lock.info`
   - Safe to remove if no terraform process running: `rm terraform/.terraform.tfstate.lock.info`
   - Or use: `terraform force-unlock <LOCK_ID>`

3. **Debugging Harness resources in terraform**:
   ```bash
   # Check what Harness resources exist in state
   cd terraform
   terraform show -json | jq -r '.values.root_module.resources[] | select(.provider_name == "registry.terraform.io/harness/harness") | "\(.type): \(.values.name // .values.identifier)"'

   # Verify delegate can connect before terraform apply
   # Check Harness UI first!
   ```

### After GitHub Repository Rename

**Checklist when renaming the GitHub repository:**

1. Update `terraform/terraform.tfvars` - Change `github_repo` variable (NOT committed)
2. Verify `github_org` if organization changed
3. Clear any stale terraform locks: `rm terraform/.terraform.tfstate.lock.info`
4. Run `terraform apply` to update Harness resources (remote templates, triggers)
5. Check GitHub Actions workflows for hardcoded repo references
6. Update any local documentation or scripts with repo name

### Harness Pipeline Import Requirements

**CRITICAL PATTERN TO RECOGNIZE:**

1. **Infrastructure definition YAMLs are REQUIRED in two places**:
   - ✅ Terraform resources (for runtime execution)
   - ✅ YAML files in `.harness/orgs/.../envs/.../infras/` (for import validation)
   - ❌ **Having only Terraform is NOT sufficient**
   - Previous AI sessions have incorrectly deleted these YAMLs thinking Terraform alone was enough

2. **Check before making changes**:
   ```bash
   # Verify all 4 infrastructure YAML files exist
   find .harness -name "*infra*.yaml"

   # Run diagnostic to verify all pipeline dependencies
   ./scripts/verify-harness-entities.sh
   ```

3. **Pipeline YAML validation vs runtime behavior**:
   - ❌ `deployToAll: true` - Works at runtime, FAILS import validation
   - ✅ Explicit infrastructure references - Works everywhere:
     ```yaml
     environment:
       environmentRef: psr_dev
       infrastructureDefinitions:
         - identifier: psr_dev_infra
     ```

4. **Webhook trigger setup**:
   - Created manually in Harness UI (not Terraform, to avoid feature flag requirements)
   - Uses Input Set: `webhook_default` (maps webhook payload to pipeline variables)
   - **CRITICAL:** Pipeline Reference Branch: `<+trigger.branch>` (required for Git Experience)
     - Without this, trigger stays QUEUED forever
   - Webhook URL goes in GitHub **VARIABLE** (not secret!): `HARNESS_WEBHOOK_URL`
   - Workflow references: `vars.HARNESS_WEBHOOK_URL`

5. **Common webhook errors**:
   - `No custom trigger found` → Wrong webhook URL in GitHub variable
   - Trigger stays QUEUED → Missing Pipeline Reference Branch setting
   - Secret vs Variable → Workflow uses `vars.` prefix, requires VARIABLE not SECRET

6. **Diagnostic workflow**:
   ```bash
   # Before import attempts
   ./scripts/verify-harness-entities.sh

   # Get webhook URL
   ./scripts/get-webhook-url.sh

   # Update GitHub variable (NOT secret)
   gh variable set HARNESS_WEBHOOK_URL --body "URL_HERE"
   ```

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
- **[docs/LOCAL_DEPLOYMENT.md](docs/LOCAL_DEPLOYMENT.md)** - Local deployment mode (Docker Compose)
- **[docs/WORKFLOWS.md](docs/WORKFLOWS.md)** - GitHub Actions workflows
- **[docs/COMMANDS.md](docs/COMMANDS.md)** - Complete command reference
- **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** - Diagnostic scripts and solutions

### Flow Files
- **[liquibase-flows/README.md](liquibase-flows/README.md)** - Flow file documentation

### Harness CD
- **[harness/README.md](harness/README.md)** - Delegate setup, connectors, secrets
- **[harness/pipelines/README.md](harness/pipelines/README.md)** - Pipeline architecture and execution
- **[docs/HARNESS_MANUAL_SETUP.md](docs/HARNESS_MANUAL_SETUP.md)** - Manual setup for template, pipeline, and trigger (one-time, 10 min)

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
