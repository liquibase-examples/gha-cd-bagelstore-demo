# AWS App Runner Services Configuration
# Creates 4 App Runner services (dev, test, staging, prod)

# IAM role for App Runner instance
resource "aws_iam_role" "apprunner_instance" {
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
  name = "${local.name_prefix}-apprunner-secrets-policy"
  role = aws_iam_role.apprunner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.rds_username.arn,
          aws_secretsmanager_secret.rds_password.arn,
          aws_secretsmanager_secret.github_pat.arn
        ]
      }
    ]
  })
}

# IAM role for App Runner access (to pull images from ECR/GHCR)
resource "aws_iam_role" "apprunner_access" {
  name = "${local.name_prefix}-apprunner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.tags
}

# Attach ECR access policy
resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner_access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# App Runner services for each environment
resource "aws_apprunner_service" "bagel_store" {
  for_each = toset(local.environments)

  service_name = "${local.name_prefix}-${each.key}"

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      image_identifier      = "public.ecr.aws/docker/library/nginx:latest" # Placeholder - will be updated by Harness
      image_repository_type = "ECR_PUBLIC"

      image_configuration {
        port = "5000"

        runtime_environment_variables = {
          FLASK_ENV    = each.key
          ENVIRONMENT  = each.key
          DATABASE_URL = "postgresql://$${SECRETS_MANAGER_ARN_USERNAME}:$${SECRETS_MANAGER_ARN_PASSWORD}@${aws_db_instance.postgres.address}:5432/${each.key}"
        }

        runtime_environment_secrets = {
          SECRETS_MANAGER_ARN_USERNAME = aws_secretsmanager_secret.rds_username.arn
          SECRETS_MANAGER_ARN_PASSWORD = aws_secretsmanager_secret.rds_password.arn
        }
      }
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_access.arn
    }
  }

  instance_configuration {
    cpu               = var.app_runner_cpu
    memory            = var.app_runner_memory
    instance_role_arn = aws_iam_role.apprunner_instance.arn
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
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.fixed.arn

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
