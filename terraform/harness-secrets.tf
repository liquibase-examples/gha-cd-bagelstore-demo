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

# AWS Access Key ID
# Used by: AWS connector and pipeline deployment steps
resource "harness_platform_secret_text" "aws_access_key_id" {
  identifier  = "aws_access_key_id"
  name        = "aws-access-key-id"
  description = "AWS Access Key ID for App Runner and RDS deployments"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.aws_access_key_id

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]
}

# AWS Secret Access Key
# Used by: AWS connector and pipeline deployment steps
resource "harness_platform_secret_text" "aws_secret_access_key" {
  identifier  = "aws_secret_access_key"
  name        = "aws-secret-access-key"
  description = "AWS Secret Access Key for App Runner and RDS deployments"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  secret_manager_identifier = "harnessSecretManager"
  value_type                = "Inline"
  value                     = var.aws_secret_access_key

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

# Output secret identifiers for reference
output "harness_secret_identifiers" {
  description = "Harness secret identifiers created"
  value = {
    github_pat            = harness_platform_secret_text.github_pat.identifier
    aws_access_key_id     = harness_platform_secret_text.aws_access_key_id.identifier
    aws_secret_access_key = harness_platform_secret_text.aws_secret_access_key.identifier
    liquibase_license_key = harness_platform_secret_text.liquibase_license_key.identifier
  }
}

# Usage in Pipeline:
# Reference secrets using: <+secrets.getValue('secret_identifier')>
#
# Examples:
# - GitHub PAT: <+secrets.getValue('github_pat')>
# - AWS Key: <+secrets.getValue('aws_access_key_id')>
# - Liquibase: <+secrets.getValue('liquibase_license_key')>
