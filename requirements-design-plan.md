# Harness CD + Liquibase Database Deployment Demo
## Requirements & System Design Document

---

## 1. Executive Summary

This document defines the requirements and system design for a demonstration showcasing coordinated application and database deployments across multiple environments using GitHub, GitHub Actions, Liquibase, and Harness CD Free Edition.

**Primary Goal:** Demonstrate how a database changelog and application are promoted together from development through production using Harness CD orchestration.

**Target Audience:** Customer evaluation of Harness CD capabilities for database and application deployment automation.

**Key Technologies:** GitHub, GitHub Actions, Liquibase Secure 5.0.1, Harness CD Free Edition, PostgreSQL, AWS (RDS, App Runner, Route53, S3, Secrets Manager), Terraform, Python/Flask, Docker.

**Pattern Reference:** This implementation leverages proven patterns from ../liquibase-patterns repository, specifically:
- ../liquibase-patterns/repos/postgres-flow-policy-demo: Flow automation with policy checks and operation reports
- ../liquibase-patterns/repos/dbt-example: GitHub Actions integration with setup-liquibase@v1
- ../liquibase-patterns/repos/Liquibase-workshop-repo: PostgreSQL schema management and AWS integration

---

## 2. Objectives

### 2.1 Primary Objectives
- Demonstrate coordinated deployment of application code and database schema changes
- Show promotion workflow through four environments: dev, test, staging, prod
- Illustrate Harness CD orchestration capabilities with AWS infrastructure
- Demonstrate CI/CD best practices with Liquibase policy checks and validation
- Showcase Liquibase integration with AWS services (S3, Secrets Manager)

### 2.2 Success Criteria
- Developer can submit PR that triggers automated Liquibase validation and policy checks
- Upon merge, CI builds artifacts and Harness deploys to dev automatically
- Harness CD can promote both app and database changes together to test, staging, and prod
- All environments remain functional throughout the demo
- Demo can be instantiated multiple times concurrently for different users using unique demo_id
- Infrastructure can be destroyed and recreated via Terraform
- Policy checks enforce governance with BLOCKER severity

---

## 3. Demo Instance Identification

### 3.1 Demo ID
**Parameter:** `demo_id` (string)

**Purpose:** Unique identifier for each demo instance to prevent conflicts when running multiple concurrent demos.

**Format:** Lowercase alphanumeric with hyphens (e.g., `demo1`, `customer-abc`, `eval-2025`)

**Usage:** Used in all resource names, DNS records, secrets, tags, and Docker image names.

**Examples:**
- RDS instance: `bagel-store-<demo_id>-rds`
- Docker image: `ghcr.io/<org>/<demo_id>-bagel-store:v1.0.0`
- DNS: `dev-<demo_id>.bagel-demo.example.com`
- S3 bucket: `bagel-store-<demo_id>-liquibase-flows`
- Secrets: `<demo_id>/rds/username`, `<demo_id>/rds/password`

---

## 4. Environments

### 4.1 Environment Definitions

| Environment | Purpose | Deployment Trigger |
|-------------|---------|-------------------|
| dev | Development integration | Automatic on merge to main |
| test | QA and testing | Manual promotion via Harness |
| staging | Pre-production validation | Manual promotion via Harness |
| prod | Production | Manual promotion via Harness |

### 4.2 Environment Configuration
- Each environment has its own PostgreSQL database on a single RDS instance
- Each environment has its own App Runner service (fixed instance count, no auto-scaling)
- Each environment has its own Route53 DNS record
- All environments use the same versioned artifacts (Docker image + changelog zip)

---

## 5. Application Requirements

### 5.1 Application Description
**Type:** Bagel Store Ordering Application

**Features:**
- Product catalog (5 types of bagels)
- Inventory tracking
- Order placement and tracking
- Single user authentication (hardcoded credentials)

**Technology Stack:**
- Language: Python 3.11+
- Framework: Flask (most common Python web framework)
- Database: PostgreSQL via psycopg2
- Dependency Management: uv (modern, fast Python package installer)
- Containerization: Docker image for deployment

### 5.2 Database Schema Requirements

**Tables Required:**
- `products` - Bagel types and descriptions
- `inventory` - Current stock levels per product
- `orders` - Customer orders
- `order_items` - Line items for each order

**No user management table** - single hardcoded user for authentication.

### 5.3 Data Model
- Products have: id, name, description, price
- Inventory has: product_id, quantity, last_updated
- Orders have: id, order_date, total_amount, status
- Order_items have: order_id, product_id, quantity, price

### 5.4 Authentication
- Single user with hardcoded username and password
- Basic session-based authentication
- No HTTPS required (HTTP only for demo simplicity)

---

## 6. Liquibase Patterns & Best Practices

### 6.1 Key Learnings from ../liquibase-patterns Repository

Based on analysis of proven implementation patterns from ../liquibase-patterns, the following best practices MUST be followed:

#### GitHub Actions Configuration
- **ALWAYS use `liquibase/setup-liquibase@v1`** - deprecated versions cause failures
- **Minimum Liquibase version: 4.32.0** - earlier versions (4.29.0) fail with "Version not supported"
- **Set `edition: 'secure'`** in setup-liquibase action for Flow and policy check features
- **Use `actions/checkout@v4`** - v3 is deprecated
- **Use `actions/upload-artifact@v4`** - v3 causes workflow failures

#### Environment Variables (Critical)
- **Use `LIQUIBASE_COMMAND_*` environment variables** - custom property substitution (`${VARIABLE}`) does NOT work reliably in GitHub Actions
- **Required variables for all workflows:**
  ```yaml
  LIQUIBASE_COMMAND_URL: jdbc:postgresql://host:5432/database
  LIQUIBASE_COMMAND_USERNAME: username
  LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.PASSWORD }}
  LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
  ```
- **Never mix approaches** - use EITHER properties files OR command variables, not both

#### Flow File Structure
Based on postgres-flow-policy-demo pattern:
- **Structured stages:** Verify → PolicyChecks → Deploy → Validation
- **Always include endStage** for cleanup and summary reporting
- **Enable operation reports:** `reports-enabled: true` with dedicated reports/ directory
- **Use YAML for changelogs** (not XML) - modern best practice
- **Reference formatted SQL changesets** from dedicated changesets/ directory

#### Policy Checks Integration
- **Integrate within flow files** using `liquibase checks run` command
- **Set severity to BLOCKER** for governance enforcement (exit code 4)
- **Generate HTML reports** for PR/build artifacts
- **Scope:** `checks-scope: "changelog, database"` for comprehensive validation

### 6.2 Pattern Application to This Project

**From postgres-flow-policy-demo:**
- Flow structure with Verify, PolicyChecks, Deploy, and Validation stages
- Operation report generation in reports/ directory
- Rollback testing via `update-testing-rollback` command

**From dbt-example:**
- GitHub Actions workflow structure with proper action versions
- LIQUIBASE_COMMAND_* environment variable usage
- Artifact upload patterns with v4 actions

**From Liquibase-workshop-repo:**
- PostgreSQL schema management patterns
- AWS Secrets Manager integration
- Multi-database architecture patterns

---

## 7. Repository Structure

### 7.1 Repository Organization
**Single Repository** containing both application code and database changelog.

```
bagel-store-demo/
├── .github/
│   └── workflows/
│       ├── pr-validation.yml          # PR CI pipeline
│       ├── main-ci.yml                # Main branch CI pipeline
│       └── app-ci.yml                 # Application CI pipeline
├── app/
│   ├── src/
│   │   ├── app.py                     # Flask application
│   │   ├── models.py                  # Database models
│   │   ├── routes.py                  # API routes
│   │   └── templates/                 # HTML templates
│   ├── Dockerfile                     # Application Docker image
│   ├── pyproject.toml                 # Python project metadata and dependencies (PEP 621)
│   ├── uv.lock                        # Locked dependency versions
│   └── README.md
├── db/
│   ├── changelog/
│   │   ├── changelog-master.yaml      # Master changelog file (YAML format)
│   │   ├── changesets/                # Individual changesets (SQL format)
│   │   │   ├── 001-initial-schema.sql
│   │   │   ├── 002-seed-data.sql
│   │   │   └── ...
│   │   └── README.md
│   └── liquibase.properties           # Liquibase base configuration
├── terraform/
│   ├── main.tf                        # Main Terraform configuration
│   ├── variables.tf                   # Variable definitions
│   ├── outputs.tf                     # Output definitions
│   ├── rds.tf                         # RDS instance configuration
│   ├── s3.tf                          # S3 bucket for flow files
│   ├── secrets.tf                     # AWS Secrets Manager
│   ├── route53.tf                     # DNS configuration
│   ├── app-runner.tf                  # App Runner services (4 environments)
│   └── README.md
├── harness/
│   ├── pipelines/
│   │   ├── deploy-pipeline.yaml       # Main deployment pipeline
│   │   └── README.md
│   ├── docker-compose.yml             # Harness Delegate
│   └── README.md
├── liquibase-flows/
│   ├── pr-validation-flow.yaml        # PR validation flow
│   ├── main-deployment-flow.yaml      # Main branch deployment flow
│   ├── liquibase.checks-settings.conf # Policy checks configuration
│   └── README.md                      # Flow file documentation
└── README.md                          # Main repository README
```

