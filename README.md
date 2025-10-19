# Bagel Store Demo: Coordinated Database + Application Deployment

> **Demonstration of coordinated application and database deployments using Harness CD, GitHub Actions, Liquibase, and AWS infrastructure.**

This project showcases a complete CI/CD pipeline that deploys both a Python Flask application and PostgreSQL database changes together through four environments (dev → test → staging → prod), with automated policy checks and manual promotion gates.

## What This Demonstrates

- **Coordinated Deployments**: Application code and database schema changes are versioned and promoted together
- **Automated Governance**: 12 Liquibase policy checks with BLOCKER severity prevent risky database changes
- **Multi-Environment Promotion**: Manual promotion workflow through dev → test → staging → prod via Harness CD
- **Modern CI/CD Patterns**: GitHub Actions for CI, Harness CD for orchestration, Liquibase Flows for database automation
- **AWS Integration**: RDS PostgreSQL, App Runner, S3, Secrets Manager, and Route53
- **Infrastructure as Code**: Complete Terraform configuration for reproducible environments

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Developer Workflow                            │
├──────────────────────────────────────────────────────────────────────┤
│  Create PR → Automated Validation → Merge → CI Build → Deploy Dev    │
│                                                    ↓                  │
│              Manual Promotion: Test → Staging → Prod                 │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────┐         ┌─────────────────┐         ┌──────────────────┐
│  GitHub Actions │────────▶│  Artifact Repos │────────▶│   Harness CD     │
│                 │         │                 │         │                  │
│  • PR Validation│         │  • Docker Image │         │  • Dev (auto)    │
│  • Policy Checks│         │  • DB Changelog │         │  • Test (manual) │
│  • Build & Push │         │                 │         │  • Staging       │
│                 │         │                 │         │  • Prod          │
└─────────────────┘         └─────────────────┘         └──────────────────┘
         │                                                       │
         │                                                       │
         ▼                                                       ▼
┌─────────────────┐                                  ┌──────────────────┐
│   AWS S3        │                                  │   AWS Services   │
│                 │                                  │                  │
│  • Flow Files   │                                  │  • RDS PostgreSQL│
│  • Policy Checks│                                  │  • App Runner    │
│  • Reports      │                                  │  • Route53 DNS   │
└─────────────────┘                                  │  • Secrets Mgr   │
                                                     └──────────────────┘
```

### Key Components

1. **Application**: Python Flask bagel ordering app with PostgreSQL backend
2. **Database**: Liquibase-managed schema with 4 tables (products, inventory, orders, order_items)
3. **CI Pipeline**: GitHub Actions validates PRs, builds artifacts, triggers deployments
4. **CD Pipeline**: Harness orchestrates promotions with manual approval gates
5. **Infrastructure**: AWS resources managed by Terraform (RDS, App Runner, S3, Secrets Manager)

## Quick Start

### Local Development & Testing

Run the complete application stack locally:

```bash
# Navigate to app directory
cd app

# Start application with Docker Compose
docker compose up --build

# Access the application
open http://localhost:5001

# Run automated tests
uv run pytest
```

**Setup Demo Credentials:**

Before running the application, you must configure demo credentials:

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set your demo password:
   ```
   DEMO_USERNAME=demo
   DEMO_PASSWORD=your-secure-password-here
   ```

For detailed testing instructions, see [app/TESTING.md](app/TESTING.md).

## Deployment Modes

This demo supports **two deployment modes** to fit different use cases:

### AWS Mode (Production-like) ☁️

**Infrastructure**: RDS, App Runner, S3, Secrets Manager, Route53

**Best for**:
- Production demonstrations
- AWS integration showcases
- Realistic cloud deployment patterns

**Setup**:
```bash
cd terraform
terraform apply
cd ../harness
docker compose up -d  # Start Harness delegate
# Run pipeline via Harness UI
```

**Cost**: ~$40/month running continuously
**Setup time**: 15-30 minutes

**Cleanup**: `terraform destroy` when done

---

### Local Mode (Fast & Free) 🚀 **NEW**

**Infrastructure**: Docker Compose (8 containers on localhost)

**Best for**:
- Development and testing
- Quick demos
- Offline demonstrations
- Learning Harness CD workflows

**Setup**:
```bash
# 1. Start all 4 environments
cp .env.example .env
docker compose -f docker-compose-demo.yml up -d

