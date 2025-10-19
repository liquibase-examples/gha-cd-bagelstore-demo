# Harness Infrastructure Definitions Configuration
#
# MOVED TO GIT-BASED MANAGEMENT
# Infrastructure definitions are now managed in Git (.harness/.../envs/.../infras/)
# and imported manually via Harness UI.
#
# Rationale (from CLAUDE.md "Hybrid Harness Management"):
# - Terraform is EXCELLENT for: Environments (with AWS outputs), Secrets, Connectors, Service
# - Terraform is PROBLEMATIC for: Remote templates/pipelines/infrastructure (timeouts, feature flags)
# - Infrastructure definitions already in Git anyway (true GitOps)
#
# Location: .harness/orgs/default/projects/bagel_store_demo/envs/<env>/<env>/infras/

# COMMENTED OUT - Managed in Git instead
# resource "harness_platform_infrastructure" "demo_infrastructures" {
#   for_each = local.harness_environments
#
#   identifier      = "${each.value.identifier}_infra"
#   name            = "${each.value.name} Infrastructure"
#   org_id          = var.harness_org_id
#   project_id      = var.harness_project_id
#   env_id          = harness_platform_environment.demo_environments[each.key].id
#   type            = "CustomDeployment"
#   deployment_type = "CustomDeployment"
#
#   yaml = <<-EOT
#     infrastructureDefinition:
#       name: ${each.value.name} Infrastructure
#       identifier: ${each.value.identifier}_infra
#       orgIdentifier: ${var.harness_org_id}
#       projectIdentifier: ${var.harness_project_id}
#       environmentRef: ${each.value.identifier}
#       deploymentType: CustomDeployment
#       type: CustomDeployment
#       spec:
#         customDeploymentRef:
#           templateRef: Custom
#           versionLabel: "1.0"
#         variables: []
#         # Minimal deployment template (.harness/.../templates/Custom/v1_0.yaml)
#         # exists to satisfy Harness validation requirements for CustomDeployment type.
#         # Actual deployment logic is in Step Group Template (Coordinated_DB_App_Deployment)
#       allowSimultaneousDeployments: false
#   EOT
#
#   tags = [
#     "demo_id:${var.demo_id}",
#     "environment:${each.key}",
#     "managed_by:terraform"
#   ]
# }

# Output infrastructure definition identifiers for reference
# COMMENTED OUT - Infrastructure definitions now managed in Git
# output "harness_infrastructure_identifiers" {
#   description = "Harness infrastructure definition identifiers created"
#   value = {
#     for env in local.environments :
#     env => harness_platform_infrastructure.demo_infrastructures[env].identifier
#   }
# }

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
# Infrastructure definitions reference minimal deployment template (Custom v1.0) for validation.
# Template location: .harness/orgs/default/projects/bagel_store_demo/templates/Custom/v1_0.yaml
# Actual deployment logic: Step Group Template (Coordinated_DB_App_Deployment) handles
# all deployment steps including instance discovery via FetchInstanceScript.
