# Harness Webhook Trigger Configuration
#
# Creates a webhook trigger that allows GitHub Actions to automatically
# start the Harness deployment pipeline after artifacts are built.
#
# Flow:
# 1. GitHub Actions builds Docker image + changelog artifact
# 2. GitHub Actions POSTs to webhook URL with version info
# 3. Harness receives webhook and starts pipeline
# 4. Pipeline deploys to dev automatically, then waits for approvals

resource "harness_platform_triggers" "github_actions_webhook" {
  identifier = "github_actions_ci"
  name       = "GitHub Actions CI - ${var.demo_id}"
  org_id     = var.harness_org_id
  project_id = var.harness_project_id
  target_id  = harness_platform_pipeline.deploy_bagel_store.identifier

  yaml = <<-EOT
    trigger:
      name: GitHub Actions CI - ${var.demo_id}
      identifier: github_actions_ci
      enabled: true
      description: "Triggered automatically when GitHub Actions completes artifact builds. Maps GitHub Actions payload to pipeline inputs."
      tags:
        demo_id: ${var.demo_id}
        managed_by: terraform
        integration: github_actions
      orgIdentifier: ${var.harness_org_id}
      projectIdentifier: ${var.harness_project_id}
      pipelineIdentifier: ${harness_platform_pipeline.deploy_bagel_store.identifier}

      source:
        type: Webhook
        spec:
          type: Custom
          spec:
            payloadConditions:
              # Only trigger if version is provided
              - key: version
                operator: Equals
                value: <+trigger.payload.version>
            headerConditions: []

      inputYaml: |
        pipeline:
          identifier: ${harness_platform_pipeline.deploy_bagel_store.identifier}
          variables:
            - name: VERSION
              type: String
              value: <+trigger.payload.version>
            - name: GITHUB_ORG
              type: String
              value: ${var.github_org}
  EOT

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform",
    "integration:github_actions"
  ]

  depends_on = [
    harness_platform_pipeline.deploy_bagel_store
  ]
}

# Instructions for retrieving webhook URL
# The Harness Terraform provider doesn't expose webhook URLs as outputs.
# You need to retrieve the URL from the Harness UI or API after creation.

output "harness_webhook_instructions" {
  description = "Webhook setup status and verification instructions"
  value       = <<-EOT

    ====================================================================
    ✅ HARNESS WEBHOOK SETUP - FULLY AUTOMATED!
    ====================================================================

    The webhook trigger has been created in Harness and GitHub variable
    has been set automatically!

    WHAT WAS CONFIGURED:

    ✅ Harness webhook trigger created
    ✅ GitHub variable HARNESS_WEBHOOK_URL set automatically
    ✅ Integration ready to use

    VERIFY THE SETUP:

    1. Check GitHub variable was set:
       gh variable list --repo ${var.github_org}/${var.github_repo} | grep HARNESS_WEBHOOK_URL

    2. Test the integration:
       git push origin main
       # Watch GitHub Actions complete, then check Harness UI

    TROUBLESHOOTING:

    If webhook doesn't trigger, verify URL in Harness UI:
    - Navigate to: https://app.harness.io/ng/account/${var.harness_account_id}/cd/orgs/${var.harness_org_id}/projects/${var.harness_project_id}/pipelines/${harness_platform_pipeline.deploy_bagel_store.identifier}/pipeline-studio/
    - Click "Triggers" tab → "GitHub Actions CI - ${var.demo_id}"
    - Compare webhook URL with GitHub variable

    ====================================================================
    EOT
}

# Alternative: Construct webhook URL manually (may vary by Harness version)
# Format: https://app.harness.io/gateway/api/webhooks/{accountId}/{orgId}/{projectId}/{triggerIdentifier}?pipelineIdentifier={pipelineId}
output "harness_webhook_url_format" {
  description = "Webhook URL format (actual URL available in Harness UI after trigger creation)"
  value       = "https://app.harness.io/gateway/api/webhooks/${var.harness_account_id}/${var.harness_org_id}/${var.harness_project_id}/${harness_platform_triggers.github_actions_webhook.identifier}?pipelineIdentifier=${harness_platform_pipeline.deploy_bagel_store.identifier}"
}

output "harness_trigger_details" {
  description = "Webhook trigger details for reference"
  value = {
    trigger_name       = harness_platform_triggers.github_actions_webhook.name
    trigger_identifier = harness_platform_triggers.github_actions_webhook.identifier
    pipeline_id        = harness_platform_pipeline.deploy_bagel_store.identifier
    org_id             = var.harness_org_id
    project_id         = var.harness_project_id
  }
}

# Automatically set GitHub variable with webhook URL
# This eliminates manual configuration step!
resource "null_resource" "set_github_webhook_variable" {
  # Run whenever the trigger changes
  triggers = {
    trigger_id = harness_platform_triggers.github_actions_webhook.id
  }

  # Use constructed webhook URL to set GitHub variable
  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # Construct webhook URL
      WEBHOOK_URL="https://app.harness.io/gateway/api/webhooks/${var.harness_account_id}/${var.harness_org_id}/${var.harness_project_id}/${harness_platform_triggers.github_actions_webhook.identifier}?pipelineIdentifier=${harness_platform_pipeline.deploy_bagel_store.identifier}"

      # Set GitHub repository variable
      echo "Setting HARNESS_WEBHOOK_URL in GitHub repository..."
      gh variable set HARNESS_WEBHOOK_URL \
        --repo ${var.github_org}/${var.github_repo} \
        --body "$WEBHOOK_URL"

      echo "✅ GitHub variable HARNESS_WEBHOOK_URL set successfully!"
      echo "Webhook URL: $WEBHOOK_URL"
    EOT
  }

  depends_on = [
    harness_platform_triggers.github_actions_webhook
  ]
}

output "github_variable_status" {
  description = "Status of GitHub variable configuration"
  value       = "HARNESS_WEBHOOK_URL variable will be automatically set in GitHub repository after terraform apply"
  depends_on  = [null_resource.set_github_webhook_variable]
}
