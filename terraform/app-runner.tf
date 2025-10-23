# AWS App Runner Services Configuration
# Creates 4 App Runner services (dev, test, staging, prod)

# SSM Parameter Store - Image tags written by Harness CD before Terraform Apply
# These parameters are created/updated by Harness pipeline before calling Terraform
data "aws_ssm_parameter" "image_tag" {
  for_each = var.deployment_mode == "aws" ? toset(local.environments) : []
  name     = "/${var.demo_id}/image-tags/${each.key}"

  # Don't fail if parameter doesn't exist yet (first deployment uses placeholder)
  # After first deployment, Harness will write SSM parameter before each Terraform apply
  lifecycle {
    postcondition {
      condition     = self.value != ""
      error_message = "SSM parameter /${var.demo_id}/image-tags/${each.key} must have a non-empty value"
    }
  }
}

# Map environment name to image tag from SSM
locals {
  image_tags = {
    for env in local.environments :
    env => try(data.aws_ssm_parameter.image_tag[env].value, "latest")
  }
}

# IAM role for App Runner instance
resource "aws_iam_role" "apprunner_instance" {
  count = var.deployment_mode == "aws" ? 1 : 0

  name = "${local.name_prefix}-apprunner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

# Policy to allow App Runner to access Secrets Manager
resource "aws_iam_role_policy" "apprunner_secrets" {
  count = var.deployment_mode == "aws" ? 1 : 0

  name = "${local.name_prefix}-apprunner-secrets-policy"
  role = aws_iam_role.apprunner_instance[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_username[0].arn,
          aws_secretsmanager_secret.rds_password[0].arn
        ]
      }
    ]
  })
}

# Note: No access role needed for public AWS Public ECR images
# App Runner can pull public ECR images without authentication

# App Runner services for each environment
resource "aws_apprunner_service" "bagel_store" {
  for_each = var.deployment_mode == "aws" ? toset(local.environments) : []

  service_name = "${local.name_prefix}-${each.key}"

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      # Image tag dynamically read from SSM Parameter Store
      # Harness CD writes SSM parameter before Terraform apply
      image_identifier      = "public.ecr.aws/${local.ecr_public_alias}/${var.demo_id}-bagel-store:${local.image_tags[each.key]}"
      image_repository_type = "ECR_PUBLIC"

      image_configuration {
        port = "5000" # Flask port

        runtime_environment_variables = {
          FLASK_ENV     = "production"
          ENVIRONMENT   = each.key
          APP_VERSION   = local.image_tags[each.key]
          DB_HOST       = aws_db_instance.postgres[0].address
          DB_PORT       = "5432"
          DB_NAME       = each.key
          DEMO_ID       = var.demo_id
          DEMO_USERNAME = "demo"
          DEMO_PASSWORD = "bagels123"
        }

        runtime_environment_secrets = {
          # Fixed: Use correct variable names that app expects
          DB_USERNAME = aws_secretsmanager_secret.rds_username[0].arn
          DB_PASSWORD = aws_secretsmanager_secret.rds_password[0].arn
        }
      }
    }

    # No authentication_configuration needed for public AWS Public ECR images
  }

  instance_configuration {
    cpu               = var.app_runner_cpu
    memory            = var.app_runner_memory
    instance_role_arn = aws_iam_role.apprunner_instance[0].arn
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  # Fixed instance count (no auto-scaling)
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.fixed[0].arn

  tags = merge(
    local.tags,
    {
      Name        = "${local.name_prefix}-${each.key}"
      Environment = each.key
    }
  )
}

# Auto-scaling configuration with fixed instance count
resource "aws_apprunner_auto_scaling_configuration_version" "fixed" {
  count = var.deployment_mode == "aws" ? 1 : 0

  auto_scaling_configuration_name = "${local.name_prefix}-fixed-scaling"

  max_concurrency = 100
  max_size        = 1
  min_size        = 1

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-fixed-scaling"
    }
  )
}
