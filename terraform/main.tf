# Terraform Main Configuration
# Bagel Store Demo - Multi-Instance Support via demo_id

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

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

# Local variables for resource naming
locals {
  name_prefix = "bagel-store-${var.demo_id}"

  # Environment names
  environments = ["dev", "test", "staging", "prod"]

  # Common tags
  tags = merge(
    var.common_tags,
    {
      demo_id   = var.demo_id
      Requestor = var.aws_username
    }
  )
}
