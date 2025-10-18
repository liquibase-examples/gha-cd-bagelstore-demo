# Harness Infrastructure Definitions Configuration
#
# Creates infrastructure definitions for CustomDeployment.
# Each environment gets one infrastructure definition that references the Custom deployment template.
#
# Pattern:
# 1. Environment = Container (like a folder)
# 2. Infrastructure Definition = Deployment target (like a file in the folder)
#
# CustomDeployment requires infrastructure definitions to exist, even with deployToAll: true.
# The deployToAll flag means "deploy to ALL infrastructure definitions in this environment",
# not "bypass infrastructure definitions".
#
# Creates 4 infrastructure definitions per demo instance:
# - ${demo_id}_dev_infra
# - ${demo_id}_test_infra
# - ${demo_id}_staging_infra
# - ${demo_id}_prod_infra

resource "harness_platform_infrastructure" "demo_infrastructures" {
  for_each = local.harness_environments

  identifier      = "${each.value.identifier}_infra"
  name            = "${each.value.name} Infrastructure"
  org_id          = var.harness_org_id
  project_id      = var.harness_project_id
  env_id          = harness_platform_environment.demo_environments[each.key].id
  type            = "CustomDeployment"
  deployment_type = "CustomDeployment"

  yaml = <<-EOT
    infrastructureDefinition:
      name: ${each.value.name} Infrastructure
      identifier: ${each.value.identifier}_infra
      orgIdentifier: ${var.harness_org_id}
      projectIdentifier: ${var.harness_project_id}
      environmentRef: ${each.value.identifier}
      deploymentType: CustomDeployment
      type: CustomDeployment
      spec:
        customDeploymentRef:
          templateRef: Custom
          versionLabel: "1.0"
        variables: []
      allowSimultaneousDeployments: false
  EOT

  tags = [
    "demo_id:${var.demo_id}",
    "environment:${each.key}",
    "managed_by:terraform"
  ]
}

# Output infrastructure definition identifiers for reference
output "harness_infrastructure_identifiers" {
  description = "Harness infrastructure definition identifiers created"
  value = {
    for env in local.environments :
    env => harness_platform_infrastructure.demo_infrastructures[env].identifier
  }
}

# Usage in Harness Pipeline:
# Instead of: (no infrastructure definitions → pipeline fails)
# Use:        deployToAll: true (deploys to the ONE infrastructure definition per environment)
#
# Or explicitly reference:
# environment:
#   environmentRef: psr_dev
#   infrastructureDefinitions:
#     - identifier: psr_dev_infra
#
# The infrastructure definition references the Custom deployment template (version 1.0)
# which is defined in the service (harness-service.tf) and contains the deployment steps.