# 2. Access environments
open http://localhost:5001  # dev
open http://localhost:5002  # test
open http://localhost:5003  # staging
open http://localhost:5004  # prod

# 3. Configure Harness environments (add variable to each)
#    Variable: DEPLOYMENT_TARGET=local

# 4. Start Harness delegate
cd harness
docker compose up -d

# 5. Run deployment pipeline via Harness UI
```

**Cost**: $0
**Setup time**: 2 minutes

**View state**: `./scripts/deployment/show-deployment-state.sh`

---

### Comparison

| Feature | AWS Mode | Local Mode |
|---------|----------|------------|
| **Database** | RDS PostgreSQL | 4 PostgreSQL containers |
| **Application** | App Runner (4 services) | 4 Flask containers |
| **URLs** | Custom DNS (Route53) | localhost:5001-5004 |
| **Cost** | ~$40/month | $0 |
| **Setup** | 15-30 min | 2 min |
| **Harness Pipeline** | ✅ Same workflow | ✅ Same workflow |
| **Policy Checks** | ✅ All 12 checks | ✅ All 12 checks |
| **Promotions** | ✅ Manual approvals | ✅ Manual approvals |

**Complete local mode guide**: [docs/LOCAL_DEPLOYMENT.md](docs/LOCAL_DEPLOYMENT.md)

## How It Works

### 1. Pull Request Workflow

When a developer creates a PR with database changes:

```
PR Created
    ↓
GitHub Actions Triggers
    ↓
Liquibase Flow Executes:
    • Verify: Connection & syntax validation
    • PolicyChecks: Run 12 BLOCKER-severity checks
    • Report: Upload results to S3 & GitHub
    ↓
✓ Checks Pass → PR can merge
✗ BLOCKER violation → PR blocked
```

**Policy Checks Enforced:**
- Prevent DROP TABLE/COLUMN/TRUNCATE operations
- Require rollback capability on all changesets
- Detect risky permission changes (GRANT/REVOKE)
- Enforce table column limits and indexing
- Flag SELECT * statements

### 2. Main Branch CI/CD

After PR merge to main:

```
Main Branch Updated
    ↓
Parallel Workflows:

[Database Workflow]              [Application Workflow]
• Validate changelog             • Build Docker image
• Run policy checks              • Tag with version
• Create changelog.zip           • Push to ghcr.io
• Upload to GitHub Packages
    ↓                                   ↓
    └───────────────┬───────────────────┘
                    ↓
            Trigger Harness Webhook
                    ↓
        ┌───────────────────────┐
        │  Harness Deployment   │
        │                       │
        │  Dev (Automatic)      │
        │    ↓ manual approval  │
        │  Test                 │
        │    ↓ manual approval  │
        │  Staging              │
        │    ↓ manual approval  │
        │  Prod                 │
        └───────────────────────┘
```

### 3. Deployment to Each Environment

For each environment, Harness executes:

```bash
# 1. Fetch changelog artifact from GitHub Packages
wget github.com/packages/.../changelog.zip

# 2. Update database via Liquibase
docker run liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://rds-endpoint:5432/{env} \
  --username='${awsSecretsManager:demo1/rds/username}' \
  --password='${awsSecretsManager:demo1/rds/password}' \
  update

# 3. Deploy application to App Runner
aws apprunner update-service \
  --service-arn {env-service-arn} \
  --image ghcr.io/{org}/bagel-store:{version}