---

## 7. CI/CD Workflow Requirements

### 7.1 Development Workflow (Outside Demo Scope)
Developer uses Liquibase IDE extension for VS Code to develop changesets locally. This is external to the demo repository and not included in implementation.

### 7.2 Pull Request Workflow

**Trigger:** Pull request opened or updated

**GitHub Actions Job: PR Validation**

**Steps:**
1. Checkout code using `actions/checkout@v4`
2. Setup Liquibase using `liquibase/setup-liquibase@v1` action:
   ```yaml
   - uses: liquibase/setup-liquibase@v1
     with:
       version: '4.32.0'
       edition: 'secure'
   ```
3. Configure AWS credentials for S3 and Secrets Manager access
4. Execute Liquibase flow with environment variables:
   ```yaml
   env:
     LIQUIBASE_COMMAND_URL: jdbc:postgresql://<rds-endpoint>:5432/dev
     LIQUIBASE_COMMAND_USERNAME: postgres
     LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
     LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
   run: liquibase flow --flow-file=liquibase-flows/pr-validation-flow.yaml
   ```
5. Flow executes (downloaded from S3 via Liquibase):
   - Verify: Connection validation and changelog syntax check
   - PolicyChecks: Run policy checks with BLOCKER severity
   - Generate HTML operation reports in reports/ directory
6. Upload policy check report to S3 (organized by PR number and run ID)
7. Upload reports as GitHub Actions artifact using `actions/upload-artifact@v4`
8. Add PR validation summary to GitHub workflow summary via `$GITHUB_STEP_SUMMARY`
9. Report status back to PR (pass/fail)

**Success Criteria:** PR can be merged if validation passes (no BLOCKER violations).

**Key Pattern:** All database credentials via LIQUIBASE_COMMAND_* variables (no property file substitution).

### 7.3 Main Branch CI Workflow

**Trigger:** Push to main branch (after PR merge)

**GitHub Actions Job: Main CI - Database**

**Steps:**
1. Checkout code using `actions/checkout@v4`
2. Setup Liquibase using `liquibase/setup-liquibase@v1`:
   ```yaml
   - uses: liquibase/setup-liquibase@v1
     with:
       version: '4.32.0'
       edition: 'secure'
   ```
3. Configure AWS credentials using `aws-actions/configure-aws-credentials@v4`
4. Execute Liquibase flow with LIQUIBASE_COMMAND_* environment variables:
   ```yaml
   env:
     LIQUIBASE_COMMAND_URL: jdbc:postgresql://<rds-endpoint>:5432/dev
     LIQUIBASE_COMMAND_USERNAME: postgres
     LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
     LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
   run: liquibase flow --flow-file=liquibase-flows/main-deployment-flow.yaml
   ```
5. Flow executes stages:
   - Verify: Connection and syntax validation
   - PolicyChecks: Run policy checks with BLOCKER severity
   - CreateArtifact: Package changelog as zip file
6. Upload changelog zip to GitHub Packages with version tag
7. Upload operation reports to S3 using AWS CLI:
   ```bash
   aws s3 cp reports/ s3://bagel-store-${{ vars.DEMO_ID }}-operation-reports/reports/${{ github.run_number }}/ --recursive
   ```
8. Upload reports as GitHub Actions artifact using `actions/upload-artifact@v4`
9. Trigger Harness deployment to dev environment via webhook

**Key Pattern:** Flow file references S3-hosted policy checks via `s3://` URLs in flow stages.

### 7.4 Application CI Workflow

**Trigger:** Push to main branch when app code changes

**GitHub Actions Job: App CI**

**Steps:**
1. Checkout code
2. Extract version from git tag
3. Build Docker image for application
4. Tag image with version: `ghcr.io/<org>/<demo_id>-bagel-store:<version>`
5. Push image to GitHub Container Registry (ghcr.io)
6. Trigger Harness deployment (if needed) via webhook

### 7.5 Versioning Strategy

**Version Source:** Git tags (e.g., `v1.0.0`, `v1.1.0`)

**Artifact Tagging:**
- Docker images tagged with git tag version
- Changelog zip artifacts tagged with git tag version
- Both artifacts reference the same version for coordinated deployment

**Tagging Process:**
- Developer creates git tag on main branch
- CI detects tag and builds versioned artifacts
- Harness references version tag when deploying

---

## 8. Liquibase Policy Checks Configuration

### 8.1 Policy Checks File
**File:** `liquibase.checks-settings.conf`

**Location:** S3 bucket (uploaded via Terraform)

**S3 Path:** `s3://bagel-store-<demo_id>-liquibase-flows/liquibase.checks-settings.conf`

### 8.2 Enabled Policy Checks (All BLOCKER Severity)

The following 12 policy checks are configured with **BLOCKER** severity (exit code 4):

1. **ChangeDropColumnWarn** - Prevents dropping columns
2. **ChangeDropTableWarn** - Prevents dropping tables
3. **ChangeTruncateTableWarn** - Prevents truncating tables
4. **CheckTablesForIndex** - Ensures tables have appropriate indexes
5. **ModifyDataTypeWarn** - Warns on data type modifications
6. **RollbackRequired** - Ensures changesets have rollback capability
7. **SqlGrantAdminWarn** - Detects GRANT statements with ADMIN OPTION
8. **SqlGrantOptionWarn** - Detects GRANT statements with GRANT OPTION
9. **SqlGrantWarn** - Detects GRANT statements
10. **SqlRevokeWarn** - Detects REVOKE statements
11. **SqlSelectStarWarn** - Detects SELECT * statements
12. **TableColumnLimit** - Enforces maximum column count per table (50 columns)

### 8.3 Severity Configuration
**Severity Level:** BLOCKER (exit code: 4)

**Impact:** Any violation of these checks will cause the CI pipeline to fail, preventing merge/deployment.

**Reference in Flow Files:** 
```yaml
--checks-settings-file: s3://bagel-store-<demo_id>-liquibase-flows/liquibase.checks-settings.conf
```

---

## 9. Harness CD Requirements

### 9.1 Harness Edition
- **Edition:** Harness Free Edition (SaaS)
- **Access:** https://app.harness.io
- **Authentication:** GitHub OAuth or email/password

### 9.2 Harness Delegate
- **Deployment:** Docker Compose (managed locally)
- **Location:** Developer laptop
- **Configuration File:** `harness/docker-compose.yml`
- **Purpose:** Execute deployment commands with access to AWS resources
- **Network Access:** Public internet access for RDS and App Runner deployments

