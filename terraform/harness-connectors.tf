# Harness Connectors Configuration
#
# Creates Harness Platform connectors for external system access.
# Connectors authenticate and connect to GitHub and AWS services.
#
# All connectors use delegate selectors to route through the local delegate.
# This allows access to private networks and manages credentials securely.

# GitHub Connector
# Purpose: Access GitHub repository and GitHub Packages for changelog artifacts
resource "harness_platform_connector_github" "github_bagel_store" {
  identifier  = "github_bagel_store"
  name        = "github-bagel-store"
  description = "GitHub connector for Bagel Store changelog artifacts and repository access"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  url                = "https://github.com/${var.github_org}/${var.github_repo}"
  connection_type    = "Repo"
  validation_repo    = var.github_repo
  delegate_selectors = [var.demo_id]

  credentials {
    http {
      username  = "git"
      token_ref = harness_platform_secret_text.github_pat.identifier
    }
  }

  api_authentication {
    token_ref = harness_platform_secret_text.github_pat.identifier
  }

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]

  depends_on = [
    harness_platform_secret_text.github_pat
  ]
}

# AWS Connector
# Purpose: Access AWS services (App Runner, RDS, Secrets Manager)
resource "harness_platform_connector_aws" "aws_bagel_store" {
  identifier  = "aws_bagel_store"
  name        = "aws-bagel-store"
  description = "AWS connector for App Runner deployments and RDS access"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  # Manual configuration - delegates use their own credentials
  # This is ideal for demo environments where delegates have IAM roles
  manual {
    delegate_selectors = [var.demo_id]
    # The secret_key_ref is not needed for delegate-based credentials
    # But the provider requires it, so we reference the secret anyway
    access_key         = harness_platform_secret_text.aws_access_key_id.identifier
    secret_key_ref     = harness_platform_secret_text.aws_secret_access_key.identifier
  }

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform"
  ]

  depends_on = [
    harness_platform_secret_text.aws_access_key_id,
    harness_platform_secret_text.aws_secret_access_key
  ]

  # Note: Using manual mode means the delegate's AWS credentials are used.
  # If you prefer explicit credentials, uncomment below:
  #
  # credentials {
  #   type               = "ManualConfig"
  #   access_key         = harness_platform_secret_text.aws_access_key_id.identifier
  #   secret_key_ref     = harness_platform_secret_text.aws_secret_access_key.identifier
  # }
  #
  # depends_on = [
  #   harness_platform_secret_text.aws_access_key_id,
  #   harness_platform_secret_text.aws_secret_access_key
  # ]
}

# Output connector identifiers for reference
output "harness_connector_identifiers" {
  description = "Harness connector identifiers created"
  value = {
    github_connector = harness_platform_connector_github.github_bagel_store.identifier
    aws_connector    = harness_platform_connector_aws.aws_bagel_store.identifier
  }
}

# Usage in Pipeline:
# Reference connectors using: <+connector_ref>
#
# Examples:
# - GitHub: connectorRef: github_bagel_store
# - AWS: connectorRef: aws_bagel_store
#
# Delegate Selection:
# Connectors automatically use delegate with selector: ${var.demo_id}
# This allows multiple demo instances to coexist with separate delegates.