# 4. Health check
curl https://{env}.bagel-demo.example.com/health
```

## Prerequisites

**First-time setup?** See [SETUP.md](SETUP.md) for complete installation instructions across Windows, macOS, and Linux.

**Quick dependency check:**
```bash
./scripts/setup/check-dependencies.sh
```

### Development

- **Docker Desktop** - For local development and testing
- **Python 3.11+** with [uv](https://docs.astral.sh/uv/) package manager
- **Git** - Version control
- **PostgreSQL client** (psql) - Optional, for database access

### AWS Deployment

- **AWS Account** with appropriate permissions
- **AWS CLI** configured (use `aws configure sso` for SSO)
- **Terraform** >= 1.0
- **GitHub Account** with repository access
- **Harness Account** (Free Edition) - Sign up at [harness.io](https://app.harness.io)

## Deployment Guide

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/harness-gha-bagelstore.git
cd harness-gha-bagelstore
```

### Step 2: Provision AWS Infrastructure

```bash
cd terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
# Required: demo_id, aws_username, db_password, github_org, github_pat
# Optional: enable_route53, domain_name, route53_zone_id

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Create infrastructure
terraform apply
```

**Note the outputs** - you'll need RDS endpoint, S3 bucket names, and App Runner service ARNs.

See [terraform/README.md](terraform/README.md) for detailed infrastructure documentation.

### Step 3: Configure GitHub Secrets

Add these secrets to your GitHub repository:

```
AWS_ACCESS_KEY_ID       - For S3 and Secrets Manager access
AWS_SECRET_ACCESS_KEY   - For S3 and Secrets Manager access
HARNESS_WEBHOOK_URL     - Harness pipeline webhook
DEMO_ID                 - Demo instance identifier (e.g., "demo1")
LIQUIBASE_LICENSE_KEY   - Liquibase Pro/Secure license key
```

### Step 4: Set Up Harness CD

1. **Start Harness Delegate** (local Docker Compose):
   ```bash
   cd harness
   docker compose up -d
   ```

2. **Create Pipeline** in Harness UI:
   - Use "Remote" pipeline type
   - Point to `harness/pipelines/deploy-pipeline.yaml` in Git repository
   - Configure connectors (GitHub, AWS)

3. **Configure Secrets** in Harness:
   - `AWS_ACCESS_KEY` - AWS credentials for deployments
   - `AWS_SECRET_KEY` - AWS credentials for deployments
   - `GITHUB_PAT` - GitHub Personal Access Token (packages:read scope)

See [harness/README.md](harness/README.md) for detailed Harness configuration.

### Step 5: Create Database Schema

```bash
cd db/changelog

# Review the master changelog and changesets
cat changelog-master.yaml
ls -la changesets/

# Test locally (optional)
docker run --rm \
  -v $(pwd):/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://localhost:5432/dev \
  --username=postgres \
  --password=yourpassword \
  --changeLogFile=changelog-master.yaml \
  validate
```

See [db/changelog/README.md](db/changelog/README.md) for changelog patterns.

### Step 6: Trigger First Deployment

```bash
# Create a git tag for versioning
git tag v1.0.0
git push origin v1.0.0

# Push to main branch
git push origin main

# This triggers:
# 1. GitHub Actions builds artifacts
# 2. Harness deploys to dev automatically
# 3. Manual promotions available for test/staging/prod
```

## Demo Walkthrough

### Scenario: Add a New Bagel Type

1. **Create Feature Branch:**
   ```bash
   git checkout -b feature/add-sesame-bagel
   ```

2. **Add Database Changeset:**
   ```bash
   # Create new changeset file
   cat > db/changelog/changesets/004-add-sesame-bagel.sql << 'EOF'
   --liquibase formatted sql
   --changeset demo:004-add-sesame-bagel

   INSERT INTO products (name, description, price)
   VALUES ('Sesame', 'Classic bagel topped with sesame seeds', 2.75);

   INSERT INTO inventory (product_id, quantity)
   VALUES ((SELECT id FROM products WHERE name = 'Sesame'), 50);

   --rollback DELETE FROM inventory WHERE product_id = (SELECT id FROM products WHERE name = 'Sesame');
   --rollback DELETE FROM products WHERE name = 'Sesame';
   EOF

   # Reference in master changelog
   # Add to db/changelog/changelog-master.yaml
   ```