**Docker Compose Configuration:**
```yaml
version: '3'
services:
  harness-delegate:
    image: harness/delegate:latest
    container_name: harness-delegate-<demo_id>
    restart: unless-stopped
    environment:
      - DELEGATE_NAME=<demo_id>-delegate
      - ACCOUNT_ID=<harness-account-id>
      - DELEGATE_TOKEN=<delegate-token>
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

### 9.3 Harness Connectors

**Required Connectors:**
1. **GitHub Connector** - Access GitHub Packages for changelog artifacts
   - Authentication: Personal Access Token with packages:read scope
2. **AWS Connector** - Access AWS resources
   - Authentication: AWS Access Key/Secret Key (stored in Harness secrets)

**Note:** Docker images are pulled from **public** GitHub Container Registry (ghcr.io), so no Docker Registry Connector is needed.

### 9.4 Harness Pipeline Configuration

**Storage Method:** Remote (stored in Git repository)

**Pipeline File:** `harness/pipelines/deploy-pipeline.yaml`

**Configuration as Code:** YAML-based pipeline definition stored in Git, referenced by Harness using Remote pipeline option.

**Pipeline Name:** Deploy Bagel Store - <demo_id>

**Pipeline Stages:**

1. **Stage: Deploy to Dev**
   - Trigger: Automatic (webhook from GitHub Actions)
   - Steps:
     - Fetch changelog zip from GitHub Packages
     - Fetch Docker image from GitHub Container Registry
     - Execute Liquibase update on dev database (using shell script with Docker)
     - Deploy application to App Runner dev service
   
2. **Stage: Deploy to Test**
   - Trigger: Manual approval
   - Steps: Same as dev, targeting test environment
   
3. **Stage: Deploy to Staging**
   - Trigger: Manual approval
   - Steps: Same as dev, targeting staging environment
   
4. **Stage: Deploy to Prod**
   - Trigger: Manual approval
   - Steps: Same as dev, targeting prod environment

### 9.5 Liquibase Execution in Harness

**Execution Method:** Shell Script step using Docker container

**Docker Image:** `liquibase/liquibase-secure:5.0.1`

**AWS Integration:**
- Liquibase reads credentials from AWS Secrets Manager
- Liquibase downloads flow files and policy checks from S3
- Native integration using AWS SDK

**Script Pattern:**
```bash
# Fetch changelog from GitHub Packages
wget <github-packages-url>/bagel-store-changelog-${VERSION}.zip
unzip bagel-store-changelog-${VERSION}.zip -d /tmp/changelog

# Run Liquibase with AWS Secrets Manager integration
docker run --rm \
  -v /tmp/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_REGION=${AWS_REGION} \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://<rds-endpoint>:5432/<db-name> \
  --username='${awsSecretsManager:<demo_id>/rds/username}' \
  --password='${awsSecretsManager:<demo_id>/rds/password}' \
  --changeLogFile=changelog-master.xml \
  update
```

**Environment-Specific Variables:**
- RDS endpoint (from Terraform outputs)
- Database name (dev/test/staging/prod)
- AWS region
- AWS credentials (for Secrets Manager access)

### 9.6 App Runner Deployment in Harness

**Deployment Method:** AWS CLI commands in shell script step

**Script Pattern:**
```bash
aws apprunner update-service \
  --service-arn <service-arn> \
  --source-configuration ImageRepository={
    ImageIdentifier=ghcr.io/<org>/<demo_id>-bagel-store:<version>,
    ImageRepositoryType=ECR_PUBLIC,
    ImageConfiguration={
      Port=5000,
      RuntimeEnvironmentVariables={
        DATABASE_URL=postgresql://${awsSecretsManager:<demo_id>/rds/username}:${awsSecretsManager:<demo_id>/rds/password}@<rds>:5432/<db>
      }
    }
  }
```

---

## 10. Infrastructure Requirements

### 10.1 AWS Resources

**Management:** All AWS resources managed via Terraform

**Tagging:** All resources tagged with:
- `demo_id`: The unique demo identifier
- `deployed_by`: AWS username of person deploying
- `managed_by`: "terraform"
- `project`: "bagel-store-demo"

**Resource List:**

1. **RDS PostgreSQL Instance**
   - Name: `bagel-store-<demo_id>-rds`
   - Engine: PostgreSQL (latest version)
   - Instance class: db.t3.micro (minimal cost)
   - Storage: 20GB gp2
   - Public accessibility: Enabled
   - Databases: 4 (dev, test, staging, prod)
   - Security group: Allow port 5432 from 0.0.0.0/0 (public demo)
   - Backup retention: 1 day
   - Multi-AZ: Disabled (cost savings)
   - Tags: Include demo_id and deployed_by

2. **S3 Bucket**
   - Name: `bagel-store-<demo_id>-liquibase-flows`
   - Purpose: Store Liquibase flow YAML files and policy checks configuration
   - Public access: Enabled (read-only)
   - Versioning: Enabled
   - Contents (uploaded via Terraform):
     - `pr-validation-flow.yaml`
     - `main-deployment-flow.yaml`
     - `liquibase.checks-settings.conf`
   - Tags: Include demo_id and deployed_by

3. **S3 Bucket for Operation Reports**
   - Name: `bagel-store-<demo_id>-operation-reports`
   - Purpose: Store Liquibase operation reports from CI/CD
   - Public access: Disabled (private)
   - Structure: `reports/<github-run-number>/operation-report.html`
   - Lifecycle: Delete after 30 days
   - Tags: Include demo_id and deployed_by

4. **AWS Secrets Manager**
   - Secrets:
     - `<demo_id>/rds/username` - RDS master username
     - `<demo_id>/rds/password` - RDS master password
   - Access: Accessible by Liquibase and App Runner via IAM
   - Tags: Include demo_id and deployed_by

5. **App Runner Services (4 instances)**
   - Service names:
     - `bagel-store-<demo_id>-dev`
     - `bagel-store-<demo_id>-test`
     - `bagel-store-<demo_id>-staging`
     - `bagel-store-<demo_id>-prod`
   - Source: **Public** container image from GitHub Container Registry (ghcr.io)
   - Image: `ghcr.io/<org>/<demo_id>-bagel-store:<version>`
   - Authentication: **None required** (public images)
   - CPU: 1 vCPU
   - Memory: 2GB
   - Port: 5000
   - Auto-scaling: **Disabled** (fixed instance count: 1)
   - Health check: HTTP GET /health
   - Environment variables:
     - `DATABASE_URL` (using AWS Secrets Manager reference)
     - `FLASK_ENV`
   - Tags: Include demo_id, deployed_by, and environment

6. **Route53 Hosted Zone & Records**
   - Hosted zone: Existing parent domain in AWS account
   - A records:
     - `dev-<demo_id>.bagel-demo.example.com` → App Runner dev
     - `test-<demo_id>.bagel-demo.example.com` → App Runner test
     - `staging-<demo_id>.bagel-demo.example.com` → App Runner staging
     - `prod-<demo_id>.bagel-demo.example.com` → App Runner prod
   - Record type: CNAME to App Runner default domain
   - Tags: Include demo_id and deployed_by

### 10.2 Terraform Configuration

**State Management:** Local state file (for demo simplicity)

**Variable Requirements:**
- `demo_id` - Unique identifier for this demo instance (string, required)
- `aws_region` - AWS region (default: us-east-1)
- `aws_username` - AWS username for tagging (required, for deployed_by tag)
- `db_username` - RDS master username
- `db_password` - RDS master password (sensitive)
- `domain_name` - Base domain for Route53 records
- `github_org` - GitHub organization name

**Outputs Required:**
- RDS endpoint
- RDS database names (dev, test, staging, prod)
- App Runner service URLs
- S3 bucket names
- Route53 DNS names
- Secrets Manager secret ARNs

**Resource Naming Convention:**
- All resources include demo_id to avoid conflicts
- Example: `bagel-store-demo1-rds`, `bagel-store-demo1-dev-apprunner`

**S3 File Uploads via Terraform:**
```hcl
resource "aws_s3_object" "pr_validation_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "pr-validation-flow.yaml"
  source = "${path.module}/../liquibase-flows/pr-validation-flow.yaml"
  etag   = filemd5("${path.module}/../liquibase-flows/pr-validation-flow.yaml")
}

resource "aws_s3_object" "main_deployment_flow" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "main-deployment-flow.yaml"
  source = "${path.module}/../liquibase-flows/main-deployment-flow.yaml"
  etag   = filemd5("${path.module}/../liquibase-flows/main-deployment-flow.yaml")
}

