# Harness Infrastructure Definitions

This directory contains infrastructure definitions for the Bagel Store demo environments.

## Overview

Infrastructure definitions specify **WHERE** to deploy (deployment targets within environments). Each environment has one infrastructure definition that references the Custom deployment template.

**Architecture:**
- **Environment** = Container (like a folder)
- **Infrastructure Definition** = Deployment target (like a file in the folder)

## Files

- `psr_dev_infra.yaml` - Dev environment infrastructure definition
- `psr_test_infra.yaml` - Test environment infrastructure definition
- `psr_staging_infra.yaml` - Staging environment infrastructure definition
- `psr_prod_infra.yaml` - Production environment infrastructure definition

## Structure

Each infrastructure definition:
- References the environment (e.g., `environmentRef: psr_dev`)
- Uses `CustomDeployment` type
- References the Custom deployment template (version 1.0)
- Has empty variables list (environment variables are in the environment itself)
- Disallows simultaneous deployments for safety

## Usage

### Import into Harness (Git Experience)

1. Commit these files to Git
2. In Harness UI, navigate to: **Project Settings** → **Environments** → **psr-dev**
3. Go to **Infrastructure Definitions** tab
4. Click **"+ New Infrastructure Definition"** → **"Remote"**
5. Configure:
   - **Git Connector**: `github_bagel_store`
   - **Repository**: `harness-gha-bagelstore`
   - **Branch**: `main`
   - **File Path**: `.harness/infrastructures/psr_dev_infra.yaml`
6. Click **"Save"**
7. Repeat for test, staging, prod

### Verify Infrastructure Definitions

After importing, verify using the API:

```bash
source harness/.env
for env in psr_dev psr_test psr_staging psr_prod; do
  echo "Checking $env..."
  curl -X GET \
    "https://app.harness.io/gateway/ng/api/infrastructures?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo&environmentIdentifier=$env" \
    -H "x-api-key: ${HARNESS_API_KEY}" | jq '.data.content | length'
done
```

Expected output: `1` for each environment.

## Why Infrastructure Definitions Are Required

From the root cause analysis:

> **`deployToAll: true` does NOT mean "bypass infrastructure definitions"**
> **It means: "deploy to ALL infrastructure definitions in this environment"**

If the environment has zero infrastructure definitions, then `deployToAll: true` has nothing to deploy to, causing the pipeline to abort with:

```
Invalid request: infrastructure definition reference is not specified
```

## CustomDeployment Requirements

CustomDeployment requires:
1. **Deployment Template** (Custom v1.0) - Defines HOW to deploy (in service definition)
2. **Infrastructure Definition** (these files) - Defines WHERE to deploy
3. **Environment** - Container for infrastructure definitions (created via Terraform)
4. **Pipeline Stage** - References environment + infrastructure definitions

## Related Documentation

- **Root Cause Analysis**: `docs/INFRASTRUCTURE_DEFINITION_RESEARCH.md`
- **Harness Manual Setup**: `docs/HARNESS_MANUAL_SETUP.md`
- **Pipeline Documentation**: `harness/pipelines/README.md`
