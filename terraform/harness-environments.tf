# Harness Environments Configuration
#
# Creates Harness CD environments with variables populated from AWS infrastructure outputs.
# This eliminates the need for manual configuration or runtime inputs in the pipeline.
#
# Pattern:
# 1. Terraform provisions AWS resources (RDS, App Runner, S3, etc.)
# 2. Terraform ALSO creates Harness environments with AWS resource details
# 3. Pipeline references: <+env.variables.rds_endpoint> (no manual input!)
#
# Creates 4 environments per demo instance:
# - ${demo_id}-dev
# - ${demo_id}-test
# - ${demo_id}-staging
# - ${demo_id}-prod

locals {
  # Map of environments with their configurations
  harness_environments = {
    for env in local.environments : env => {
      identifier  = "${var.demo_id}_${env}"
      name        = "${var.demo_id}-${env}"
      description = "${upper(env)} environment for ${var.demo_id} demo instance"
      type        = env == "prod" ? "Production" : "PreProduction"

      # Environment variables from AWS outputs
      variables = {
        # Database configuration
        rds_endpoint     = aws_db_instance.postgres.endpoint
        rds_address      = aws_db_instance.postgres.address
        rds_port         = tostring(aws_db_instance.postgres.port)
        database_name    = env
        jdbc_url         = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${env}"

        # App Runner configuration
        app_runner_service_arn  = aws_apprunner_service.bagel_store[env].arn
        app_runner_service_url  = aws_apprunner_service.bagel_store[env].service_url
        app_runner_service_id   = aws_apprunner_service.bagel_store[env].service_id
        app_runner_service_name = "bagel-store-${var.demo_id}-${env}"

        # S3 configuration
        liquibase_flows_bucket    = aws_s3_bucket.liquibase_flows.id
        operation_reports_bucket  = aws_s3_bucket.operation_reports.id

        # Demo configuration
        demo_id      = var.demo_id
        aws_region   = var.aws_region
        environment  = env

        # DNS configuration (if Route53 enabled)
        dns_record = var.enable_route53 ? "${env}-${var.demo_id}.${var.domain_name}" : "not-configured"
      }
    }
  }
}

# Create Harness Platform Environments
resource "harness_platform_environment" "demo_environments" {
  for_each = local.harness_environments

  identifier = each.value.identifier
  name       = each.value.name
  org_id     = var.harness_org_id
  project_id = var.harness_project_id
  type       = each.value.type

  tags = [
    "demo_id:${var.demo_id}",
    "environment:${each.key}",
    "managed_by:terraform"
  ]

  # YAML configuration with environment variables
  yaml = <<-EOT
    environment:
      name: ${each.value.name}
      identifier: ${each.value.identifier}
      description: ${each.value.description}
      orgIdentifier: ${var.harness_org_id}
      projectIdentifier: ${var.harness_project_id}
      type: ${each.value.type}
      tags:
        demo_id: ${var.demo_id}
        environment: ${each.key}
        managed_by: terraform
      variables:
        # Database Configuration
        - name: rds_endpoint
          type: String
          value: "${each.value.variables.rds_endpoint}"
          description: "RDS PostgreSQL endpoint (host:port)"

        - name: rds_address
          type: String
          value: "${each.value.variables.rds_address}"
          description: "RDS PostgreSQL address (host only)"

        - name: rds_port
          type: String
          value: "${each.value.variables.rds_port}"
          description: "RDS PostgreSQL port"

        - name: database_name
          type: String
          value: "${each.value.variables.database_name}"
          description: "Database name for this environment"

        - name: jdbc_url
          type: String
          value: "${each.value.variables.jdbc_url}"
          description: "Full JDBC connection URL"

        # App Runner Configuration
        - name: app_runner_service_arn
          type: String
          value: "${each.value.variables.app_runner_service_arn}"
          description: "App Runner service ARN"

        - name: app_runner_service_url
          type: String
          value: "${each.value.variables.app_runner_service_url}"
          description: "App Runner service default URL"

        - name: app_runner_service_id
          type: String
          value: "${each.value.variables.app_runner_service_id}"
          description: "App Runner service ID"

        - name: app_runner_service_name
          type: String
          value: "${each.value.variables.app_runner_service_name}"
          description: "App Runner service name"

        # S3 Configuration
        - name: liquibase_flows_bucket
          type: String
          value: "${each.value.variables.liquibase_flows_bucket}"
          description: "S3 bucket for Liquibase flow files"

        - name: operation_reports_bucket
          type: String
          value: "${each.value.variables.operation_reports_bucket}"
          description: "S3 bucket for operation reports"

        # Demo Configuration
        - name: demo_id
          type: String
          value: "${each.value.variables.demo_id}"
          description: "Demo instance identifier"

        - name: aws_region
          type: String
          value: "${each.value.variables.aws_region}"
          description: "AWS region"

        - name: environment
          type: String
          value: "${each.value.variables.environment}"
          description: "Environment name (dev/test/staging/prod)"

        - name: dns_record
          type: String
          value: "${each.value.variables.dns_record}"
          description: "DNS record (if Route53 enabled)"
  EOT

  # Ensure environments are created after AWS resources exist
  depends_on = [
    aws_db_instance.postgres,
    aws_apprunner_service.bagel_store,
    aws_s3_bucket.liquibase_flows,
    aws_s3_bucket.operation_reports
  ]
}

# Output environment identifiers for reference
output "harness_environment_identifiers" {
  description = "Harness environment identifiers created"
  value = {
    for env in local.environments :
    env => harness_platform_environment.demo_environments[env].identifier
  }
}

output "harness_environment_details" {
  description = "Complete Harness environment configuration"
  value = {
    for env in local.environments :
    env => {
      identifier = harness_platform_environment.demo_environments[env].identifier
      name       = harness_platform_environment.demo_environments[env].name
      type       = harness_platform_environment.demo_environments[env].type
      # Show key variable values for verification
      rds_endpoint           = local.harness_environments[env].variables.rds_endpoint
      app_runner_service_url = local.harness_environments[env].variables.app_runner_service_url
    }
  }
}

# Usage in Harness Pipeline:
# Instead of: <+pipeline.variables.RDS_ENDPOINT>
# Use:        <+env.variables.rds_endpoint>
#
# Example Liquibase command in pipeline:
# docker run liquibase/liquibase-secure:5.0.1 \
#   --url=jdbc:postgresql://<+env.variables.rds_address>:<+env.variables.rds_port>/<+env.variables.database_name> \
#   --username='${awsSecretsManager:<+env.variables.demo_id>/rds/username}' \
#   --password='${awsSecretsManager:<+env.variables.demo_id>/rds/password}' \
#   update
#
# Example AWS CLI command in pipeline:
# aws apprunner update-service \
#   --service-arn <+env.variables.app_runner_service_arn> \
#   --region <+env.variables.aws_region>
