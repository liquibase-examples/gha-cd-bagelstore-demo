# AI Handoff Document - Harness CD Terraform Automation

## Current State

The Harness CD integration is **partially automated** via Terraform. Environments are created automatically, but connectors, secrets, services, and pipeline import still require manual setup.

## What's Already Done

### ✅ Terraform - Harness Environments (Complete)
- **File:** `terraform/harness-provider.tf` - Harness Terraform Provider configuration
- **File:** `terraform/harness-environments.tf` - Creates 4 environments (dev, test, staging, prod)
- **Each environment has 14 variables:**
  - Database: `rds_endpoint`, `rds_address`, `rds_port`, `database_name`, `jdbc_url`
  - App Runner: `app_runner_service_arn`, `app_runner_service_url`, `app_runner_service_id`, `app_runner_service_name`
  - S3: `liquibase_flows_bucket`, `operation_reports_bucket`
  - Config: `demo_id`, `aws_region`, `environment`, `dns_record`

### ✅ Pipeline Configuration (Complete)
- **File:** `harness/pipelines/deploy-pipeline.yaml` - 4-stage deployment pipeline
- Pipeline uses environment variables: `<+env.variables.variable_name>`
- Stored in Git as Remote pipeline

### ✅ Delegate Configuration (Complete)
- **File:** `harness/docker-compose.yml` - Delegate runs locally via Docker Compose
- **File:** `harness/.env` - Delegate credentials configured (gitignored)
- Delegate is currently downloading/starting

### ✅ Documentation (Complete)
- `terraform/README.md` - Documents Harness Terraform Provider integration
- `harness/README.md` - Setup instructions (manual process)
- `harness/pipelines/README.md` - Pipeline documentation

## What Needs to Be Done

### Task: Complete Terraform Automation for Harness CD

**Goal:** Eliminate all manual setup steps by creating Terraform resources for connectors, secrets, service, and pipeline.

### Required Terraform Resources

#### 1. GitHub Connector
Create `terraform/harness-connectors.tf` with:

```hcl
# GitHub Connector for accessing changelog artifacts
resource "harness_platform_connector_github" "github_bagel_store" {
  identifier  = "github_bagel_store"
  name        = "github-bagel-store"
  description = "GitHub connector for Bagel Store changelog artifacts"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  url                = "https://github.com/${var.github_org}/harness-gha-bagelstore"
  connection_type    = "Repo"
  validation_repo    = "harness-gha-bagelstore"
  delegate_selectors = ["${var.demo_id}"]

  credentials {
    http {
      username  = var.github_username
      token_ref = harness_platform_secret_text.github_pat.id
    }
  }

  api_authentication {
    token_ref = harness_platform_secret_text.github_pat.id
  }
}
```

#### 2. AWS Connector
```hcl
# AWS Connector for App Runner deployments
resource "harness_platform_connector_aws" "aws_bagel_store" {
  identifier  = "aws_bagel_store"
  name        = "aws-bagel-store"
  description = "AWS connector for App Runner and RDS access"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  manual {
    delegate_selectors = ["${var.demo_id}"]
  }

  cross_account_access {
    role_arn    = var.aws_role_arn  # Optional: Use IAM role instead of keys
    external_id = var.demo_id
  }

  # OR use access keys:
  # credentials {
  #   type = "ManualConfig"
  #   access_key     = harness_platform_secret_text.aws_access_key_id.id
  #   secret_key_ref = harness_platform_secret_text.aws_secret_access_key.id
  # }
}
```

#### 3. Secrets
Create `terraform/harness-secrets.tf`:

```hcl
# GitHub Personal Access Token
resource "harness_platform_secret_text" "github_pat" {
  identifier  = "github_pat"
  name        = "github-pat"
  description = "GitHub Personal Access Token for packages access"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.github_pat
}

# AWS Access Key ID
resource "harness_platform_secret_text" "aws_access_key_id" {
  identifier  = "aws_access_key_id"
  name        = "aws-access-key-id"
  description = "AWS Access Key ID for deployments"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.aws_access_key_id
}

# AWS Secret Access Key
resource "harness_platform_secret_text" "aws_secret_access_key" {
  identifier  = "aws_secret_access_key"
  name        = "aws-secret-access-key"
  description = "AWS Secret Access Key for deployments"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.aws_secret_access_key
}

# Liquibase License Key
resource "harness_platform_secret_text" "liquibase_license_key" {
  identifier  = "liquibase_license_key"
  name        = "liquibase-license-key"
  description = "Liquibase Secure/Pro license key"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.liquibase_license_key
}
```

