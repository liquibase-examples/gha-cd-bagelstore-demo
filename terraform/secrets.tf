# AWS Secrets Manager Configuration
# Stores database credentials

# RDS Username Secret
resource "aws_secretsmanager_secret" "rds_username" {
  count = var.deployment_mode == "aws" ? 1 : 0

  name        = "${var.demo_id}/rds/username"
  description = "RDS master username for ${var.demo_id} demo"

  tags = merge(
    local.tags,
    {
      Name = "${var.demo_id}/rds/username"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_username" {
  count = var.deployment_mode == "aws" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.rds_username[0].id
  secret_string = var.db_username
}

# RDS Password Secret
resource "aws_secretsmanager_secret" "rds_password" {
  count = var.deployment_mode == "aws" ? 1 : 0

  name        = "${var.demo_id}/rds/password"
  description = "RDS master password for ${var.demo_id} demo"

  tags = merge(
    local.tags,
    {
      Name = "${var.demo_id}/rds/password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  count = var.deployment_mode == "aws" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.rds_password[0].id
  secret_string = var.db_password
}