3. **Create Pull Request:**
   ```bash
   git add db/changelog/
   git commit -m "Add Sesame bagel product"
   git push origin feature/add-sesame-bagel

   # Create PR in GitHub UI
   ```

4. **Automated Validation:**
   - GitHub Actions runs `pr-validation-flow.yaml`
   - Liquibase validates syntax and runs 12 policy checks
   - Policy report uploaded to S3 and GitHub Actions artifacts
   - PR status updated (✓ or ✗)

5. **Merge and Deploy:**
   ```bash
   # After PR approval and merge
   # GitHub Actions automatically:
   # - Builds changelog artifact
   # - Builds Docker image
   # - Triggers Harness deployment to dev
   ```

6. **Promote Through Environments:**
   - Access Harness UI
   - Review dev deployment
   - Click "Approve" to promote to test
   - Repeat for staging and prod

## Project Structure

```
harness-gha-bagelstore/
├── app/                          # Flask application
│   ├── src/                      # Application source code
│   │   ├── app.py                # Flask app factory
│   │   ├── routes.py             # Route handlers
│   │   ├── models.py             # Data models
│   │   ├── database.py           # Database utilities
│   │   └── templates/            # Jinja2 HTML templates
│   ├── tests/                    # Automated tests (pytest + Playwright)
│   ├── Dockerfile                # Container image definition
│   ├── docker-compose.yml        # Local development environment
│   ├── pyproject.toml            # Python dependencies (PEP 621)
│   └── README.md                 # Application documentation
│
├── db/
│   └── changelog/
│       ├── changelog-master.yaml # Master changelog (YAML format)
│       └── changesets/           # SQL changesets (formatted SQL)
│
├── terraform/                    # AWS infrastructure as code
│   ├── main.tf                   # Provider configuration
│   ├── rds.tf                    # PostgreSQL RDS instance
│   ├── s3.tf                     # S3 buckets
│   ├── secrets.tf                # AWS Secrets Manager
│   ├── app-runner.tf             # App Runner services
│   ├── route53.tf                # DNS records (optional)
│   └── README.md                 # Infrastructure documentation
│
├── harness/
│   ├── pipelines/
│   │   └── deploy-pipeline.yaml  # Harness CD pipeline definition
│   └── docker-compose.yml        # Harness Delegate
│
├── liquibase-flows/
│   ├── pr-validation-flow.yaml   # PR validation flow
│   ├── main-deployment-flow.yaml # Main branch deployment flow
│   ├── liquibase.checks-settings.conf # Policy checks (12 BLOCKER checks)
│   └── README.md                 # Flow documentation
│
├── .github/workflows/
│   ├── pr-validation.yml         # PR validation workflow
│   ├── main-ci.yml               # Main branch CI (database)
│   └── app-ci.yml                # Application CI
│
├── CLAUDE.md                     # AI assistant instructions
├── requirements-design-plan.md   # Complete system design
└── README.md                     # This file
```

## Key Technologies