#### 4. Service Definition
Create `terraform/harness-service.tf`:

```hcl
# Bagel Store Service
resource "harness_platform_service" "bagel_store" {
  identifier  = "bagel_store"
  name        = "Bagel Store"
  description = "Flask application with PostgreSQL database"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  yaml = <<-EOT
    service:
      name: Bagel Store
      identifier: bagel_store
      serviceDefinition:
        type: CustomDeployment
        spec:
          customDeploymentRef:
            templateRef: Custom
            versionLabel: "1.0"
      gitOpsEnabled: false
  EOT
}
```

#### 5. Pipeline (Git Sync)
Create `terraform/harness-pipeline.tf`:

```hcl
# Pipeline stored in Git (Remote Pipeline)
resource "harness_platform_pipeline" "deploy_bagel_store" {
  identifier = "Deploy_Bagel_Store"
  name       = "Deploy Bagel Store - ${var.demo_id}"
  org_id     = var.harness_org_id
  project_id = var.harness_project_id

  git_details {
    branch_name    = "main"
    file_path      = "harness/pipelines/deploy-pipeline.yaml"
    connector_ref  = harness_platform_connector_github.github_bagel_store.id
    repo_name      = "harness-gha-bagelstore"
    store_type     = "REMOTE"
  }

  tags = {
    demo_id = var.demo_id
  }
}
```

#### 6. Add New Variables
Update `terraform/variables.tf` to add:

```hcl
# GitHub Configuration (already exists, but add username)
variable "github_username" {
  description = "GitHub username for connector authentication"
  type        = string
  default     = ""
}

# AWS Configuration for Harness (already exists via aws_access_key_id in secrets)
# No new variables needed if using existing AWS credentials

# Liquibase Configuration
variable "liquibase_license_key" {
  description = "Liquibase Secure/Pro license key"
  type        = string
  sensitive   = true
  default     = ""
}
```

Update `terraform/terraform.tfvars.example`:

```hcl
# Add to existing file:

# ===== Liquibase Configuration =====
liquibase_license_key = "your-liquibase-license-key-here"
```

### Implementation Notes

1. **Secret Management:**
   - Use `harnessSecretManager` (Harness built-in secret manager)
   - Set `value_type = "Inline"` for Terraform-managed secrets
   - Ensure secrets are marked `sensitive = true` in variables

2. **Connector Validation:**
   - GitHub connector should validate against the repository
   - AWS connector uses delegate selectors: `["${var.demo_id}"]`
   - Test connections after apply

3. **Dependencies:**
   - Pipeline depends on: service, connectors
   - Connectors depend on: secrets
   - Use `depends_on` if needed

4. **Remote Pipeline:**
   - Pipeline YAML stays in Git (`harness/pipelines/deploy-pipeline.yaml`)
   - Terraform just imports/registers it in Harness
   - Changes to pipeline YAML don't require `terraform apply`

### Testing the Implementation

After creating the Terraform resources:

```bash
cd terraform
terraform plan
terraform apply
```

**Verify in Harness UI:**
1. **Connectors:** Project Settings → Connectors (should see 2)
2. **Secrets:** Project Settings → Secrets (should see 4)
3. **Service:** Services (should see "Bagel Store")
4. **Pipeline:** Pipelines (should see "Deploy Bagel Store - demo1")
5. **Environments:** Environments (should see 4: dev, test, staging, prod)

### Success Criteria

- [ ] All Terraform resources create successfully
- [ ] Connectors show "Connected" status in Harness UI
- [ ] Secrets are accessible in Harness UI
- [ ] Service appears in Services list
- [ ] Pipeline imports from Git successfully
- [ ] Pipeline can be executed with only 2 runtime inputs: VERSION, GITHUB_ORG
- [ ] No manual setup required after `terraform apply`

### Documentation to Update