resource "aws_s3_object" "policy_checks_config" {
  bucket = aws_s3_bucket.liquibase_flows.id
  key    = "liquibase.checks-settings.conf"
  source = "${path.module}/../liquibase-flows/liquibase.checks-settings.conf"
  etag   = filemd5("${path.module}/../liquibase-flows/liquibase.checks-settings.conf")
}
```

### 10.3 Multi-Instance Support

**Requirement:** Support multiple concurrent demo instances

**Implementation:**
- Each demo instance uses a unique `demo_id` variable
- All AWS resources include demo_id in name/tags
- Separate Terraform state files per demo instance (using workspaces or separate state files)
- No resource conflicts between instances

**Cleanup:**
- `terraform destroy -var="demo_id=<id>"` removes all resources for an instance
- No manual cleanup required

---

## 11. Artifact Management

### 11.1 Docker Images (Application)

**Registry:** GitHub Container Registry (ghcr.io)

**Visibility:** **Public** (no authentication required for pulling)

**Naming Convention:** `ghcr.io/<github-org>/<demo_id>-bagel-store:<version>`

**Example:** `ghcr.io/myorg/demo1-bagel-store:v1.0.0`

**Storage:** GitHub Container Registry (free for public repos)

**Retention:** Indefinite (manual cleanup if needed)

### 11.2 Changelog Artifacts

**Format:** ZIP file containing all changelog XML files

**Storage:** GitHub Packages (generic packages)

**Naming Convention:** `bagel-store-<demo_id>-changelog-<version>.zip`

**Contents:**
- `changelog-master.xml`
- All changeset XML files
- `liquibase.properties` template

**Retention:** Indefinite (GitHub Packages retention)

### 11.3 Liquibase Flow Files and Policy Checks

**Storage:** AWS S3 bucket (public read)

**Files:**
- `pr-validation-flow.yaml`
- `main-deployment-flow.yaml`
- `liquibase.checks-settings.conf`

**Access:** Public HTTPS URLs via S3

**Management:** Uploaded via Terraform using `aws_s3_object` resources

### 11.4 Operation Reports

**Storage:** AWS S3 bucket (private)

**Naming Convention:** `reports/<github-run-number>/operation-report.html`

**Upload Method:** GitHub Actions with AWS CLI

**Example:**
```yaml
- name: Upload Operation Report
  run: |
    aws s3 cp operation-report.html \
      s3://bagel-store-${{ vars.DEMO_ID }}-operation-reports/reports/${{ github.run_number }}/
```

---

## 12. Security Requirements

### 12.1 Repository Security
- All repositories: Private
- Access: Restricted to team members
- Branch protection: Enabled on main branch

### 12.2 Database Security
- RDS: Publicly accessible (demo only - not production pattern)
- Credentials: Stored in AWS Secrets Manager
- Liquibase: Native integration with AWS Secrets Manager using `${awsSecretsManager:secret-name}` syntax
- Connections: Username/password authentication via Secrets Manager
- SSL: Not required (demo simplification)

### 12.3 Secrets Management

**AWS Secrets Manager:**
- `<demo_id>/rds/username` - Database username
- `<demo_id>/rds/password` - Database password

**GitHub Secrets:**
- `AWS_ACCESS_KEY_ID` - For Terraform, GitHub Actions, and S3 access
- `AWS_SECRET_ACCESS_KEY` - For Terraform, GitHub Actions, and S3 access
- `HARNESS_WEBHOOK_URL` - For triggering Harness pipelines
- `DEMO_ID` - Demo instance identifier
- `LIQUIBASE_LICENSE_KEY` - Liquibase Pro license key

**Harness Secrets:**
- `AWS_ACCESS_KEY` - AWS access key for deployments
- `AWS_SECRET_KEY` - AWS secret key for deployments
- `GITHUB_PAT` - Personal access token for GitHub Packages (changelog artifacts only)

**Note:** No secrets needed for Docker images - they are public on ghcr.io

### 12.4 Application Security
- Authentication: Session-based with hardcoded user
- HTTPS: Not implemented (HTTP only)
- SQL Injection: Prevented via parameterized queries (ORM)
- CORS: Disabled (single origin)

---

## 13. Out of Scope

The following items are explicitly **excluded** from this demo:

1. HTTPS/SSL certificate management
2. User management and registration features
3. Production-grade security hardening
4. High availability and disaster recovery
5. Automated rollback capabilities
6. Performance testing and optimization
7. Monitoring and observability tooling
8. Cost optimization beyond basic instance sizing
9. Multi-region deployment
10. Database backup and restore automation
11. Secrets rotation
12. Compliance and audit logging
13. Development of changelog using VS Code extension (external to demo)

---

## 14. Cost Estimates

**Monthly Cost (Running Continuously):**
- RDS db.t3.micro: ~$15-20
- App Runner (4 services @ $5 each, no auto-scaling): ~$20
- Route53 hosted zone: $0.50
- S3: Negligible
- Secrets Manager: ~$2 (3 secrets)
- **Total: ~$37-42/month**

**Cost Savings:**
- Use AWS Free Tier where applicable
- Run `terraform destroy` after each demo
- Use smallest instance sizes
- Disabled auto-scaling on App Runner

---

# System Design

## 15. Architecture Overview

### 15.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Developer Workflow                        │
├─────────────────────────────────────────────────────────────────┤
│  VS Code + Liquibase Extension  →  Create Changeset  →  PR      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub (Source)                          │
├─────────────────────────────────────────────────────────────────┤
│  • bagel-store-demo repository (private)                        │
│  • Pull Request triggers GitHub Actions                         │
│  • Main branch triggers CI pipelines                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions (CI)                           │
├─────────────────────────────────────────────────────────────────┤
│  PR Validation:                 Main CI:                         │
│  • Setup Liquibase             • Build changelog zip            │
│  • Download from S3            • Build Docker image             │
│  • Run policy checks (BLOCKER) • Push to registries             │
│  • Validate syntax             • Upload reports to S3           │
│  • Upload reports to S3        • Trigger Harness                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Artifact Registries                           │
├─────────────────────────────────────────────────────────────────┤
│  • GitHub Container Registry (Docker: <demo_id>-bagel-store)     │
│  • GitHub Packages (Changelog zips)                              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Services                             │
├─────────────────────────────────────────────────────────────────┤
│  • S3: Liquibase flows, policy checks, operation reports        │
│  • Secrets Manager: DB credentials, GitHub PAT                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              Harness CD Free Edition (SaaS)                      │
├─────────────────────────────────────────────────────────────────┤
│  Deploy Pipeline (Remote YAML in Git):                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   Dev    │→ │   Test   │→ │ Staging  │→ │   Prod   │       │
│  │ (auto)   │  │ (manual) │  │ (manual) │  │ (manual) │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│                                                                  │
│  Each stage:                                                     │
│  1. Fetch changelog zip from GitHub                              │
│  2. Fetch Docker image from GHCR                                 │
│  3. Run Liquibase update (DB) with AWS integration               │
│  4. Deploy to App Runner                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│     Harness Delegate (Local Docker Compose on Laptop)           │
├─────────────────────────────────────────────────────────────────┤
│  • Executes deployment commands                                  │
│  • Network access to AWS resources (public)                      │
│  • Runs Liquibase Docker container                               │
│  • Executes AWS CLI commands                                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    AWS Infrastructure                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────┐    │
│  │  RDS PostgreSQL Instance (Public, tagged)               │    │
│  │  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐              │    │
│  │  │ dev  │  │ test │  │stage │  │ prod │              │    │
│  │  └──────┘  └──────┘  └──────┘  └──────┘              │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  App Runner Services (No auto-scaling, tagged)          │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │  │   dev    │  │   test   │  │ staging  │  │   prod   │  │
│  │  │ <demo_id>│  │ <demo_id>│  │ <demo_id>│  │ <demo_id>│  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Route53 DNS                                            │    │
│  │  dev-<demo_id>.bagel-demo.example.com → dev App Runner │    │
│  │  test-<demo_id>.bagel-demo.example.com → test          │    │
│  │  staging-<demo_id>.bagel-demo.example.com → staging    │    │
│  │  prod-<demo_id>.bagel-demo.example.com → prod          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  S3 Buckets (tagged with demo_id)                       │    │
│  │  • bagel-store-<demo_id>-liquibase-flows (public)       │    │
│  │    - pr-validation-flow.yaml                             │    │
│  │    - main-deployment-flow.yaml                           │    │
│  │    - liquibase.checks-settings.conf                      │    │
│  │  • bagel-store-<demo_id>-operation-reports (private)    │    │
│  │    - reports/<run-number>/operation-report.html         │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  AWS Secrets Manager                                    │    │
│  │  • <demo_id>/rds/username                               │    │
│  │  • <demo_id>/rds/password                               │    │
│  │  • <demo_id>/github/pat                                 │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 15.2 Component Interactions

```
┌──────────────────┐         ┌──────────────────┐
│   Developer      │────────▶│   GitHub Repo    │
│   (VS Code)      │  PR     │   (Private)      │
└──────────────────┘         └──────────────────┘
                                      │
                                      │ webhook
                                      ▼
                             ┌──────────────────┐
                             │ GitHub Actions   │
                             │ (CI Pipelines)   │
                             └──────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
          ┌─────────────────┐ ┌────────────┐  ┌──────────────┐
          │ GitHub Container│ │   GitHub   │  │   AWS S3     │
          │   Registry      │ │  Packages  │  │ (flows +     │
          │ (<demo_id>-app) │ │(changelog) │  │  reports)    │
          └─────────────────┘ └────────────┘  └──────────────┘
                    │                 │                 │
                    └─────────────────┼─────────────────┘
                                      │
                                      ▼
                             ┌──────────────────┐
                             │   Harness CD     │
                             │   (SaaS)         │
                             │   Remote YAML    │
                             └──────────────────┘
                                      │
                                      │ commands
                                      ▼
                             ┌──────────────────┐
                             │    Harness       │
                             │    Delegate      │
                             │ (Docker Compose) │
                             └──────────────────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    │                 │                 │
                    ▼                 ▼                 ▼
          ┌─────────────────┐ ┌────────────┐  ┌──────────────┐
          │  Liquibase       │ │   AWS      │  │ AWS Secrets  │
          │  Secure 5.0.1    │ │ App Runner │  │   Manager    │
          │  (Docker)        │ │            │  │              │
          │  → RDS           │ │            │  │              │
          └─────────────────┘ └────────────┘  └──────────────┘