### Application Stack
- **[Python 3.11](https://www.python.org/)** - Programming language
- **[Flask](https://flask.palletsprojects.com/)** - Web framework
- **[uv](https://docs.astral.sh/uv/)** - Fast Python package manager (replaces pip)
- **[PostgreSQL](https://www.postgresql.org/)** - Relational database
- **[Docker](https://www.docker.com/)** - Containerization

### CI/CD & Database Management
- **[GitHub Actions](https://docs.github.com/actions)** - Continuous integration
- **[Harness CD](https://www.harness.io/)** - Deployment orchestration
- **[Liquibase Secure 5.0.1](https://www.liquibase.com/)** - Database change management
- **[Terraform](https://www.terraform.io/)** - Infrastructure as code

### AWS Services
- **[RDS PostgreSQL](https://aws.amazon.com/rds/postgresql/)** - Managed database
- **[App Runner](https://aws.amazon.com/apprunner/)** - Container hosting
- **[S3](https://aws.amazon.com/s3/)** - Object storage (flows, reports)
- **[Secrets Manager](https://aws.amazon.com/secrets-manager/)** - Credential management
- **[Route53](https://aws.amazon.com/route53/)** - DNS management

### Testing
- **[pytest](https://pytest.org/)** - Python testing framework
- **[Playwright](https://playwright.dev/)** - Browser automation for E2E tests

## Troubleshooting

### Common Issues

**Port 5000 already in use on macOS**
- The application uses port 5001 externally to avoid conflicts with macOS AirPlay Receiver
- Access at `http://localhost:5001` instead of 5000

**Docker containers not starting**
```bash
# Check service status
docker compose ps

# View logs
docker compose logs app
docker compose logs postgres

# Restart services
docker compose restart
```

**Terraform apply fails**
- Ensure AWS CLI is configured: `aws sts get-caller-identity`
- Check that required IAM permissions are granted
- Verify `terraform.tfvars` has all required variables

**GitHub Actions workflow fails**
- Verify all GitHub Secrets are configured
- Check that Liquibase license key is valid
- Review workflow logs in GitHub Actions tab

**Harness deployment fails**
- Ensure Harness Delegate is running: `docker compose ps` in `harness/` directory
- Verify AWS credentials are configured in Harness secrets
- Check that GitHub PAT has `packages:read` scope

**Tests failing after template changes**
- Templates are baked into Docker images at build time
- Rebuild without cache: `docker compose build --no-cache`
- See [app/TESTING.md](app/TESTING.md) for detailed troubleshooting

### Getting Help

- Review detailed documentation in subdirectory README files
- Check [requirements-design-plan.md](requirements-design-plan.md) for complete system design
- Review [CLAUDE.md](CLAUDE.md) for development patterns and best practices

## Environment-Specific URLs

After deployment, access your environments:

**With Route53 DNS (if `enable_route53 = true`):**
- Dev: `https://dev-{demo_id}.{domain_name}`
- Test: `https://test-{demo_id}.{domain_name}`
- Staging: `https://staging-{demo_id}.{domain_name}`
- Prod: `https://prod-{demo_id}.{domain_name}`

**Without Route53 DNS (default):**
- App Runner provides default URLs shown in Terraform outputs
- Example: `https://abc123xyz.us-east-1.awsapprunner.com`

## Security Notes

⚠️ **This is a demonstration environment, not production-ready:**

- RDS is publicly accessible for demo convenience
- No SSL/TLS enforcement on database connections
- Single-database instance (no high availability)
- Hardcoded demo user credentials
- Public Docker images on GitHub Container Registry

**For production deployments:**
- Use private subnets and VPC peering
- Enable SSL/TLS for all connections
- Implement Multi-AZ for RDS
- Use proper authentication and authorization
- Store images in private registries
- Enable automated backups and disaster recovery

## What's Next?

### Extending This Demo

- **Add monitoring**: Integrate with CloudWatch, DataDog, or New Relic
- **Implement rollbacks**: Add rollback capabilities to Harness pipelines
- **Add more checks**: Customize Liquibase policy checks for your governance needs
- **Multi-region**: Extend Terraform to deploy across multiple AWS regions
- **Additional environments**: Add QA, UAT, or performance testing environments

### Learning Resources

- [Liquibase Flow Documentation](https://docs.liquibase.com/commands/flow/home.html)
- [Harness CD Documentation](https://developer.harness.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/actions)

---

**Built with modern DevOps practices for coordinated database and application deployments.**
