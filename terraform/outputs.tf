# Terraform Outputs
# Provides resource information after deployment
# All AWS resource outputs are conditional based on deployment_mode

# ===== RDS Outputs (AWS mode only) =====

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = var.deployment_mode == "aws" ? aws_db_instance.postgres[0].endpoint : "local-mode-not-applicable"
}

output "rds_address" {
  description = "RDS instance address (without port)"
  value       = var.deployment_mode == "aws" ? aws_db_instance.postgres[0].address : "local-mode-not-applicable"
}

output "rds_port" {
  description = "RDS instance port"
  value       = var.deployment_mode == "aws" ? aws_db_instance.postgres[0].port : "5432"
}

output "rds_databases" {
  description = "Database names created on RDS instance"
  value       = ["dev", "test", "staging", "prod"]
}

# ===== S3 Outputs (AWS mode only) =====

output "liquibase_flows_bucket" {
  description = "S3 bucket for Liquibase flow files"
  value       = var.deployment_mode == "aws" ? aws_s3_bucket.liquibase_flows[0].id : "local-mode-not-applicable"
}

output "liquibase_flows_bucket_url" {
  description = "S3 bucket URL for flow files"
  value       = var.deployment_mode == "aws" ? "s3://${aws_s3_bucket.liquibase_flows[0].id}" : "local-mode-not-applicable"
}

output "operation_reports_bucket" {
  description = "S3 bucket for operation reports"
  value       = var.deployment_mode == "aws" ? aws_s3_bucket.operation_reports[0].id : "local-mode-not-applicable"
}

output "operation_reports_bucket_url" {
  description = "S3 bucket URL for operation reports"
  value       = var.deployment_mode == "aws" ? "s3://${aws_s3_bucket.operation_reports[0].id}" : "local-mode-not-applicable"
}

# ===== Secrets Manager Outputs (AWS mode only) =====

output "secrets_rds_username_arn" {
  description = "ARN of RDS username secret"
  value       = var.deployment_mode == "aws" ? aws_secretsmanager_secret.rds_username[0].arn : "local-mode-not-applicable"
}

output "secrets_rds_password_arn" {
  description = "ARN of RDS password secret"
  value       = var.deployment_mode == "aws" ? aws_secretsmanager_secret.rds_password[0].arn : "local-mode-not-applicable"
  sensitive   = true
}

# ===== App Runner Outputs (AWS mode only) =====

output "app_runner_services" {
  description = "App Runner service URLs by environment"
  value = var.deployment_mode == "aws" ? {
    for env in local.environments :
    env => {
      service_arn = aws_apprunner_service.bagel_store[env].arn
      service_url = aws_apprunner_service.bagel_store[env].service_url
      service_id  = aws_apprunner_service.bagel_store[env].service_id
    }
  } : {
    dev     = { service_url = "localhost:5001", service_arn = "local-mode", service_id = "local-mode" }
    test    = { service_url = "localhost:5002", service_arn = "local-mode", service_id = "local-mode" }
    staging = { service_url = "localhost:5003", service_arn = "local-mode", service_id = "local-mode" }
    prod    = { service_url = "localhost:5004", service_arn = "local-mode", service_id = "local-mode" }
  }
}

# ===== Route53 Outputs (Optional, AWS mode only) =====

output "dns_records" {
  description = "DNS records for all environments (only if Route53 is enabled)"
  value = var.deployment_mode == "aws" && var.enable_route53 ? {
    for env in local.environments :
    env => "${env}-${var.demo_id}.${var.domain_name}"
  } : var.deployment_mode == "aws" ? {
    for env in local.environments :
    env => "Route53 disabled - use App Runner URL: https://${aws_apprunner_service.bagel_store[env].service_url}"
  } : {
    for env in local.environments :
    env => "local-mode - use localhost URLs"
  }
}

# ===== Connection Strings =====

output "jdbc_urls" {
  description = "JDBC connection URLs for all databases"
  value = var.deployment_mode == "aws" ? {
    for env in local.environments :
    env => "jdbc:postgresql://${aws_db_instance.postgres[0].address}:${aws_db_instance.postgres[0].port}/${env}"
  } : {
    for env in local.environments :
    env => "jdbc:postgresql://postgres-${env}:5432/${env}"
  }
}

# ===== Liquibase Commands (AWS mode only) =====

output "liquibase_example_commands" {
  description = "Example Liquibase commands"
  value = var.deployment_mode == "aws" ? join("\n", [
    "# Using AWS Secrets Manager for credentials:",
    "docker run --rm \\",
    "  -v $(pwd)/db/changelog:/liquibase/changelog \\",
    "  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \\",
    "  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \\",
    "  -e AWS_REGION=${var.aws_region} \\",
    "  liquibase/liquibase-secure:5.0.1 \\",
    "  --url=jdbc:postgresql://${var.deployment_mode == "aws" ? aws_db_instance.postgres[0].address : "localhost"}:${var.deployment_mode == "aws" ? aws_db_instance.postgres[0].port : "5432"}/dev \\",
    "  --username='$${awsSecretsManager:${var.demo_id}/rds/username}' \\",
    "  --password='$${awsSecretsManager:${var.demo_id}/rds/password}' \\",
    "  --changeLogFile=changelog-master.yaml \\",
    "  validate"
  ]) : "Local mode - use: docker compose -f docker-compose-demo.yml up -d"
}

# ===== Deployment Mode Summary =====

output "deployment_mode" {
  description = "Deployment mode (aws or local)"
  value       = var.deployment_mode
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = var.deployment_mode == "aws" ? {
    demo_id           = var.demo_id
    deployment_mode   = var.deployment_mode
    aws_region        = var.aws_region
    rds_endpoint      = aws_db_instance.postgres[0].endpoint
    s3_flows_bucket   = aws_s3_bucket.liquibase_flows[0].id
    s3_reports_bucket = aws_s3_bucket.operation_reports[0].id
    app_runner_count  = length(local.environments)
    route53_enabled   = var.enable_route53
    dns_base          = var.enable_route53 ? "${var.demo_id}.${var.domain_name}" : "Route53 disabled - use App Runner URLs"
  } : {
    demo_id         = var.demo_id
    deployment_mode = var.deployment_mode
    message         = "Local mode - Use docker-compose-demo.yml for deployment"
    app_ports       = "dev:5001, test:5002, staging:5003, prod:5004"
    db_ports        = "dev:5432, test:5433, staging:5434, prod:5435"
  }
}
