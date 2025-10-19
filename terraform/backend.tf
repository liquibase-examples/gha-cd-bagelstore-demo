# Terraform Backend Configuration
# S3 backend for remote state storage with native locking (Terraform 1.10+)

terraform {
  backend "s3" {
    bucket       = "907240911534-psr-terraform-state"
    key          = "bagel-store/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # Terraform 1.10+ native S3 locking (no DynamoDB needed)
  }
}
