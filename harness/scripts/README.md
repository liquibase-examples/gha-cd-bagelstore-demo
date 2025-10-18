# Harness Deployment Scripts

This directory contains executable scripts used by Harness deployment pipelines. These scripts are mounted into the delegate container at `/opt/harness-delegate/scripts/` for execution during deployments.

## Architecture

**Problem:** Inline YAML scripts in Harness templates require manual UI refresh after every change, slowing iteration.

**Solution:** External scripts in Git, bind mounted to delegate, called from template YAML.

**Benefits:**
- ✅ Fast iteration - Edit, commit, push (no UI refresh needed!)
- ✅ Version controlled - Full Git workflow
- ✅ Testable locally - Can test scripts before deploying
- ✅ Separation of concerns - Orchestration (YAML) vs Implementation (bash)

## Scripts

### 1. `fetch-changelog-artifact.sh`
Downloads changelog artifact from GitHub Actions artifact storage.

**Usage:**
```bash
fetch-changelog-artifact.sh <VERSION> <GITHUB_ORG> <GITHUB_PAT>
```

**Arguments:**
- `VERSION` - Git tag/version (e.g., v1.0.0)
- `GITHUB_ORG` - GitHub organization name
- `GITHUB_PAT` - GitHub Personal Access Token

**Output:**
- Extracts changelog to `/tmp/changelog/`
- Prints file listing for verification

**Example:**
```bash
/opt/harness-delegate/scripts/fetch-changelog-artifact.sh \
  "v1.0.0" \
  "liquibase-examples" \
  "ghp_xxxxx"
```

---

### 2. `update-database.sh`
Runs Liquibase update against target database.

**Usage:**
```bash
update-database.sh <ENVIRONMENT> <DEMO_ID> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
```

**Arguments:**
- `ENVIRONMENT` - Target environment (dev/test/staging/prod)
- `DEMO_ID` - Demo instance identifier
- `DEPLOYMENT_TARGET` - Deployment mode: "aws" or "local"
- `AWS_PARAMS_JSON` - JSON with AWS parameters (for AWS mode)
- `SECRETS_JSON` - JSON with secret references

**AWS Mode:**
- Uses S3 flow files with policy checks
- Connects to RDS PostgreSQL
- Uses AWS Secrets Manager for credentials

**Local Mode:**
- Direct Liquibase update (no flow files)
- Connects to Docker Compose postgres container
- Uses hardcoded postgres/postgres credentials

**Example (AWS):**
```bash
/opt/harness-delegate/scripts/update-database.sh \
  "dev" \
  "demo1" \
  "aws" \
  '{"jdbc_url":"jdbc:postgresql://...","aws_region":"us-east-1","liquibase_flows_bucket":"...","rds_endpoint":"..."}' \
  '{"aws_access_key_id":"...","aws_secret_access_key":"...","liquibase_license_key":"...","db_username":"...","db_password":"..."}'
```

---

### 3. `deploy-application.sh`
Deploys application to AWS App Runner or Docker Compose.

**Usage:**
```bash
deploy-application.sh <ENVIRONMENT> <VERSION> <GITHUB_ORG> <DEPLOYMENT_TARGET> <AWS_PARAMS_JSON> <SECRETS_JSON>
```

**Arguments:**
- `ENVIRONMENT` - Target environment (dev/test/staging/prod)
- `VERSION` - Version to deploy (e.g., v1.0.0)
- `GITHUB_ORG` - GitHub organization name
- `DEPLOYMENT_TARGET` - Deployment mode: "aws" or "local"
- `AWS_PARAMS_JSON` - JSON with AWS parameters
- `SECRETS_JSON` - JSON with secret references

**AWS Mode:**
- Updates App Runner service with new Docker image
- Pulls from ghcr.io
- Sets environment variables including Secrets Manager refs

**Local Mode:**
- Updates `.env` file with new version
- Pulls Docker image from ghcr.io
- Restarts specific Docker Compose service

**Example (Local):**
```bash
/opt/harness-delegate/scripts/deploy-application.sh \
  "dev" \
  "v1.0.0" \
  "liquibase-examples" \
  "local" \
  '{}' \
  '{}'
```

---

### 4. `health-check.sh`
Verifies deployed application is healthy and running correct version.

**Usage:**
```bash
health-check.sh <ENVIRONMENT> <VERSION> <DEPLOYMENT_TARGET> <SERVICE_URL>
```

**Arguments:**
- `ENVIRONMENT` - Target environment
- `VERSION` - Expected version
- `DEPLOYMENT_TARGET` - Deployment mode: "aws" or "local"
- `SERVICE_URL` - Service URL (for AWS mode, empty for local)

