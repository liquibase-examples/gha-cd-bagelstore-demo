# Terraform Infrastructure for Bagel Store Demo

Complete AWS infrastructure for the Bagel Store demonstration, supporting multiple concurrent demo instances via unique `demo_id` identifiers.

## Architecture Overview

This Terraform configuration creates:

- **RDS PostgreSQL Instance** - Single instance with 4 databases (dev, test, staging, prod)
- **AWS Secrets Manager** - Database credentials
- **S3 Buckets** - Liquibase flows (public) and operation reports (private)
- **App Runner Services** - 4 services (one per environment) with fixed instance count
- **Route53 DNS** (Optional) - Custom DNS records for all environments

## Prerequisites

1. **AWS CLI** configured with credentials (use `aws configure sso` for SSO)
2. **Terraform** >= 1.0
3. **PostgreSQL client** (psql) for database creation
4. **GitHub Personal Access Token** with packages:read scope
5. **Route53 Hosted Zone** (optional - only if you want custom DNS)

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

## File Structure

```
terraform/
├── main.tf              # Provider and local variables
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output definitions
├── rds.tf              # PostgreSQL RDS instance
├── secrets.tf          # AWS Secrets Manager
├── s3.tf               # S3 buckets and file uploads
├── app-runner.tf       # App Runner services (4 environments)
├── route53.tf          # DNS records
└── README.md           # This file
```

## Next Steps

After Terraform completes:

1. Note the RDS endpoint from outputs
2. Configure GitHub Actions secrets with RDS endpoint and demo_id
3. Create Liquibase changelogs in `db/changelog/`
4. Build and push Docker image to GitHub Container Registry
5. Configure Harness CD pipeline with service ARNs

## Support

For issues or questions, refer to the main project [requirements-design-plan.md](../requirements-design-plan.md).
