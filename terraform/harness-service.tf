# Harness Service Configuration
#
# Creates the Bagel Store service definition in Harness.
# A service represents the application being deployed.
#
# The service uses CustomDeployment type because we're deploying to:
# - App Runner (not native Kubernetes or ECS)
# - PostgreSQL via Liquibase (custom database deployment)
#
# Pipeline stages reference this service by identifier: bagel_store

resource "harness_platform_service" "bagel_store" {
  identifier  = "bagel_store"
  name        = "Bagel Store"
  description = "Flask application with PostgreSQL database - Coordinated deployment demo"
  org_id      = var.harness_org_id
  project_id  = var.harness_project_id

  tags = [
    "demo_id:${var.demo_id}",
    "managed_by:terraform",
    "app_type:flask",
    "db_type:postgresql"
  ]

  # YAML configuration for service
  yaml = <<-EOT
    service:
      name: Bagel Store
      identifier: bagel_store
      tags:
        demo_id: ${var.demo_id}
        managed_by: terraform
      serviceDefinition:
        type: CustomDeployment
        spec:
          customDeploymentRef:
            templateRef: ""
          # Empty templateRef - deployment logic is in Step Group Template
          # (Coordinated_DB_App_Deployment) which contains FetchInstanceScript
      gitOpsEnabled: false
  EOT
}

# Output service identifier for reference
output "harness_service_identifier" {
  description = "Harness service identifier created"
  value       = harness_platform_service.bagel_store.identifier
}

# Usage in Pipeline:
# Reference service using: serviceRef: bagel_store
#
# The pipeline will use this service definition and add:
# - Artifact sources (Docker image from GitHub Container Registry)
# - Deployment steps (Liquibase + App Runner updates)
# - Environment-specific configuration
