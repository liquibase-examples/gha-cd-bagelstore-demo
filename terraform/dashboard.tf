# Dashboard HTML Generation
# Creates a local HTML file with all demo links and connectivity information

locals {
  dashboard_html = templatefile("${path.module}/dashboard.html.tpl", {
    demo_id     = var.demo_id
    aws_region  = var.aws_region
    github_org  = var.github_org
    github_repo = var.github_repo

    # Deployment mode
    deployment_mode = var.deployment_mode

    # App Runner URLs (AWS mode) or localhost URLs (local mode)
    app_urls = var.deployment_mode == "aws" ? {
      for env in local.environments :
      env => "https://${aws_apprunner_service.bagel_store[env].service_url}"
      } : {
      dev     = "http://localhost:5001"
      test    = "http://localhost:5002"
      staging = "http://localhost:5003"
      prod    = "http://localhost:5004"
    }

    # RDS connection info
    rds_endpoint = var.deployment_mode == "aws" ? aws_db_instance.postgres[0].endpoint : "localhost:5432-5435"
    rds_username = var.db_username
    jdbc_urls = {
      for env in local.environments :
      env => var.deployment_mode == "aws" ?
      "jdbc:postgresql://${aws_db_instance.postgres[0].address}:${aws_db_instance.postgres[0].port}/${env}" :
      "jdbc:postgresql://localhost:${env == "dev" ? "5432" : env == "test" ? "5433" : env == "staging" ? "5434" : "5435"}/${env}"
    }

    # Harness info
    harness_account_id  = var.harness_account_id
    harness_org_id      = var.harness_org_id
    harness_project_id  = var.harness_project_id
    harness_pipeline_id = "Deploy_Bagel_Store"

    # S3 buckets (AWS mode only)
    s3_flows_bucket   = var.deployment_mode == "aws" ? aws_s3_bucket.liquibase_flows[0].id : "N/A (local mode)"
    s3_reports_bucket = var.deployment_mode == "aws" ? aws_s3_bucket.operation_reports[0].id : "N/A (local mode)"
  })
}

resource "local_file" "dashboard" {
  content  = local.dashboard_html
  filename = "${path.module}/../demo-dashboard.html"

  file_permission = "0644"
}

output "dashboard_location" {
  description = "Location of the demo dashboard HTML file"
  value       = abspath("${path.module}/../demo-dashboard.html")
}