```

---

## 16. Data Flow Diagrams

### 16.1 PR Validation Flow

```
Developer creates PR
    ↓
GitHub webhook triggers pr-validation.yml
    ↓
GitHub Actions workflow:
    1. Checkout code
    2. Setup Liquibase (setup-liquibase action)
    3. Configure AWS credentials
    4. Download pr-validation-flow.yaml from S3
    5. Download liquibase.checks-settings.conf from S3
    6. Execute Liquibase flow:
        - liquibase checks run --checks-scope=changelog \
          --checks-settings-file=s3://bucket/liquibase.checks-settings.conf
        - All checks at BLOCKER severity
        - liquibase validate
    7. Upload operation report to S3:
       s3://bucket/reports/<run-number>/pr-validation-report.html
    8. Upload report as GitHub Actions artifact
    ↓
Report status to PR (✓ or ✗)
    ↓
If ✓: PR can be merged
If ✗ (BLOCKER violation): PR cannot be merged
```

### 16.2 Main Branch CI Flow

```
PR merged to main
    ↓
GitHub webhook triggers main-ci.yml
    ↓
Parallel workflows:

[Database Workflow]                [App Workflow]
1. Checkout code                   1. Checkout code
2. Setup Liquibase                 2. Extract version from git tag
3. Configure AWS credentials       3. Build Docker image
4. Download flow from S3           4. Tag: ghcr.io/<org>/<demo_id>-bagel-store:v<ver>
5. Download policy checks from S3  5. Push to ghcr.io
6. Execute Liquibase flow:         6. Trigger Harness webhook
   - Run checks (BLOCKER)
   - Validate
   - Create changelog zip
7. Upload to GitHub Packages
8. Upload operation report to S3:
   s3://bucket/reports/<run-number>/main-report.html
9. Trigger Harness webhook
```

### 16.3 Harness Deployment Flow

```
Harness receives webhook (version: v1.0.0)
    ↓
Pipeline starts: Deploy Bagel Store - <demo_id> (v1.0.0)
    ↓
Stage 1: Deploy to Dev (automatic)
    ↓
    Steps executed by Harness Delegate (Docker Compose):
    
    Step 1: Fetch Artifacts
        - Download changelog zip from GitHub Packages
        - Extract to temp directory
    
    Step 2: Update Database
        - Run Docker container:
          docker run liquibase/liquibase-secure:5.0.1 \
            --url=jdbc:postgresql://<rds>:5432/dev \
            --username='${awsSecretsManager:<demo_id>/rds/username}' \
            --password='${awsSecretsManager:<demo_id>/rds/password}' \
            --changeLogFile=changelog-master.xml \
            update
        - Liquibase natively reads from AWS Secrets Manager
    
    Step 3: Deploy Application
        - Run AWS CLI:
          aws apprunner update-service \
            --service-arn <dev-service-arn> \
            --source-configuration ImageRepository={
              ImageIdentifier=ghcr.io/<org>/<demo_id>-bagel-store:v1.0.0
            }
    
    Step 4: Health Check
        - Poll dev-<demo_id>.bagel-demo.example.com/health
        - Wait for 200 OK
    ↓
Stage 1 complete: Dev environment running v1.0.0
    ↓
⏸️  Manual approval required for Test
    ↓
Operator approves promotion
    ↓
Stage 2: Deploy to Test (same steps, test environment)
    ↓
⏸️  Manual approval required for Staging
    ↓
Stage 3: Deploy to Staging
    ↓
⏸️  Manual approval required for Prod
    ↓
Stage 4: Deploy to Prod
    ↓
Pipeline complete: All environments running v1.0.0
```

---

## 17. Deployment Pipeline Details

### 17.1 Liquibase Flow File: pr-validation-flow.yaml

**Purpose:** Validate changelog on PR

**Location:** Repository `liquibase-flows/pr-validation-flow.yaml` (also uploaded to S3 via Terraform)

**Pattern Source:** Based on postgres-flow-policy-demo flowfile.yaml structure

**Content Structure:**
```yaml
##########           LIQUIBASE FLOWFILE                ##########
##########  learn more http://docs.liquibase.com/flow  ##########

globalVariables:
  ENV: "PR"
  REPORTS_PATH: "reports"
  POLICY_REPORT: "pr-policy-report.html"
  VALIDATION_REPORT: "pr-validation-report.html"

stages:
  # Stage 1: Connection and Validation
  Verify:
    actions:
      - type: liquibase
        command: connect
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "connection-report.html" }

      - type: liquibase
        command: validate
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "${VALIDATION_REPORT}" }

      - type: liquibase
        command: status
        cmdArgs: { verbose: "true" }
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "status-report.html" }

  # Stage 2: Policy Checks (BLOCKER severity)
  PolicyChecks:
    actions:
      - type: liquibase
        command: checks show
        cmdArgs: { check-status: "enabled" }

      - type: liquibase
        command: checks run
        cmdArgs:
          report-enabled: "true"
          report-path: "${REPORTS_PATH}"
          report-name: "${POLICY_REPORT}"
          checks-output: "issues"
          checks-scope: "changelog"
          auto-update: "on"
        globalArgs: { reports-open: "false" }

endStage:
  actions:
    - type: shell
      command: |
        echo "=== PR VALIDATION SUMMARY ==="
        echo "Environment: ${ENV}"
        echo "Reports: ${REPORTS_PATH}/"
        ls -la "${REPORTS_PATH}/"*.html 2>/dev/null || echo "No reports found"
```

### 17.2 Liquibase Flow File: main-deployment-flow.yaml

**Purpose:** Build and validate changelog on main branch

**Location:** Repository `liquibase-flows/main-deployment-flow.yaml` (also uploaded to S3 via Terraform)

**Pattern Source:** Extends postgres-flow-policy-demo pattern with artifact creation

**Content Structure:**
```yaml
##########           LIQUIBASE FLOWFILE                ##########
##########  learn more http://docs.liquibase.com/flow  ##########

globalVariables:
  ENV: "MAIN"
  REPORTS_PATH: "reports"
  POLICY_REPORT: "main-policy-report.html"
  DEPLOYMENT_REPORT: "main-deployment-report.html"
  VERSION: "${VERSION:-latest}"

stages:
  # Stage 1: Connection and Validation
  Verify:
    actions:
      - type: liquibase
        command: connect
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "connection-report.html" }

      - type: liquibase
        command: validate
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "validation-report.html" }

      - type: liquibase
        command: status
        cmdArgs: { verbose: "true" }
        globalArgs: { reports-enabled: "true", reports-path: "${REPORTS_PATH}", reports-name: "status-report.html" }

  # Stage 2: Policy Checks (BLOCKER severity)
  PolicyChecks:
    actions:
      - type: liquibase
        command: checks show
        cmdArgs: { check-status: "enabled" }

      - type: liquibase
        command: checks run
        cmdArgs:
          report-enabled: "true"
          report-path: "${REPORTS_PATH}"
          report-name: "${POLICY_REPORT}"
          checks-output: "issues"
          checks-scope: "changelog"
          auto-update: "on"
        globalArgs: { reports-open: "false" }

  # Stage 3: Create Changelog Artifact
  CreateArtifact:
    actions:
      - type: shell
        command: |
          echo "Creating changelog artifact..."
          cd db/changelog
          zip -r ../../bagel-store-changelog-${VERSION}.zip . -x "*.git*"
          echo "Artifact created: bagel-store-changelog-${VERSION}.zip"
          ls -lh ../../bagel-store-changelog-${VERSION}.zip

