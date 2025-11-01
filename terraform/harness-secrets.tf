# Harness Secrets Configuration
#
# Creates Harness Platform secrets for use in pipelines and connectors.
# Secrets are stored in Harness's built-in secret manager.
#
# These secrets are referenced in:
# - Connectors (GitHub PAT, AWS credentials)
# - Pipeline steps (database deployment, app deployment)
#
# Security: All variable values are marked sensitive in variables.tf

# GitHub Personal Access Token
# Used by: GitHub connector for repository and package access
resource "harness_platform_secret_text" "github_pat" {
  identifier  = "github_pat"
  name        = "github-pat"
  description = "GitHub Personal Access Token for repository and packages access"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.github_pat

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]
}

# Liquibase License Key
# Used by: Pipeline database update steps
resource "harness_platform_secret_text" "liquibase_license_key" {
  identifier  = "liquibase_license_key"
  name        = "liquibase-license-key"
  description = "Liquibase Secure/Pro license key for database deployments"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.liquibase_license_key

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]
}

# Harness API Key
# Used by: Terraform Harness provider initialization on delegate
resource "harness_platform_secret_text" "harness_api_key" {
  identifier  = "harness_api_key"
  name        = "harness-api-key"
  description = "Harness Platform API key for Terraform provider initialization"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.harness_api_key

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]
}

# Output secret identifiers for reference
output "harness_secret_identifiers" {
  description = "Harness secret identifiers created"
  value = {
    github_pat            = harness_platform_secret_text.github_pat.identifier
    liquibase_license_key = harness_platform_secret_text.liquibase_license_key.identifier
    harness_api_key       = harness_platform_secret_text.harness_api_key.identifier
  }
}

# Usage in Pipeline:
# Reference secrets using: <+secrets.getValue('secret_identifier')>
#
# Examples:
# - GitHub PAT: <+secrets.getValue('github_pat')>
# - Liquibase: <+secrets.getValue('liquibase_license_key')>
