# Harness Terraform Provider Configuration
#
# This provider enables Terraform to manage Harness resources, including:
# - Environments
# - Environment Variables
# - Services
# - Infrastructure Definitions
# - Connectors (optional)
# - Secrets (optional)
#
# Purpose: Automatically configure Harness environments with AWS infrastructure
# outputs so the deployment pipeline can reference them without manual input.
#
# Authentication: Requires Harness API key (use environment variable or tfvars)

# Harness Provider Configuration
provider "harness" {
  # Harness API endpoint
  endpoint = "https://app.harness.io/gateway"

  # Account ID - found in Harness URL after login
  # Example URL: https://app.harness.io/ng/account/ACCOUNT_ID/...
  account_id = var.harness_account_id

  # Authentication - use Personal Access Token (PAT) or Service Access Token (SAT)
  # Recommended: Use environment variable HARNESS_PLATFORM_API_KEY
  # Or set via terraform.tfvars (not recommended for security)
  platform_api_key = var.harness_api_key
}

# Notes on Provider Configuration:
#
# 1. Authentication Methods (in order of preference):
#    a) Environment variable: export HARNESS_PLATFORM_API_KEY="your-api-key"
#    b) Terraform variable: Set in terraform.tfvars (gitignored)
#    c) CLI flag: terraform apply -var="harness_api_key=..."
#
# 2. Creating API Key:
#    - Navigate to: Profile → My API Keys → New API Key
#    - Or use Service Account Token for automation
#    - Scopes needed: Environment (View, Create/Edit), Project (View)
#
# 3. Finding Account ID:
#    - Login to Harness at https://app.harness.io
#    - Check URL: https://app.harness.io/ng/account/YOUR_ACCOUNT_ID/...
#    - Or go to: Account Settings → Overview
#
# 4. Organization and Project:
#    - Must exist before running Terraform
#    - Create manually in Harness UI first
#    - Note the org_id and project_id for use in resources
#
# 5. Best Practices:
#    - Use Service Account Token for CI/CD automation
#    - Store API key in AWS Secrets Manager or similar
#    - Never commit API keys to git
#    - Use separate tokens per demo instance if possible
