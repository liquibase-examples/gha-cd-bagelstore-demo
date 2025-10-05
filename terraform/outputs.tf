# Terraform Outputs
# Provides resource information after deployment

# ===== RDS Outputs =====

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address (without port)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_databases" {
  description = "Database names created on RDS instance"
  value       = ["dev", "test", "staging", "prod"]
}

# ===== S3 Outputs =====

output "liquibase_flows_bucket" {
  description = "S3 bucket for Liquibase flow files"
  value       = aws_s3_bucket.liquibase_flows.id
}

output "liquibase_flows_bucket_url" {
  description = "S3 bucket URL for flow files"
  value       = "s3://${aws_s3_bucket.liquibase_flows.id}"
}

output "operation_reports_bucket" {
  description = "S3 bucket for operation reports"
  value       = aws_s3_bucket.operation_reports.id
}

output "operation_reports_bucket_url" {
  description = "S3 bucket URL for operation reports"
  value       = "s3://${aws_s3_bucket.operation_reports.id}"
}

# ===== Secrets Manager Outputs =====

output "secrets_rds_username_arn" {
  description = "ARN of RDS username secret"
  value       = aws_secretsmanager_secret.rds_username.arn
}

output "secrets_rds_password_arn" {
  description = "ARN of RDS password secret"
  value       = aws_secretsmanager_secret.rds_password.arn
  sensitive   = true
}

# ===== App Runner Outputs =====

output "app_runner_services" {
  description = "App Runner service URLs by environment"
  value = {
    for env in local.environments :
    env => {
      service_arn = aws_apprunner_service.bagel_store[env].arn
      service_url = aws_apprunner_service.bagel_store[env].service_url
      service_id  = aws_apprunner_service.bagel_store[env].service_id
    }
  }
}

# ===== Route53 Outputs (Optional) =====

output "dns_records" {
  description = "DNS records for all environments (only if Route53 is enabled)"
  value = var.enable_route53 ? {
    for env in local.environments :
    env => "${env}-${var.demo_id}.${var.domain_name}"
  } : {
    for env in local.environments :
    env => "Route53 disabled - use App Runner URL: https://${aws_apprunner_service.bagel_store[env].service_url}"
  }
}

# ===== Connection Strings =====

output "jdbc_urls" {
  description = "JDBC connection URLs for all databases"
  value = {
    for env in local.environments :
    env => "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${env}"
  }
}

# ===== Liquibase Commands =====

output "liquibase_example_commands" {
  description = "Example Liquibase commands using AWS Secrets Manager"
  value = <<-EOT
    # Using AWS Secrets Manager for credentials:
    docker run --rm \
      -v $(pwd)/db/changelog:/liquibase/changelog \
      -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      -e AWS_REGION=${var.aws_region} \
      liquibase/liquibase-secure:5.0.1 \
      --url=jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/dev \
      --username='$${awsSecretsManager:${var.demo_id}/rds/username}' \
      --password='$${awsSecretsManager:${var.demo_id}/rds/password}' \
      --changeLogFile=changelog-master.yaml \
      validate

    # Using flow file from S3:
    docker run --rm \
      -v $(pwd)/db/changelog:/liquibase/changelog \
      -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
      -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
      -e AWS_REGION=${var.aws_region} \
      liquibase/liquibase-secure:5.0.1 \
      flow \
      --flow-file=s3://${aws_s3_bucket.liquibase_flows.id}/pr-validation-flow.yaml
  EOT
}

# ===== Summary =====

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    demo_id              = var.demo_id
    aws_region           = var.aws_region
    rds_endpoint         = aws_db_instance.postgres.endpoint
    s3_flows_bucket      = aws_s3_bucket.liquibase_flows.id
    s3_reports_bucket    = aws_s3_bucket.operation_reports.id
    app_runner_count     = length(local.environments)
    route53_enabled      = var.enable_route53
    dns_base             = var.enable_route53 ? "${var.demo_id}.${var.domain_name}" : "Route53 disabled - use App Runner URLs"
  }
}