endStage:
  actions:
    - type: shell
      command: |
        echo "=== MAIN BUILD SUMMARY ==="
        echo "Environment: ${ENV}"
        echo "Version: ${VERSION}"
        echo "Reports: ${REPORTS_PATH}/"
        ls -la "${REPORTS_PATH}/"*.html 2>/dev/null || echo "No reports found"
```

### 17.3 Policy Checks Configuration File

**File:** `liquibase.checks-settings.conf`

**Location:** S3 bucket `s3://bagel-store-<demo_id>-liquibase-flows/liquibase.checks-settings.conf`

**Configuration:** All 12 checks enabled with BLOCKER severity (exit code 4)

### 17.4 Harness Pipeline Structure

**File:** `harness/pipelines/deploy-pipeline.yaml`

**Storage:** Git repository (Remote pipeline in Harness)

**Pipeline Definition:**
```yaml
pipeline:
  name: Deploy Bagel Store - <demo_id>
  identifier: deploy_bagel_store_<demo_id>
  projectIdentifier: bagel_store_demo
  orgIdentifier: default
  
  stages:
    - stage:
        name: Deploy to Dev
        identifier: deploy_dev
        type: Deployment
        spec:
          execution:
            steps:
              - step:
                  name: Fetch Changelog
                  identifier: fetch_changelog
                  type: ShellScript
                  spec:
                    shell: Bash
                    source:
                      type: Inline
                      spec:
                        script: |
                          # Download from GitHub Packages
                          # Extract to working directory
              
              - step:
                  name: Update Database
                  identifier: update_database
                  type: ShellScript
                  spec:
                    shell: Bash
                    source:
                      type: Inline
                      spec:
                        script: |
                          docker run --rm \
                            -v $(pwd):/liquibase/changelog \
                            -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
                            -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
                            -e AWS_REGION=${AWS_REGION} \
                            liquibase/liquibase-secure:5.0.1 \
                            --url=jdbc:postgresql://${RDS_ENDPOINT}:5432/dev \
                            --username='${awsSecretsManager:<demo_id>/rds/username}' \
                            --password='${awsSecretsManager:<demo_id>/rds/password}' \
                            --changeLogFile=changelog-master.xml \
                            update
              
              - step:
                  name: Deploy Application
                  identifier: deploy_app
                  type: ShellScript
                  spec:
                    shell: Bash
                    source:
                      type: Inline
                      spec:
                        script: |
                          aws apprunner update-service \
                            --service-arn ${DEV_SERVICE_ARN} \
                            --source-configuration ImageRepository={
                              ImageIdentifier=ghcr.io/<org>/<demo_id>-bagel-store:${VERSION}
                            }
    
    - stage:
        name: Deploy to Test
        identifier: deploy_test
        type: Approval
        spec:
          execution:
            steps:
              - step:
                  name: Manual Approval
                  identifier: approval
                  type: HarnessApproval
        # ... similar deployment steps for test environment
    
    # ... staging and prod stages with approvals
```

---

## 18. Technology Stack Summary

### 18.1 Development & CI/CD
- **Source Control:** GitHub (private repositories)
- **CI/CD:** GitHub Actions
- **CD Orchestration:** Harness CD Free Edition (Remote YAML pipelines)
- **Liquibase:** Secure version 5.0.1
- **GitHub Action:** liquibase/setup-liquibase@v1

### 18.2 Application
- **Language:** Python 3.11+
- **Framework:** Flask
- **Database Client:** psycopg2
- **Dependency Management:** uv (replaces pip for faster, reproducible installs)
- **Dependency Files:** pyproject.toml (PEP 621) + uv.lock
- **Containerization:** Docker
- **Base Image:** ghcr.io/astral-sh/uv:python3.11-bookworm-slim

### 18.3 Database
- **Engine:** PostgreSQL (latest AWS RDS version)
- **Change Management:** Liquibase Secure 5.0.1
- **Hosting:** AWS RDS
- **Policy Checks:** 12 checks at BLOCKER severity

### 18.4 Infrastructure
- **Cloud Provider:** AWS
- **IaC:** Terraform
- **Compute:** AWS App Runner (no auto-scaling)
- **Database:** AWS RDS PostgreSQL
- **Storage:** AWS S3
- **DNS:** AWS Route53
- **Secrets:** AWS Secrets Manager

### 18.5 Artifacts & Registries
- **Container Images:** GitHub Container Registry (ghcr.io/<org>/<demo_id>-bagel-store)
- **Changelog Artifacts:** GitHub Packages
- **Flow Files:** AWS S3
- **Operation Reports:** AWS S3

---

## 19. Implementation Phases

### Phase 1: Infrastructure Setup ⏸️ **BLOCKED** by DAT-20991

**Status:** Terraform code complete, awaiting AWS permissions

**Completed:**
1. ✅ Created Terraform configurations for all AWS resources
2. ✅ Configured demo_id variable and tagging
3. ✅ Configured aws_profile variable support
4. ✅ Made Route53 DNS optional (enable_route53 flag)
5. ✅ Created terraform.tfvars.example template
6. ✅ Removed GitHub PAT from AWS Secrets Manager (kept as Terraform variable)

**Blocked by DAT-20991 (DevOps team):**
- Need IAM roles created: `liquibase-demo-apprunner-instance-role`, `liquibase-demo-apprunner-access-role`
- Need Security Group created: `liquibase-demo-rds-sg`
- Need Auto Scaling Config created: `liquibase-demo-fixed-scaling`
- Need AWS permissions granted: App Runner (CreateService, etc.), RDS (CreateDBInstance, etc.)

**Can proceed after DAT-20991 resolved:**
1. 🔲 Provision RDS instance with 4 databases
2. 🔲 Create S3 buckets for flows and reports
3. 🔲 Set up AWS Secrets Manager secrets (RDS credentials only)
4. 🔲 Configure Route53 DNS records (optional)
5. 🔲 Upload Liquibase flow files and policy checks to S3 via Terraform

### Phase 2: Application Development ✅ **COMPLETE**

**Status:** Completed and tested - October 5, 2025

**Dependencies:** None (local development only)

**Tasks:**
1. ✅ Initialize uv project with `uv init`
2. ✅ Create pyproject.toml with Flask and psycopg2 dependencies
3. ✅ Create Flask application structure (routes, models, templates)
4. ✅ Implement database models (products, inventory, orders, order_items)
5. ✅ Build UI templates (product catalog, cart, checkout, login)
6. ✅ Create Dockerfile using uv for dependency installation
7. ✅ Generate uv.lock file for reproducible builds
8. ✅ Test locally with Docker Compose (PostgreSQL + Flask)
9. ✅ Implement comprehensive test suite (15 tests with pytest + Playwright)
10. ✅ Add `/version` endpoint for deployment verification
11. ✅ Fix routing for `/checkout/place-order` endpoint

**Deliverables:**
- Complete Flask application with Blueprint architecture
- All database models (Product, Inventory, Order, OrderItem)
- Full UI templates (6 pages: base, index, cart, checkout, login, order_confirmation)
- Authentication with environment-based credentials (DEMO_USERNAME, DEMO_PASSWORD)
- Shopping cart and checkout flow
- Docker Compose setup with PostgreSQL 16
- Comprehensive E2E test suite (15 tests, all passing)
- Health check endpoint (`/health`)
- Version info endpoint (`/version`) for Harness deployment tracking

**Test Results:**
```
15 passed in 8.69s
- 11 E2E tests (Playwright browser automation)
- 4 health check tests
```

**Notes:**
- Application fully functional and ready for Phase 3 (Database Schema)
- Docker Compose environment validated
- All tests passing with Playwright E2E automation
- Ready for AWS deployment when infrastructure available

---

### Phase 3: Database Schema ✅ **COMPLETE**

**Status:** Completed and tested - October 5, 2025

**Dependencies:** None (local Liquibase testing)

**Tasks:**
1. ✅ Design database schema (products, inventory, orders, order_items)
2. ✅ Create 7 Liquibase changesets in formatted SQL
3. ✅ Create master changelog file (YAML format)
4. ✅ Verify policy checks configuration (12 BLOCKER checks)
5. ✅ Create comprehensive README.md documentation
6. ✅ Test Liquibase validate locally (successful)
7. ✅ Test Liquibase update locally (9 changesets applied)
8. ✅ Verify schema matches app/init-db.sql exactly
9. ✅ Update CLAUDE.md with changeset development patterns
10. ✅ Update .gitignore (liquibase.properties already present)

