# Harness Step Group Template Configuration
#
# Registers a Remote Step Group Template stored in Git with Harness.
# The template YAML lives in: harness/templates/deployment-steps.yaml
#
# Remote Template Benefits:
# - Version control for template changes
# - Code review via Pull Requests
# - GitOps workflow
# - Single source of truth
# - Reusable across multiple pipelines
#
# Terraform only registers/imports the template - the YAML stays in Git.
# Changes to the template YAML don't require terraform apply.

resource "harness_platform_template" "deployment_steps" {
  identifier = "Coordinated_DB_App_Deployment"
  name       = "Coordinated DB and App Deployment"
  version    = "v1.0"
  is_stable  = true
  org_id     = var.harness_org_id
  project_id = var.harness_project_id

  # Remote template configuration - YAML stored in Git
  # Template type (StepGroup) and description are defined in the YAML file itself
  git_details {
    branch_name   = "main"
    file_path     = "harness/templates/deployment-steps.yaml"
    connector_ref = harness_platform_connector_github.github_bagel_store.identifier
    repo_name     = var.github_repo
    store_type    = "REMOTE"
  }

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform",
    "template_type:step_group",
    "purpose:deployment"
  ]

  # Template depends on GitHub connector being available
  depends_on = [
    harness_platform_connector_github.github_bagel_store
  ]
}

# Output template identifier for reference
output "harness_template_identifier" {
  description = "Harness step group template identifier created"
  value       = harness_platform_template.deployment_steps.identifier
}

output "harness_template_version" {
  description = "Harness step group template version"
  value       = harness_platform_template.deployment_steps.version
}

output "harness_template_url" {
  description = "Harness template URL"
  value       = "https://app.harness.io/ng/account/${var.harness_account_id}/settings/organizations/${var.harness_org_id}/projects/${var.harness_project_id}/setup/resources/template-studio/${harness_platform_template.deployment_steps.identifier}"
}

# Template Usage:
# The pipeline references this template in stages:
#
#   - stepGroup:
#       name: Coordinated DB and App Deployment
#       identifier: Coordinated_Deployment
#       template:
#         templateRef: Coordinated_DB_App_Deployment
#         versionLabel: v1.0
#
# Template contains 4 steps:
# 1. Fetch Changelog Artifact - Downloads from GitHub Packages
# 2. Update Database - Liquibase via Docker container
# 3. Deploy Application - App Runner (AWS) or Docker Compose (Local)
# 4. Health Check - Verifies deployment with version validation
#
# Template Variables (inherited from stage context):
# - <+env.variables.*>        - Environment-specific values (RDS, App Runner, etc.)
# - <+pipeline.variables.*>   - Pipeline-level values (VERSION, GITHUB_ORG)
# - <+secrets.getValue(...)>  - Harness secrets (credentials, tokens)
#
# Deployment Modes:
# - AWS Mode (default): Uses RDS + App Runner with S3 flow files
# - Local Mode: Uses Docker Compose with local PostgreSQL containers
# - Controlled by: DEPLOYMENT_TARGET environment variable
