# Harness Step Group Templates

This directory contains reusable Harness step group templates for the Bagel Store deployment pipeline.

## Overview

Templates eliminate duplication by defining common deployment steps once and reusing them across multiple pipeline stages.

## Available Templates

### Coordinated DB and App Deployment

**File:** `deployment-steps.yaml`
**Identifier:** `Coordinated_DB_App_Deployment`
**Current Version:** `v1.0`

**Purpose:** Performs coordinated database and application deployment across all environments (dev, test, staging, prod).

**Steps:**
1. **Fetch Changelog Artifact** - Downloads changelog from GitHub Packages
2. **Update Database** - Runs Liquibase update via Docker container
3. **Deploy Application** - Updates App Runner (AWS) or Docker Compose (Local)
4. **Health Check** - Verifies deployment with version validation

**Deployment Modes:**
- **AWS Mode** (default): Uses RDS + App Runner with S3 flow files
- **Local Mode**: Uses Docker Compose with local PostgreSQL containers

Controlled by `DEPLOYMENT_TARGET` environment variable (`aws` or `local`).

**Environment Variables Used:**

From Harness Environment (stage-specific):
- `environment` - Target environment name (dev/test/staging/prod)
- `demo_id` - Demo instance identifier
- `jdbc_url` - Complete JDBC connection URL
- `rds_address` - RDS endpoint address
- `rds_port` - RDS port number
- `database_name` - Database name
- `app_runner_service_arn` - App Runner service ARN
- `app_runner_service_url` - App Runner service URL
- `liquibase_flows_bucket` - S3 bucket for Liquibase flow files
- `aws_region` - AWS region

From Pipeline:
- `VERSION` - Git tag version to deploy (e.g., v1.0.0)
- `GITHUB_ORG` - GitHub organization name

From Harness Secrets:
- `github_pat` - GitHub Personal Access Token (for Packages)
- `aws_access_key_id` - AWS Access Key
- `aws_secret_access_key` - AWS Secret Key
- `liquibase_license_key` - Liquibase Pro/Secure license

## Usage in Pipelines

Reference the template in a pipeline stage:

```yaml
execution:
  steps:
    - stepGroup:
        name: Coordinated DB and App Deployment
        identifier: Coordinated_Deployment
        template:
          templateRef: Coordinated_DB_App_Deployment
          versionLabel: v1.0
```

**Automatic context resolution:** The template inherits environment variables from the stage's environment configuration, so no additional inputs are needed.

## Modifying Templates

### To Update Deployment Logic:

1. **Edit the template file** (`deployment-steps.yaml`)
2. **Test changes** in a non-production environment first
3. **Update version label** (increment to v1.1, v1.2, etc.)
4. **Update pipeline references** or use "Always use stable version"
5. **Commit and push** to Git repository

### Versioning Strategy:

- **Major version (v2.0)** - Breaking changes or significant refactoring
- **Minor version (v1.1)** - New features or non-breaking changes
- **Patch version (v1.0.1)** - Bug fixes (if needed)

### Example Modifications:

**Add smoke tests after health check:**
```yaml
- step:
    type: ShellScript
    name: Smoke Tests
    identifier: Smoke_Tests
    spec:
      script: |
        curl -f https://service/api/smoke-test
        # Add more smoke tests...
```

**Change health check timeout:**
```yaml
- step:
    type: ShellScript
    name: Health Check
    identifier: Health_Check
    timeout: 15m  # Changed from 10m
```

**Add Slack notification:**
```yaml
- step:
    type: ShellScript
    name: Notify Success
    identifier: Notify_Success
    spec:
      script: |
        curl -X POST $SLACK_WEBHOOK_URL \
          -H 'Content-Type: application/json' \
          -d '{"text":"Deployed <+pipeline.variables.VERSION> to <+env.variables.environment>"}'
```

## Template Structure

```yaml
template:
  name: <Template Name>
  identifier: <Template_Identifier>
  versionLabel: <version>
  type: StepGroup
  projectIdentifier: <project>
  orgIdentifier: <org>
  tags: {}
  description: <description>

  spec:
    steps:
      - step:
          type: ShellScript
          name: <Step Name>
          identifier: <step_id>
          spec:
            shell: Bash
            source:
              type: Inline
              spec:
                script: |
                  #!/bin/bash
                  # Script content
          timeout: 10m

    stageType: Deployment
```

## Benefits of Templates

✅ **Code Reuse** - Write once, use in multiple stages
✅ **Consistency** - Same deployment logic across all environments
✅ **Maintainability** - Update in one place, affects all usages
✅ **Version Control** - Track changes and roll back if needed
✅ **Testing** - Test template changes independently
✅ **Documentation** - Single source of truth for deployment process

## Troubleshooting

### Template Not Found Error

**Error:** `Template with identifier 'Coordinated_DB_App_Deployment' not found`

**Solutions:**
1. Verify template is registered in Harness (check Project Settings → Templates)
2. Confirm template scope matches pipeline scope (Project/Org/Account)
3. Check Git sync status if using remote templates
4. Verify `projectIdentifier` and `orgIdentifier` match pipeline

### Variable Resolution Issues

**Error:** `Could not resolve expression <+env.variables.environment>`

**Solutions:**
1. Verify environment is properly configured in stage
2. Check environment variables are set in Terraform outputs
3. Confirm environment reference matches: `environmentRef: dev`
4. Test variable resolution in Harness UI (Input Sets)

### Docker Network Issues (Local Mode)

**Error:** `Could not connect to postgres-dev container`

**Solutions:**
1. Ensure Docker Compose network exists: `docker network ls`
2. Verify container names match: `docker ps`
3. Check network name in template: `harness-gha-bagelstore_bagel-network`
4. Restart Docker Compose services if needed

## Additional Resources

- [Harness Step Group Templates Documentation](https://developer.harness.io/docs/platform/templates/create-a-stepgroup-template/)
- [Harness Template Variables](https://developer.harness.io/docs/platform/templates/template/)
- [Pipeline README](../pipelines/README.md) - Complete pipeline documentation
- [Harness README](../README.md) - Harness setup and delegate configuration