**Deliverables:**
- **Changesets (7):**
  - 001-create-products-table.sql
  - 002-create-inventory-table.sql
  - 003-create-orders-table.sql
  - 004-create-order-items-table.sql
  - 005-create-indexes.sql (4 indexes)
  - 006-seed-products.sql (5 bagel types)
  - 007-seed-inventory.sql (50 units each)
- **Master Changelog:** changelog-master.yaml (YAML format)
- **Documentation:** db/changelog/README.md (comprehensive guide)
- **Policy Checks:** liquibase.checks-settings.conf (verified 12 BLOCKER checks)

**Test Results:**
```
Liquibase Validate: ✅ No validation errors found
Liquibase Update:   ✅ 9 changesets applied successfully
Database Verify:    ✅ 4 tables + 2 tracking tables created
Seed Data:          ✅ 5 products, 5 inventory records loaded
Schema Match:       ✅ Identical to app/init-db.sql
```

**Database Tables Created:**
- `products` (5 rows)
- `inventory` (5 rows)
- `orders` (0 rows - ready for transactions)
- `order_items` (0 rows - ready for transactions)
- `databasechangelog` (Liquibase tracking)
- `databasechangeloglock` (Liquibase locking)

**Indexes Created:**
- `idx_order_items_order_id`
- `idx_order_items_product_id`
- `idx_orders_status`
- `idx_orders_date`

**Notes:**
- All changesets include proper rollback statements
- Policy checks configuration validated (BLOCKER severity on all 12 checks)
- Local testing uses `liquibase/liquibase-secure:5.0.1`
- License key required in `~/.zshrc` as `LIQUIBASE_LICENSE_KEY`
- Ready for integration with Phase 4 (GitHub Actions CI/CD)

---

### Phase 4: CI/CD Pipeline ⚠️ **PARTIALLY BLOCKED**

**Status:** Can prepare workflows, but cannot fully test until Phase 1 complete

**Can proceed now:**
1. 🔲 Create GitHub Actions workflow files (.github/workflows/)
   - pr-validation.yml
   - main-ci.yml (database)
   - app-ci.yml (application)
2. 🔲 Configure GitHub Packages for Docker images
3. 🔲 Configure GitHub Secrets (AWS credentials, Liquibase license)
4. 🔲 Write S3 upload logic for operation reports
5. 🔲 Test workflow syntax validation

