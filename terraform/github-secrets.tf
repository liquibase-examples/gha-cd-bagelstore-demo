# GitHub Actions Secrets - Automated Configuration
# Terraform will create/update these secrets automatically
# No manual `gh secret set` commands needed!

resource "github_actions_secret" "aws_access_key_id" {
  repository      = var.github_repo
  secret_name     = "AWS_ACCESS_KEY_ID"
  plaintext_value = var.aws_access_key_id
}

resource "github_actions_secret" "aws_secret_access_key" {
  repository      = var.github_repo
  secret_name     = "AWS_SECRET_ACCESS_KEY"
  plaintext_value = var.aws_secret_access_key
}

resource "github_actions_secret" "aws_region" {
  repository      = var.github_repo
  secret_name     = "AWS_REGION"
  plaintext_value = "us-east-1" # ECR Public requirement
}

# GitHub Actions Variables (not secrets)
resource "github_actions_variable" "demo_id" {
  repository    = var.github_repo
  variable_name = "DEMO_ID"
  value         = var.demo_id
}

resource "github_actions_variable" "deployment_target" {
  repository    = var.github_repo
  variable_name = "DEPLOYMENT_TARGET"
  value         = var.deployment_mode
}

# Output for verification
output "github_secrets_configured" {
  description = "GitHub secrets successfully configured"
  value = {
    repository        = var.github_repo
    aws_credentials   = "configured"
    demo_id           = var.demo_id
    deployment_target = var.deployment_mode
  }
}
