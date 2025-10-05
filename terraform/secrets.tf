# AWS Secrets Manager Configuration
# Stores database credentials and GitHub PAT

# RDS Username Secret
resource "aws_secretsmanager_secret" "rds_username" {
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
  secret_id     = aws_secretsmanager_secret.rds_username.id
  secret_string = var.db_username
}

# RDS Password Secret
resource "aws_secretsmanager_secret" "rds_password" {
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
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = var.db_password
}

# GitHub Personal Access Token Secret
resource "aws_secretsmanager_secret" "github_pat" {
  name        = "${var.demo_id}/github/pat"
  description = "GitHub Personal Access Token for ${var.demo_id} demo"

  tags = merge(
    local.tags,
    {
      Name = "${var.demo_id}/github/pat"
    }
  )
}

resource "aws_secretsmanager_secret_version" "github_pat" {
  secret_id     = aws_secretsmanager_secret.github_pat.id
  secret_string = var.github_pat
}
