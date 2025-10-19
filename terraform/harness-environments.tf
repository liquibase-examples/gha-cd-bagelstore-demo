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

      # Environment variables - conditional based on deployment_mode
      variables = var.deployment_mode == "aws" ? {
        # AWS MODE - Use RDS and App Runner
        # Database configuration
        rds_endpoint  = aws_db_instance.postgres[0].endpoint
        rds_address   = aws_db_instance.postgres[0].address
        rds_port      = tostring(aws_db_instance.postgres[0].port)
        database_name = env
        jdbc_url      = "jdbc:postgresql://${aws_db_instance.postgres[0].address}:${aws_db_instance.postgres[0].port}/${env}"

        # App Runner configuration
        app_runner_service_arn  = aws_apprunner_service.bagel_store[env].arn
        app_runner_service_url  = aws_apprunner_service.bagel_store[env].service_url
        app_runner_service_id   = aws_apprunner_service.bagel_store[env].service_id
        app_runner_service_name = "bagel-store-${var.demo_id}-${env}"

        # S3 configuration
        liquibase_flows_bucket   = aws_s3_bucket.liquibase_flows[0].id
        operation_reports_bucket = aws_s3_bucket.operation_reports[0].id

        # Demo configuration
        demo_id     = var.demo_id
        aws_region  = var.aws_region
        environment = env

        # Secrets Manager ARNs
        secrets_username_arn = aws_secretsmanager_secret.rds_username[0].arn
        secrets_password_arn = aws_secretsmanager_secret.rds_password[0].arn

        # DNS configuration (if Route53 enabled)
        dns_record = var.enable_route53 ? "${env}-${var.demo_id}.${var.domain_name}" : "not-configured"
        } : {
        # LOCAL MODE - Use Docker Compose (dummy AWS values)
        # Database configuration
        rds_endpoint  = "local-postgres-${env}:5432"
        rds_address   = "local-postgres-${env}"
        rds_port      = "5432"
        database_name = env
        jdbc_url      = "jdbc:postgresql://postgres-${env}:5432/${env}"

        # App Runner configuration (not used in local mode)
        app_runner_service_arn  = "local-mode-not-applicable"
        app_runner_service_url  = "localhost:${env == "dev" ? "5001" : env == "test" ? "5002" : env == "staging" ? "5003" : "5004"}"
        app_runner_service_id   = "local-mode-not-applicable"
        app_runner_service_name = "bagel-store-local-${env}"

        # S3 configuration (not used in local mode)
        liquibase_flows_bucket   = "local-mode-not-applicable"
        operation_reports_bucket = "local-mode-not-applicable"

        # Demo configuration
        demo_id     = var.demo_id
        aws_region  = var.aws_region
        environment = env

        # Secrets Manager ARNs (not used in local mode, but required for template compatibility)
        secrets_username_arn = "local-mode-not-applicable"
        secrets_password_arn = "local-mode-not-applicable"

        # DNS configuration
        dns_record = "localhost"
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

        # Deployment Mode Configuration
        - name: DEPLOYMENT_TARGET
          type: String
          value: "${var.deployment_mode}"
          description: "Deployment mode: 'aws' for App Runner/RDS, 'local' for Docker Compose"

        # ECR Configuration
        - name: ecr_public_alias
          type: String
          value: "${local.ecr_public_alias}"
          description: "AWS Public ECR registry alias for Docker images"

        # AWS Secrets Manager ARNs (for App Runner RuntimeEnvironmentSecrets)
        - name: secrets_username_arn
          type: String
          value: "${each.value.variables.secrets_username_arn}"
          description: "ARN of AWS Secrets Manager secret for database username"

        - name: secrets_password_arn
          type: String
          value: "${each.value.variables.secrets_password_arn}"
          description: "ARN of AWS Secrets Manager secret for database password"
  EOT

  # Note: depends_on removed since AWS resources are now conditional
  # Terraform automatically handles dependencies through resource references in locals
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
