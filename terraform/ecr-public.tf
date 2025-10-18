# AWS Public ECR Repository
# Public ECR only available in us-east-1 region
# Free tier: unlimited storage and bandwidth for public repositories

resource "aws_ecrpublic_repository" "bagel_store" {
  count    = var.deployment_mode == "aws" ? 1 : 0
  provider = aws.us-east-1 # Public ECR only in us-east-1

  repository_name = "${var.demo_id}-bagel-store"

  catalog_data {
    about_text        = "Bagel Store demo - Harness CD + Liquibase + GitHub Actions"
    description       = "Flask application with PostgreSQL, demonstrating coordinated database and application deployments"
    operating_systems = ["Linux"]
    architectures     = ["x86-64"]
  }

  tags = merge(
    local.tags,
    {
      Name = "${var.demo_id}-bagel-store"
    }
  )
}