After implementation:
1. Update `terraform/README.md` - Add sections for connectors, secrets, service, pipeline
2. Update `harness/README.md` - Change "Manual Setup" to "Automatic Setup via Terraform"
3. Update `harness/pipelines/README.md` - Note that prerequisites are automated

### Reference Documentation

- **Harness Terraform Provider:** https://registry.terraform.io/providers/harness/harness/latest/docs
- **GitHub Connector:** https://registry.terraform.io/providers/harness/harness/latest/docs/resources/platform_connector_github
- **AWS Connector:** https://registry.terraform.io/providers/harness/harness/latest/docs/resources/platform_connector_aws
- **Secret Text:** https://registry.terraform.io/providers/harness/harness/latest/docs/resources/platform_secret_text
- **Service:** https://registry.terraform.io/providers/harness/harness/latest/docs/resources/platform_service
- **Pipeline:** https://registry.terraform.io/providers/harness/harness/latest/docs/resources/platform_pipeline

### Current Git Branch

Branch: `main`
Last commit: "Implement Harness Terraform Provider integration for zero-config deployments"

### Environment Context

- **Harness Account ID:** Set in `harness/.env` file (gitignored)
- **Harness Delegate Token:** Set in `harness/.env` file (gitignored)
- **Delegate:** Currently downloading via `docker compose up -d` in `harness/` directory
- **AWS Profile:** `liquibase-csteam-operator` (configured)
- **Demo ID:** `demo1`

## Questions for Clarification

1. **GitHub Username:** What GitHub username should be used for the connector? (User's GitHub username for authentication)

2. **AWS Authentication Method:** Prefer IAM role or access keys?
   - IAM Role: More secure, requires AWS role ARN
   - Access Keys: Simpler, uses existing AWS credentials

3. **Liquibase License:** Does user have a Liquibase Pro/Secure license key to add to secrets?

4. **Delegate Selector:** Should remain `demo_id` for multi-instance support?

## Additional Context

### Project Structure
```
harness-gha-bagelstore/
├── app/                     # Flask application
├── db/changelog/            # Liquibase changesets
├── terraform/               # Terraform configuration
│   ├── harness-provider.tf          # ✅ EXISTS
│   ├── harness-environments.tf      # ✅ EXISTS
│   ├── harness-connectors.tf        # ❌ TO CREATE
│   ├── harness-secrets.tf           # ❌ TO CREATE
│   ├── harness-service.tf           # ❌ TO CREATE
│   ├── harness-pipeline.tf          # ❌ TO CREATE
│   ├── variables.tf                 # ⚠️  TO UPDATE
│   └── terraform.tfvars.example     # ⚠️  TO UPDATE
├── harness/                 # Harness CD configuration
│   ├── docker-compose.yml   # Delegate configuration
│   ├── .env                 # Delegate credentials (gitignored)
│   └── pipelines/
│       └── deploy-pipeline.yaml    # Pipeline YAML (in Git)
└── .github/workflows/       # GitHub Actions CI/CD
```

### Key Design Decisions

1. **Environment Variables Pattern:** Pipeline uses `<+env.variables.*>` for infrastructure details
2. **Security Model:** DB credentials in AWS Secrets Manager, accessed via `${awsSecretsManager:path}`
3. **Multi-Instance:** All resources tagged with `demo_id` for concurrent demos
4. **Remote Pipeline:** Pipeline YAML in Git, registered via Terraform
5. **Delegate:** Runs locally, not managed by Terraform

### Important Files to Reference

- `terraform/harness-environments.tf` - Pattern for creating Harness resources
- `terraform/harness-provider.tf` - Provider configuration
- `harness/pipelines/deploy-pipeline.yaml` - Pipeline that needs to reference connectors/secrets
- `harness/README.md` - Current manual setup instructions to automate

## Summary

**Current state:** Harness environments are automated via Terraform, but connectors, secrets, service, and pipeline registration require manual setup.

**Goal:** Create 4 new Terraform files (`harness-connectors.tf`, `harness-secrets.tf`, `harness-service.tf`, `harness-pipeline.tf`) to fully automate Harness CD setup.

**Result:** Single `terraform apply` creates complete Harness CD setup with no manual steps required.
