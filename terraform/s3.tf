# S3 Bucket Configuration
# Two buckets: liquibase-flows (public) and operation-reports (private)

# ===== Liquibase Flows Bucket (Public Read) =====

resource "aws_s3_bucket" "liquibase_flows" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = "${local.name_prefix}-liquibase-flows"

  tags = merge(
    local.tags,
    {
      Name    = "${local.name_prefix}-liquibase-flows"
      Purpose = "Liquibase flow files and policy checks"
    }
  )
}

resource "aws_s3_bucket_versioning" "liquibase_flows" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "liquibase_flows" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "liquibase_flows" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.liquibase_flows[0].arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.liquibase_flows]
}

# Upload Liquibase flow files
resource "aws_s3_object" "pr_validation_flow" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id
  key    = "pr-validation-flow.yaml"
  source = "${path.module}/../liquibase-flows/pr-validation-flow.yaml"
  etag   = filemd5("${path.module}/../liquibase-flows/pr-validation-flow.yaml")

  content_type = "application/x-yaml"

  tags = merge(
    local.tags,
    {
      Name = "pr-validation-flow.yaml"
    }
  )
}

resource "aws_s3_object" "main_deployment_flow" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id
  key    = "main-deployment-flow.yaml"
  source = "${path.module}/../liquibase-flows/main-deployment-flow.yaml"
  etag   = filemd5("${path.module}/../liquibase-flows/main-deployment-flow.yaml")

  content_type = "application/x-yaml"

  tags = merge(
    local.tags,
    {
      Name = "main-deployment-flow.yaml"
    }
  )
}

resource "aws_s3_object" "policy_checks_config" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.liquibase_flows[0].id
  key    = "liquibase.checks-settings.conf"
  source = "${path.module}/../liquibase-flows/liquibase.checks-settings.conf"
  etag   = filemd5("${path.module}/../liquibase-flows/liquibase.checks-settings.conf")

  content_type = "text/plain"

  tags = merge(
    local.tags,
    {
      Name = "liquibase.checks-settings.conf"
    }
  )
}

# ===== Operation Reports Bucket (Private) =====

resource "aws_s3_bucket" "operation_reports" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = "${local.name_prefix}-operation-reports"

  tags = merge(
    local.tags,
    {
      Name    = "${local.name_prefix}-operation-reports"
      Purpose = "Liquibase operation reports from CI/CD"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "operation_reports" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.operation_reports[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to delete reports after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "operation_reports" {
  count = var.deployment_mode == "aws" ? 1 : 0

  bucket = aws_s3_bucket.operation_reports[0].id

  rule {
    id     = "delete-old-reports"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 30
    }
  }
}
