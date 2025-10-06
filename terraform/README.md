# Terraform Infrastructure for Bagel Store Demo

Complete AWS infrastructure for the Bagel Store demonstration, supporting multiple concurrent demo instances via unique `demo_id` identifiers.

## Architecture Overview

This Terraform configuration creates:

- **RDS PostgreSQL Instance** - Single instance with 4 databases (dev, test, staging, prod)
- **AWS Secrets Manager** - Database credentials
- **S3 Buckets** - Liquibase flows (public) and operation reports (private)
- **App Runner Services** - 4 services (one per environment) with fixed instance count
- **Route53 DNS** (Optional) - Custom DNS records for all environments
- **Harness Environments** - Automatically configured with AWS infrastructure outputs

## Prerequisites

1. **AWS CLI** configured with credentials (use `aws configure sso` for SSO)
2. **Terraform** >= 1.0
3. **PostgreSQL client** (psql) for database creation
4. **GitHub Personal Access Token** with packages:read scope
5. **Route53 Hosted Zone** (optional - only if you want custom DNS)
6. **Harness Account** with API key (for automatic Harness environment configuration)

## Required Variables

Create a `terraform.tfvars` file with these values:

```hcl
# Demo instance identifier
demo_id = "demo1"

# AWS configuration
aws_region   = "us-east-1"
aws_username = "your-aws-username"

# Database configuration
db_username = "postgres"
db_password = "your-secure-password-here"

# GitHub configuration
github_org = "your-github-org"
github_pat = "ghp_xxxxxxxxxxxxxxxxxxxx"

# DNS configuration (Optional - set enable_route53 = false to skip)
enable_route53 = false
# domain_name      = "bagel-demo.example.com"
# route53_zone_id  = "Z1234567890ABC"

# Harness CD configuration (automatically creates environments with AWS outputs)
harness_account_id  = "your-harness-account-id"
harness_api_key     = "pat.xxxxxxxxxxxxxxxx"
harness_org_id      = "default"
harness_project_id  = "bagel_store_demo"
```

**Tip:** Copy the example file and customize it:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

## Usage

### Initialize Terraform

```bash
cd terraform
terraform init
```

### Plan Infrastructure

```bash
terraform plan \
  -var="demo_id=demo1" \
  -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
```

### Apply Infrastructure

```bash
terraform apply \
  -var="demo_id=demo1" \
  -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
```

### View Outputs

```bash
terraform output
```

### Destroy Infrastructure

When done with the demo, remove all resources:

```bash
terraform destroy \
  -var="demo_id=demo1" \
  -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
```

## Resource Naming Convention

All resources use the pattern: `bagel-store-<demo_id>-<resource-type>`

Examples:
- RDS: `bagel-store-demo1-rds`
- S3 Flow Bucket: `bagel-store-demo1-liquibase-flows`
- S3 Reports Bucket: `bagel-store-demo1-operation-reports`
- App Runner Dev: `bagel-store-demo1-dev`
- DNS (if enabled): `dev-demo1.bagel-demo.example.com`
- App Runner URL (always): `https://xxxxx.us-east-1.awsapprunner.com`

## Multi-Instance Support

To run multiple concurrent demos:

1. Use different `demo_id` values
2. All resources will be tagged and named uniquely
3. No resource conflicts between instances

Example:

```bash
# Demo instance 1
terraform apply -var="demo_id=customer-abc" ...

# Demo instance 2
terraform apply -var="demo_id=eval-2025" ...
```

## Resource Tags

All resources are automatically tagged with:

- `demo_id`: Unique demo identifier
- `deployed_by`: AWS username
- `managed_by`: "terraform"
- `project`: "bagel-store-demo"

## Outputs

After applying, Terraform provides:

### RDS Information
- `rds_endpoint` - Full endpoint with port
- `rds_address` - Address without port
- `jdbc_urls` - JDBC connection strings for all environments

### S3 Buckets
- `liquibase_flows_bucket` - Public bucket for flow files
- `operation_reports_bucket` - Private bucket for CI/CD reports

### App Runner
- `app_runner_services` - Service ARNs and URLs
- `dns_records` - Custom DNS records

### Example Commands
- `liquibase_example_commands` - Ready-to-use Liquibase commands

## Cost Estimates

Running continuously (monthly):
- RDS db.t3.micro: ~$15-20
- App Runner (4 services): ~$20
- Route53: $0.50
- Secrets Manager: ~$2
- S3: Negligible
- **Total: ~$37-42/month**

**Cost Savings:** Run `terraform destroy` after demos to avoid ongoing charges.

## Security Notes

⚠️ **Demo Configuration - Not Production Ready**

- RDS is publicly accessible (demo convenience)
- Security groups allow 0.0.0.0/0 access to PostgreSQL
- No SSL/TLS enforcement
- Single database instance (no high availability)