**Behavior:**
- Waits up to 5 minutes for service to respond
- Checks `/health` endpoint returns HTTP 200
- Verifies `/version` endpoint returns expected version
- Retries every 10 seconds

**Example:**
```bash
/opt/harness-delegate/scripts/health-check.sh \
  "dev" \
  "v1.0.0" \
  "aws" \
  "myapp.us-east-1.awsapprunner.com"
```

---

### 5. `fetch-instances.sh`
Reports instance information to Harness for deployment tracking.

**Usage:**
```bash
fetch-instances.sh <ENVIRONMENT> <DEPLOYMENT_TARGET> <SERVICE_NAME> <SERVICE_URL>
```

**Arguments:**
- `ENVIRONMENT` - Target environment
- `DEPLOYMENT_TARGET` - Deployment mode
- `SERVICE_NAME` - Service name (for AWS)
- `SERVICE_URL` - Service URL (for AWS)

**Output:**
- JSON in Harness format
- AWS mode: `{"instances": [{"instanceName": "...", "instanceUrl": "..."}]}`
- Local mode: `{"instances": [{"instanceName": "...", "instanceId": "..."}]}`

**Example:**
```bash
/opt/harness-delegate/scripts/fetch-instances.sh \
  "dev" \
  "aws" \
  "demo1-bagel-dev" \
  "myapp.us-east-1.awsapprunner.com"
```

---

## Local Testing

Scripts can be tested locally before deploying:

```bash
# Test fetch-changelog-artifact.sh
cd harness/scripts
./fetch-changelog-artifact.sh "v1.0.0" "liquibase-examples" "$GITHUB_PAT"

# Test health-check.sh
./health-check.sh "dev" "v1.0.0" "local" ""

# Test fetch-instances.sh
./fetch-instances.sh "dev" "local" "app-dev" ""
```

## Delegate Mount Configuration

Scripts are mounted in `harness/docker-compose.yml`:

```yaml
volumes:
  - ./scripts:/opt/harness-delegate/scripts:ro
```

**After adding new scripts:**
1. Restart delegate: `docker compose restart harness-delegate`
2. Verify mount: `docker exec harness-delegate-demo1 ls /opt/harness-delegate/scripts`

## Template Integration

In `.harness/.../Coordinated_DB_App_Deployment/v1_0.yaml`:

```yaml
- step:
    type: ShellScript
    name: Fetch Changelog Artifact
    spec:
      script: |-
        /opt/harness-delegate/scripts/fetch-changelog-artifact.sh \
          "<+pipeline.variables.VERSION>" \
          "<+pipeline.variables.GITHUB_ORG>" \
          "<+secrets.getValue('github_pat')>"
```

## Development Workflow

### Iteration Workflow (Fast!)
1. Edit script: `vim harness/scripts/fetch-changelog-artifact.sh`
2. Test locally: `./harness/scripts/fetch-changelog-artifact.sh ...`
3. Commit: `git commit -m "Fix artifact download"`
4. Push: `git push`
5. Trigger: `gh workflow run main-ci.yml`
6. ✅ **Changes take effect immediately** - No Harness UI interaction!

### When to Refresh Template
**Only refresh template in Harness UI when:**
- Changing template YAML structure (adding/removing steps)
- Changing step order or dependencies
- Changing script arguments or variable names

**Do NOT refresh template for:**
- Script logic changes (bug fixes, improvements)
- Logging additions
- Error handling improvements
- JSON parameter changes

## Debugging

**View script output in Harness:**
1. Go to execution view
2. Click on step (e.g., "Fetch Changelog Artifact")
3. View logs - script stdout/stderr appears

**Test scripts on delegate:**
```bash
# Exec into delegate container
docker exec -it harness-delegate-demo1 bash

# Check scripts are mounted
ls -la /opt/harness-delegate/scripts/

# Run script manually
/opt/harness-delegate/scripts/fetch-changelog-artifact.sh "v1.0.0" "liquibase-examples" "token"
```

## Error Codes

All scripts follow consistent exit code pattern:
- `0` - Success
- `1` - Failure (with descriptive error message)

Scripts use `set -e` to fail fast on any command error.

## Best Practices

1. **Always validate arguments** - Scripts check argument count and print usage
2. **Use explicit variables** - Don't rely on global env vars from delegate
3. **Log progress clearly** - Echo key steps for debugging
4. **Fail fast** - Use `set -e` and explicit exit codes
5. **Test locally first** - Verify script works before committing
6. **Keep scripts focused** - One script = one responsibility
7. **Document arguments** - Update README when adding parameters