**Blocked until Phase 1 complete:**
- Cannot test workflows against real RDS database
- Cannot test S3 uploads (buckets don't exist yet)
- Cannot test Liquibase with AWS Secrets Manager

**Notes:**
- Workflows can be written and syntax-validated
- Use DAT-20991 blocker time to perfect workflow logic

---

### Phase 5: Harness Configuration ✅ **CAN PROCEED**

**Status:** Most work can proceed independently

**Can proceed now:**
1. 🔲 **Research:** Review Harness CD Free Edition via Context7
2. 🔲 **Research:** Study Harness Remote pipeline configuration
3. 🔲 Set up Harness account (harness.io)
4. 🔲 Create Harness delegate docker-compose.yml
5. 🔲 Start Harness Delegate locally (test connectivity)
6. 🔲 Build deployment pipeline YAML in Git repository
7. 🔲 Configure Harness to use Remote pipeline from Git
8. 🔲 Create Harness connectors (GitHub - can test)

**Blocked until Phase 1 complete:**
- Cannot create AWS connector (no infrastructure yet)
- Cannot test deployments to App Runner
- Cannot test end-to-end promotion flow

**Notes:**
- Harness setup, delegate, and pipeline YAML can all be prepared
- Only actual deployment testing requires AWS infrastructure

### Phase 6: Integration Testing & Documentation ⏸️ **BLOCKED** by Phase 1

**Status:** Requires complete AWS infrastructure

**Dependencies:** Phase 1 (AWS infrastructure), Phase 2 (app), Phase 3 (database), Phase 4 (CI/CD), Phase 5 (Harness)

**Tasks:**
1. 🔲 Test full workflow end-to-end (PR → merge → deploy → promote)
2. 🔲 Verify all environments (dev, test, staging, prod)
3. 🔲 Test promotion flow through Harness CD
4. 🔲 Validate policy checks enforcement (BLOCKER severity)
5. 🔲 Verify AWS integration (Secrets Manager, S3, App Runner)
6. 🔲 Document demo script for Bank of America presentation

**Notes:**
- Final integration testing requires all phases complete
- Can prepare test plans while waiting for Phase 1

---

## Summary: What Can Proceed Now

**✅ Immediate work (no blockers):**
- **Phase 2:** Develop Flask application locally
- **Phase 3:** Create Liquibase changesets and test locally
- **Phase 5:** Set up Harness account, delegate, and pipeline YAML

**⚠️ Partial work (prepare but can't test):**
- **Phase 4:** Write GitHub Actions workflows (can't test until Phase 1)

**⏸️ Blocked by DAT-20991:**
- **Phase 1:** AWS infrastructure deployment
- **Phase 6:** Full integration testing

**Critical Path:** DAT-20991 → Phase 1 → Phase 6

**Parallel Work Opportunity:** While waiting for DevOps, complete Phases 2, 3, and 5 to maximize readiness

---

## 20. Appendix

### 20.1 Useful Commands

**Terraform:**
```bash
terraform init
terraform plan -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
terraform apply -var="demo_id=demo1" -var="aws_username=$(aws sts get-caller-identity --query UserId --output text)"
terraform destroy -var="demo_id=demo1"
```

**Harness Delegate (Docker Compose):**
```bash
cd harness
docker-compose up -d
docker-compose logs -f harness-delegate
docker-compose down
```

**Liquibase Local Test with AWS Integration:**
```bash
# With Secrets Manager
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=<your-key> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret> \
  -e AWS_REGION=us-east-1 \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://localhost:5432/dev \
  --username='${awsSecretsManager:demo1/rds/username}' \
  --password='${awsSecretsManager:demo1/rds/password}' \
  --changeLogFile=changelog-master.xml \
  validate

# With S3 flow files
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  -e AWS_ACCESS_KEY_ID=<your-key> \
  -e AWS_SECRET_ACCESS_KEY=<your-secret> \
  -e AWS_REGION=us-east-1 \
  liquibase/liquibase-secure:5.0.1 \
  flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/pr-validation-flow.yaml
```

**Upload Operation Report to S3:**
```bash
aws s3 cp operation-report.html \
  s3://bagel-store-demo1-operation-reports/reports/123/operation-report.html
```

### 20.2 Required GitHub Secrets

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
HARNESS_WEBHOOK_URL
DEMO_ID
LIQUIBASE_LICENSE_KEY
GITHUB_TOKEN (auto-provided)
```

### 20.3 Required Harness Secrets

```
AWS_ACCESS_KEY
AWS_SECRET_KEY
GITHUB_PAT (for changelog artifacts from GitHub Packages)
```

### 20.4 AWS Secrets Manager Secrets

```
<demo_id>/rds/username
<demo_id>/rds/password
```

**Note:** No GitHub PAT in Secrets Manager - Docker images are public

### 20.5 Python Dependency Management with uv

**Initialize Project:**
```bash
cd app
uv init --name bagel-store --python 3.11
```

**Add Dependencies:**
```bash
uv add flask psycopg2-binary python-dotenv
```

**pyproject.toml Example:**
```toml
[project]
name = "bagel-store"
version = "1.0.0"
description = "Bagel Store Ordering Application"
requires-python = ">=3.11"
dependencies = [
    "flask>=3.0.0",
    "psycopg2-binary>=2.9.9",
    "python-dotenv>=1.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "black>=23.0.0",
]
```

**Install Dependencies:**
```bash
# Install all dependencies (creates uv.lock)
uv sync

# Install including dev dependencies
uv sync --extra dev

# Run application
uv run python src/app.py
```

**Dockerfile with uv:**
```dockerfile
FROM ghcr.io/astral-sh/uv:python3.11-bookworm-slim

WORKDIR /app

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies (much faster than pip)
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ ./src/

# Set environment
ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 5000

CMD ["uv", "run", "python", "src/app.py"]
```

**CI/CD Integration (GitHub Actions):**
```yaml
- name: Install uv
  uses: astral-sh/setup-uv@v4
  with:
    version: "latest"

- name: Install dependencies
  run: uv sync --frozen

- name: Run tests
  run: uv run pytest
```

**Benefits:**
- **Speed**: 10-100x faster than pip
- **Reproducibility**: uv.lock ensures identical installs
- **Disk space**: Shared cache across projects
- **No virtual env needed**: uv manages automatically
- **Modern**: Follows PEP 621 standards

### 20.6 Policy Checks Configuration Example

**File:** `liquibase.checks-settings.conf`

```
# All checks configured with BLOCKER severity (exit code 4)
liquibase.checks.ChangeDropColumnWarn.severity=BLOCKER
liquibase.checks.ChangeDropTableWarn.severity=BLOCKER
liquibase.checks.ChangeTruncateTableWarn.severity=BLOCKER
liquibase.checks.CheckTablesForIndex.severity=BLOCKER
liquibase.checks.ModifyDataTypeWarn.severity=BLOCKER
liquibase.checks.RollbackRequired.severity=BLOCKER
liquibase.checks.SqlGrantAdminWarn.severity=BLOCKER
liquibase.checks.SqlGrantOptionWarn.severity=BLOCKER
liquibase.checks.SqlGrantWarn.severity=BLOCKER
liquibase.checks.SqlRevokeWarn.severity=BLOCKER
liquibase.checks.SqlSelectStarWarn.severity=BLOCKER
liquibase.checks.TableColumnLimit.severity=BLOCKER
liquibase.checks.TableColumnLimit.maxColumns=50
```

---

## 21. Pattern-Based Design Updates Summary

### 21.1 Changes from Original Design

Based on analysis of proven patterns from the ../liquibase-patterns repository, the following design improvements have been incorporated:

#### GitHub Actions Modernization
- ✅ Updated to `liquibase/setup-liquibase@v1` (replaces deprecated versions)
- ✅ Minimum Liquibase version raised to 4.32.0 (from 5.0.1 mention)
- ✅ Added `edition: 'secure'` parameter for Flow and policy check support
- ✅ Updated to `actions/checkout@v4` and `actions/upload-artifact@v4`
- ✅ Added `aws-actions/configure-aws-credentials@v4` for AWS integration

#### Environment Variable Strategy
- ✅ **Critical Change:** Use `LIQUIBASE_COMMAND_*` environment variables exclusively in GitHub Actions
- ✅ Removed reliance on custom property substitution (e.g., `${VARIABLE}` in properties files)
- ✅ Required variables explicitly defined: LIQUIBASE_COMMAND_URL, LIQUIBASE_COMMAND_USERNAME, LIQUIBASE_COMMAND_PASSWORD, LIQUIBASE_LICENSE_KEY
- ✅ Pattern proven to work reliably in GitHub Actions environment

#### Changelog Format
- ✅ Changed from XML to YAML for root changelog (modern best practice)
- ✅ Use formatted SQL for individual changesets (not XML)
- ✅ Pattern: YAML root → SQL changesets (postgres-flow-policy-demo pattern)

#### Flow File Structure
- ✅ Adopted staged structure: Verify → PolicyChecks → Deploy/Build → Validation
- ✅ Added `endStage` for cleanup and summary reporting
- ✅ Included `globalVariables` for consistent configuration
- ✅ Enabled operation reports with dedicated reports/ directory
- ✅ Pattern source: postgres-flow-policy-demo

#### Workflow Enhancements
- ✅ Added GitHub workflow summary via `$GITHUB_STEP_SUMMARY` for PR visibility
- ✅ S3 upload pattern for operation reports organized by PR number and run ID
- ✅ Artifact upload with proper naming and retention policies
- ✅ Pattern source: dbt-example GitHub Actions workflows

### 21.2 Pattern Repository References

**Primary Patterns Used:**
1. **postgres-flow-policy-demo** - Flow structure, policy checks, operation reports
2. **dbt-example** - GitHub Actions setup-liquibase usage, LIQUIBASE_COMMAND_* variables
3. **Liquibase-workshop-repo** - PostgreSQL patterns, AWS integration, multi-database architecture

**Documentation References:**
- `../liquibase-patterns/docs/liquibase-learnings.md` - Critical GitHub Actions and environment variable lessons
- `../liquibase-patterns/docs/catalog.md` - Repository inventory and quick reference
- `../liquibase-patterns/claude.md` - Workshop architecture and best practices

### 21.3 Implementation Benefits

**Reliability Improvements:**
- Proven patterns reduce implementation risk
- Known working configurations for GitHub Actions
- Tested AWS integration patterns

**Maintainability:**
- Modern action versions with active support
- Clear separation of concerns in flow files
- Consistent environment variable handling

**Observability:**
- Comprehensive operation reports at each stage
- GitHub workflow summaries for quick status
- S3-organized reports for historical analysis

---

## 22. Documentation Resources Available via Context7

### 22.1 Liquibase Documentation
Context7 has comprehensive Liquibase documentation available:

- **[/liquibase/liquibase](/liquibase/liquibase)** - Main Liquibase source code
  - 140 code snippets
  - Trust score: 10
  - Contains core implementation patterns

- **[/liquibase/liquibase-docs](/liquibase/liquibase-docs)** - Official Liquibase documentation
  - 3,679 code snippets
  - Trust score: 10
  - Comprehensive usage examples and best practices

**Usage:** Can fetch detailed documentation for specific Liquibase features during implementation phases 3, 4, and 5.

### 22.2 GitHub Actions Documentation
Context7 provides extensive GitHub Actions resources:

- **[/actions/checkout](/actions/checkout)** - Checkout action (v5 available)
  - 32 code snippets
  - Trust score: 8.9

- **[/actions/upload-artifact](/actions/upload-artifact)** - Artifact upload action
  - 42 code snippets
  - Trust score: 8.9

- **[/actions/cache](/actions/cache)** - Caching dependencies
  - 73 code snippets
  - Trust score: 8.9

- **[/actions/toolkit](/actions/toolkit)** - GitHub Actions toolkit
  - 136 code snippets
  - Trust score: 8.9

**Usage:** Reference during Phase 4 (CI/CD Pipeline implementation) for workflow optimization.

### 22.3 Harness CD Documentation
Context7 has Harness platform documentation:

- **[/harness/developer-hub](/harness/developer-hub)** - Harness Developer Hub
  - 22,333 code snippets
  - Trust score: 9.1
  - Comprehensive guides, videos, certifications, and reference docs

- **[/harness/harness](/harness/harness)** - Harness Open Source
  - 31 code snippets
  - Trust score: 9.1
  - DevOps platform documentation

**Usage:** Critical resource for Phase 5 (Harness Configuration) including pipeline YAML syntax, delegate setup, and connector configuration.

### 22.4 PostgreSQL Documentation
Context7 provides multiple PostgreSQL resources:

- **[/websites/postgresql](/websites/postgresql)** - Official PostgreSQL docs
  - 73,401 code snippets
  - Trust score: 7.5

- **[/postgres/postgres](/postgres/postgres)** - PostgreSQL source (v17.6, v16.10)
  - 20 code snippets
  - Trust score: 8.4

- **[/porsager/postgres](/porsager/postgres)** - Postgres.js (Node.js client)
  - 178 code snippets
  - Trust score: 9.6

**Usage:** Reference during Phase 2 (Application Development) for psycopg2 integration and Phase 3 (Database Schema) for PostgreSQL-specific features.

### 22.5 Additional Relevant Documentation

- **AWS Secrets Manager GitHub Action** - [/bitovi/github-actions-aws-secrets-manager](/bitovi/github-actions-aws-secrets-manager)
  - 15 code snippets, Trust score: 7.9
  - Useful for Phase 4 GitHub Actions AWS integration

**Recommendation:** Leverage Context7 documentation during implementation to:
1. Verify syntax and best practices for each technology
2. Find working code examples for integration patterns
3. Troubleshoot issues with authoritative sources
4. Stay current with latest API changes and features

---

**Document Version:** 3.2
**Last Updated:** 2025-10-04
**Status:** Updated with uv Dependency Management - Ready for Implementation
**Pattern Review:** Completed - Incorporates learnings from ../liquibase-patterns repository
**Documentation Resources:** Catalogued - Context7 integration identified
**Dependency Management:** Updated to use uv instead of pip/requirements.txt