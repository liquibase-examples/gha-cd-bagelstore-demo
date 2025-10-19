# Terraform Main Configuration
# Bagel Store Demo - Multi-Instance Support via demo_id

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    harness = {
      source  = "harness/harness"
      version = "~> 0.30"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = merge(
      var.common_tags,
      {
        demo_id   = var.demo_id
        Requestor = var.aws_username
      }
    )
  }
}

# Public ECR requires us-east-1 provider (only region supported)
provider "aws" {
  alias   = "us-east-1"
  region  = "us-east-1"
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = merge(
      var.common_tags,
      {
        demo_id   = var.demo_id
        Requestor = var.aws_username
      }
    )
  }
}

# GitHub provider for automated secrets management
provider "github" {
  token = var.github_pat
  owner = var.github_org
}

# Local variables for resource naming
locals {
  name_prefix = "bagel-store-${var.demo_id}"

  # Environment names
  environments = ["dev", "test", "staging", "prod"]

  # ECR Public registry alias - extracted from repository URI
  ecr_public_alias = var.deployment_mode == "aws" ? (
    length(aws_ecrpublic_repository.bagel_store) > 0 ?
    split("/", aws_ecrpublic_repository.bagel_store[0].repository_uri)[1] :
    "pending-creation"
  ) : "local-mode"

  # Common tags
  tags = merge(
    var.common_tags,
    {
      demo_id   = var.demo_id
      Requestor = var.aws_username
    }
  )
}