For production deployments:
- Enable private subnets
- Use VPC peering or PrivateLink
- Enable SSL/TLS
- Configure Multi-AZ
- Implement backup strategies

## Troubleshooting

### Database Creation Fails

If the `null_resource.create_databases` fails:

```bash
# Manually create databases
PGPASSWORD='your-password' psql \
  -h <rds-endpoint> \
  -U postgres \
  -c "CREATE DATABASE dev;"

# Repeat for test, staging, prod
```

### App Runner Services Not Starting

App Runner services initially use a placeholder image. They will be updated with the actual application image during Harness deployment.

### S3 File Upload Fails

Ensure the Liquibase flow files exist before running Terraform:
- `../liquibase-flows/pr-validation-flow.yaml`
- `../liquibase-flows/main-deployment-flow.yaml`
- `../liquibase-flows/liquibase.checks-settings.conf`

## Harness CD Integration

### Automatic Environment Configuration

This Terraform configuration **automatically creates and configures Harness environments** with AWS infrastructure outputs. This eliminates manual configuration and ensures the Harness deployment pipeline always has correct infrastructure details.

**How it works:**

1. Terraform provisions AWS resources (RDS, App Runner, S3, etc.)
2. Terraform **also** creates Harness environments via the Harness Terraform Provider
3. Each environment gets 14 variables populated with AWS resource details
4. Harness pipeline references these via `<+env.variables.variable_name>`

**Environment Variables Created:**

Each of the 4 environments (dev, test, staging, prod) gets these variables:

```yaml
# Database Configuration
rds_endpoint     # Full endpoint (host:port)
rds_address      # Host only
rds_port         # Port number
database_name    # Environment-specific database (dev/test/staging/prod)
jdbc_url         # Complete JDBC connection string

# App Runner Configuration
app_runner_service_arn   # Service ARN for AWS CLI
app_runner_service_url   # Default service URL
app_runner_service_id    # Service ID
app_runner_service_name  # Service name

# S3 Configuration
liquibase_flows_bucket       # Bucket for flow files
operation_reports_bucket     # Bucket for reports

# Demo Configuration
demo_id          # Demo instance identifier
aws_region       # AWS region
environment      # Environment name (dev/test/staging/prod)
dns_record       # DNS record (if Route53 enabled)
```

**Usage in Harness Pipeline:**

Instead of manual runtime inputs, the pipeline uses environment variables:

```yaml
# Liquibase deployment
docker run liquibase/liquibase-secure:5.0.1 \
  --url=<+env.variables.jdbc_url> \
  --username='${awsSecretsManager:<+env.variables.demo_id>/rds/username}' \
  --password='${awsSecretsManager:<+env.variables.demo_id>/rds/password}' \
  update

# App Runner deployment
aws apprunner update-service \
  --service-arn <+env.variables.app_runner_service_arn> \
  --region <+env.variables.aws_region>
```

**Benefits:**

- ✅ Zero manual configuration in Harness
- ✅ Single source of truth (Terraform)
- ✅ No runtime input prompts for infrastructure details
- ✅ Automatic multi-instance support (different `demo_id` = different environments)
- ✅ Infrastructure changes automatically propagate to Harness

**Configuration:**

Set these variables in `terraform.tfvars`:

```hcl
# Find in Harness URL: https://app.harness.io/ng/account/YOUR_ACCOUNT_ID/...
harness_account_id = "your-account-id"

# Create at: Profile → My API Keys → New API Key
# Required scopes: Environment (View, Create/Edit), Project (View)
harness_api_key = "pat.xxxxxxxxxxxxxxxxxxxxxxxx"

# Organization ID (usually "default")
harness_org_id = "default"

# Project ID (create in Harness first, then use identifier here)
harness_project_id = "bagel_store_demo"
```

See `harness-provider.tf` and `harness-environments.tf` for implementation details.

## File Structure

```
terraform/
├── main.tf                   # Provider and local variables
├── variables.tf              # Input variable definitions
├── outputs.tf                # Output definitions
├── rds.tf                    # PostgreSQL RDS instance
├── secrets.tf                # AWS Secrets Manager
├── s3.tf                     # S3 buckets and file uploads
├── app-runner.tf             # App Runner services (4 environments)
├── route53.tf                # DNS records
├── harness-provider.tf       # Harness Terraform Provider configuration
├── harness-environments.tf   # Harness environment creation and configuration
└── README.md                 # This file
```

## Next Steps

After Terraform completes:

1. ✅ **Harness environments are automatically configured** - No manual steps needed!
2. Note the RDS endpoint and other outputs: `terraform output`
3. Configure GitHub Actions secrets with `DEMO_ID` (Harness environments reference this)
4. Create Liquibase changelogs in `db/changelog/`
5. Build and push Docker image to GitHub Container Registry
6. Deploy via Harness pipeline (infrastructure details already configured via environment variables)

## Support

For issues or questions, refer to the main project [requirements-design-plan.md](../requirements-design-plan.md).
