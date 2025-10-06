# Harness Pipeline Configuration
#
# Registers a Remote Pipeline stored in Git with Harness.
# The pipeline YAML lives in: harness/pipelines/deploy-pipeline.yaml
#
# Remote Pipeline Benefits:
# - Version control for pipeline changes
# - Code review via Pull Requests
# - GitOps workflow
# - Single source of truth
#
# Terraform only registers/imports the pipeline - the YAML stays in Git.
# Changes to the pipeline YAML don't require terraform apply.

resource "harness_platform_pipeline" "deploy_bagel_store" {
  identifier = "Deploy_Bagel_Store"
  name       = "Deploy Bagel Store - ${var.demo_id}"
  org_id     = var.harness_org_id
  project_id = var.harness_project_id

  # Remote pipeline configuration - YAML stored in Git
  git_details {
    branch_name   = "main"
    file_path     = "harness/pipelines/deploy-pipeline.yaml"
    connector_ref = harness_platform_connector_github.github_bagel_store.identifier
    repo_name     = "harness-gha-bagelstore"
    store_type    = "REMOTE"
  }

  tags = {
    demo_id    = var.demo_id
    managed_by = "terraform"
  }

  # Pipeline depends on service and GitHub connector
  depends_on = [
    harness_platform_service.bagel_store,
    harness_platform_connector_github.github_bagel_store,
    harness_platform_environment.demo_environments
  ]
}

# Output pipeline identifier for reference
output "harness_pipeline_identifier" {
  description = "Harness pipeline identifier created"
  value       = harness_platform_pipeline.deploy_bagel_store.identifier
}

output "harness_pipeline_url" {
  description = "Harness pipeline URL"
  value       = "https://app.harness.io/ng/account/${var.harness_account_id}/cd/orgs/${var.harness_org_id}/projects/${var.harness_project_id}/pipelines/${harness_platform_pipeline.deploy_bagel_store.identifier}/pipeline-studio/"
}

# Pipeline Execution:
# The pipeline can be executed via:
# 1. Harness UI - Navigate to Pipelines and click "Run"
# 2. Webhook trigger - Configured in pipeline triggers
# 3. API/CLI - Using Harness API
#
# Runtime Inputs Required:
# - VERSION: Git tag version (e.g., v1.0.0)
# - GITHUB_ORG: GitHub organization name
#
# All infrastructure details come from environment variables (configured by Terraform):
# - RDS endpoints, App Runner ARNs, S3 buckets, etc.
# - No manual input needed for infrastructure!
