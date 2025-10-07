# Terraform Variables for Bagel Store Demo
# Supports multiple concurrent demo instances via demo_id

# ===== Core Demo Configuration =====

variable "demo_id" {
  description = "Unique identifier for this demo instance (e.g., 'demo1', 'customer-abc')"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.demo_id))
    error_message = "demo_id must be lowercase alphanumeric with hyphens only"
  }
}

variable "deployment_mode" {
  description = "Deployment target mode: 'aws' for cloud infrastructure (RDS, App Runner), 'local' for Docker Compose"
  type        = string
  default     = "aws"

  validation {
    condition     = contains(["aws", "local"], var.deployment_mode)
    error_message = "deployment_mode must be either 'aws' or 'local'"
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_username" {
  description = "AWS username for resource tagging (deployed_by tag)"
  type        = string
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = ""
}

# ===== Database Configuration =====

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "RDS master password (will be stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

# ===== Application Configuration =====

variable "github_org" {
  description = "GitHub organization name"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (will change if someone clones/forks the repo)"
  type        = string
  default     = "harness-gha-bagelstore"
}

variable "github_username" {
  description = "GitHub username for connector authentication"
  type        = string
  default     = ""
}

variable "github_pat" {
  description = "GitHub Personal Access Token for Harness configuration"
  type        = string
  sensitive   = true
}

variable "app_runner_cpu" {
  description = "App Runner vCPU configuration (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "app_runner_memory" {
  description = "App Runner memory in MB"
  type        = number
  default     = 2048
}

# ===== DNS Configuration (Optional) =====

variable "enable_route53" {
  description = "Enable Route53 DNS records for App Runner services"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Base domain for Route53 records (e.g., 'bagel-demo.example.com'). Required if enable_route53 = true"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for the domain. Required if enable_route53 = true"
  type        = string
  default     = ""
}

# ===== Harness Configuration =====

variable "harness_account_id" {
  description = "Harness account ID (found in Harness URL after login)"
  type        = string
  default     = ""
}

variable "harness_api_key" {
  description = "Harness Platform API key (Personal Access Token or Service Account Token)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "harness_org_id" {
  description = "Harness organization ID (e.g., 'default')"
  type        = string
  default     = "default"
}

variable "harness_project_id" {
  description = "Harness project ID where environments will be created"
  type        = string
  default     = ""
}

# ===== AWS Credentials for Harness =====

variable "aws_access_key_id" {
  description = "AWS Access Key ID for Harness deployments (stored as Harness secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for Harness deployments (stored as Harness secret)"
  type        = string
  sensitive   = true
  default     = ""
}

# ===== Liquibase Configuration =====

variable "liquibase_license_key" {
  description = "Liquibase Secure/Pro license key for database deployments"
  type        = string
  sensitive   = true
  default     = ""
}

# ===== Tags =====

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project = "bagel-store-demo"
  }
}
