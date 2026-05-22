# Demo Scripts - Pipeline Rollback Demonstration

Scripts for demonstrating Liquibase rollback capabilities through a complete CI/CD pipeline deployment.

## Product Rating Demo

This demo showcases Liquibase's ability to:
- Deploy database changes through a multi-stage pipeline (dev → test → staging → prod)
- Rollback changes across all environments
- Maintain schema consistency across environments

### What It Does

**Apply Script:**
- Applies git patch with rating feature changes (uncommitted)
- Shows what will be deployed
- Provides instructions for manual commit/push

**Rollback Script:**
- Resets git working tree to clean state
- Connects to AWS RDS databases via Terraform outputs
- Rolls back rating changeset from all 4 databases
- Handles databases where changeset hasn't been deployed yet

**UI Impact:**
- Star ratings (★★★★★) appear/disappear below product names

### Prerequisites

**Required:**
- ✅ Terraform infrastructure deployed (`cd terraform && terraform apply`)
- ✅ AWS CLI configured with valid credentials
- ✅ `AWS_PROFILE` environment variable set
- ✅ `jq` installed (for parsing JSON)
- ✅ Docker installed (for Liquibase execution)

**Deployment Mode:**
- This demo requires AWS deployment mode
- RDS instance with 4 databases (dev, test, staging, prod)
- AWS Secrets Manager credentials configured

**Verify prerequisites:**
```bash
# Check terraform state
ls terraform/terraform.tfstate

# Verify AWS credentials
export AWS_PROFILE=liquibase-sandbox-owner
aws sts get-caller-identity

# Check terraform outputs
cd terraform && terraform output
```

---

## Usage

### 1. Apply the Rating Feature

```bash
./scripts/demo/apply-rating-demo.sh
```

**What happens:**
- ✅ Verifies git working tree is clean
- ✅ Applies `rating-feature.patch` (uncommitted changes)
- ✅ Shows `git status` and `git diff --stat`
- ✅ Displays next steps for manual deployment

**Output:**
```
========================================
  Changes Applied (Uncommitted)
========================================

Modified files:
 M db/changelog/changelog-master.yaml
 M db/changelog/changesets/008-add-product-ratings.sql
 M app/src/models.py
 M app/src/routes.py
 M app/src/templates/index.html
 M app/src/static/css/style.css

Next steps (MANUAL):
  1. Review changes: git diff
  2. Commit: git commit -am "Add product ratings"
  3. Push: git push
  4. Watch pipeline deploy through environments
  5. Reset demo: ./scripts/demo/rollback-rating-demo.sh
```

### 2. Deploy Through Pipeline (MANUAL)

**You perform these steps:**

```bash
# Review the changes
git diff

# Commit the feature
git commit -am "Add product ratings feature"

# Push to trigger pipeline
git push
```

**What happens in the pipeline:**

1. **GitHub Actions** (main-ci.yml):
   - Builds Docker image → AWS Public ECR
   - Runs Liquibase PR validation
   - Creates changelog artifact (zip)
   - Triggers Harness via webhook

2. **Harness CD** (Deploy_Bagel_Store pipeline):
   - **Dev stage**: Liquibase update → App Runner deploy → Health check
   - **Test stage**: Liquibase update → App Runner deploy → Health check
   - **Staging stage**: Liquibase update → App Runner deploy → Health check
   - **Prod stage**: Liquibase update → App Runner deploy → Health check

**Monitor deployment:**
```bash
# GitHub Actions
gh run list --limit 5

# Harness pipeline
./scripts/harness/get-pipeline-executions.sh
```

### 3. Verify Deployment

**Check each environment:**
```bash
# Get App Runner URLs from terraform
cd terraform && terraform output app_runner_services

# Visit each environment URL
# Star ratings should appear below product names
```

**Check databases directly:**
```bash
# Get RDS endpoint
RDS_ENDPOINT=$(cd terraform && terraform output -raw rds_address)

# Connect to each database
psql -h $RDS_ENDPOINT -U postgres -d dev -c "SELECT name, rating FROM products;"
psql -h $RDS_ENDPOINT -U postgres -d test -c "SELECT name, rating FROM products;"
psql -h $RDS_ENDPOINT -U postgres -d staging -c "SELECT name, rating FROM products;"
psql -h $RDS_ENDPOINT -U postgres -d prod -c "SELECT name, rating FROM products;"
```

### 4. Rollback (Reset Demo)

```bash
./scripts/demo/rollback-rating-demo.sh
```

**What happens:**

**Part 1: Git Reset**
- Discards uncommitted changes (if any)
- Cleans working tree

**Part 2: Database Rollback**
- Gets terraform outputs (RDS endpoint, credentials)
- Fetches username/password from AWS Secrets Manager
- For each database (dev, test, staging, prod):
  - Checks if changeset 008 exists
  - If exists: Runs `liquibase rollback v1.0.0`
  - If not exists: Skips (not deployed yet)
  - Handles connection errors gracefully

**Output:**
```
========================================
  Rollback Summary
========================================

Git working tree: Reset to HEAD

Database rollbacks:
  ✓ Rolled back (4): dev test staging prod

========================================
  ✓ Demo Reset Complete!
========================================

Ready for next demonstration:
  ./scripts/demo/apply-rating-demo.sh
```

**Partial deployment example:**
```
Database rollbacks:
  ✓ Rolled back (2): dev test
  ⊘ Skipped (2): staging prod (changeset not applied)
```

---

## Complete Demo Flow

### Standard Flow (Full Pipeline)

```bash
# 1. Apply changes (uncommitted)
./scripts/demo/apply-rating-demo.sh

# 2. Commit and push
git commit -am "Add product ratings"
git push

# 3. Watch pipeline (5-10 minutes)
./scripts/harness/get-pipeline-executions.sh

# 4. Verify in UI - star ratings appear in all environments

# 5. Reset for next demo
./scripts/demo/rollback-rating-demo.sh
```

### Quick Demo (Dev Only)

```bash
# 1. Apply changes
./scripts/demo/apply-rating-demo.sh

# 2. Commit and push
git commit -am "Add product ratings"
git push

# 3. Wait for dev stage to complete (1-2 minutes)

# 4. Show dev environment with ratings

# 5. Rollback before pipeline completes other stages
./scripts/demo/rollback-rating-demo.sh
# Result: dev rolled back, test/staging/prod skipped
```

---

## Technical Details

### Rating Feature Implementation

**Database Changes** (`008-add-product-ratings.sql`):
```sql
-- Forward migration
ALTER TABLE products ADD COLUMN rating INTEGER NOT NULL DEFAULT 4
CHECK (rating >= 1 AND rating <= 5);

UPDATE products SET rating = 4 WHERE name = 'Plain Bagel';
UPDATE products SET rating = 5 WHERE name = 'Everything Bagel';
-- ... (5 products total)

-- Rollback
--rollback ALTER TABLE products DROP COLUMN rating;
```

**Application Changes:**
- `models.py` - Added `rating: int = 0` field
- `routes.py` - Query includes rating column
- `index.html` - Display stars: `{% for i in range(product.rating) %}★{% endfor %}`
- `style.css` - Gold star styling (#f39c12)

### AWS Integration

**Terraform Outputs Used:**
```bash
terraform output -json | jq
{
  "rds_address": "bagel-store-psr.xxx.us-east-1.rds.amazonaws.com",
  "rds_port": 5432,
  "demo_id": "psr",
  "deployment_mode": "aws"
}
```

**AWS Secrets Manager:**
```bash
# Secret IDs (constructed from demo_id)
${demo_id}/rds/username  # e.g., psr/rds/username
${demo_id}/rds/password  # e.g., psr/rds/password

# Fetch via AWS CLI
aws secretsmanager get-secret-value --secret-id psr/rds/username
```

**Liquibase Execution:**
```bash
docker run --rm --network host \
  -v /path/to/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url="jdbc:postgresql://RDS_HOST:5432/dev" \
  --username="postgres" \
  --password="secret" \
  --changelog-file=changelog-master.yaml \
  rollback v1.0.0
```

---

## Troubleshooting

### Apply Script Errors

**"Git working tree is not clean"**
```bash
# View uncommitted changes
git status

# Option 1: Commit changes
git commit -am "WIP: save current work"

# Option 2: Stash changes
git stash

# Option 3: Discard changes (WARNING: destructive)
git checkout -- .
```

**"Patch has already been applied"**
```bash
# Reset and try again
./scripts/demo/rollback-rating-demo.sh
./scripts/demo/apply-rating-demo.sh
```

### Rollback Script Errors

**"AWS_PROFILE not set"**
```bash
export AWS_PROFILE=liquibase-sandbox-owner
aws sts get-caller-identity  # verify
```

**"Terraform state not found"**
```bash
cd terraform
terraform init
terraform apply
```

**"Deployment mode is 'local'"**
```bash
# This demo requires AWS mode
cd terraform
vim terraform.tfvars

# Set: deployment_mode = "aws"
terraform apply
```

**"Failed to fetch credentials from Secrets Manager"**
```bash
# Verify secrets exist
aws secretsmanager list-secrets | grep rds

# Check permissions
aws iam get-user-policy --user-name $USER --policy-name SecretsManagerAccess
```

**"Rollback failed" for specific database**
```bash
# Check database connectivity
RDS_ENDPOINT=$(cd terraform && terraform output -raw rds_address)
psql -h $RDS_ENDPOINT -U postgres -d dev -c "SELECT 1"

# Check Liquibase changelog table
psql -h $RDS_ENDPOINT -U postgres -d dev -c "SELECT * FROM databasechangelog WHERE id LIKE '%008%';"

# Manual rollback
docker run --rm --network host \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url="jdbc:postgresql://$RDS_ENDPOINT:5432/dev" \
  --username="postgres" \
  --password="$DB_PASSWORD" \
  --changelog-file=changelog-master.yaml \
  rollback v1.0.0
```

### Pipeline Issues

**GitHub Actions not triggering**
```bash
# Verify webhook URL
./scripts/harness/get-webhook-url.sh

# Check GitHub variable
gh variable list | grep HARNESS_WEBHOOK_URL
```

**Harness pipeline stuck in QUEUED**
```bash
# Check trigger configuration
./scripts/harness/get-trigger.sh

# Verify Pipeline Reference Branch is set to: <+trigger.branch>
```

**Deployment fails at Liquibase step**
```bash
# View execution logs
./scripts/harness/get-pipeline-executions.sh
# Note execution ID

./scripts/harness/get-execution-details.sh <execution_id>
```

---

## Files in This Demo

```
scripts/demo/
├── README.md                    # This file
├── rating-feature.patch         # Git patch with all changes
├── apply-rating-demo.sh         # Apply changes (uncommitted)
└── rollback-rating-demo.sh      # Reset git + rollback databases
```

**Database changes:**
```
db/changelog/
├── changelog-master.yaml                    # Updated with new changeset
└── changesets/008-add-product-ratings.sql   # Rating column + rollback
```

**Application changes:**
```
app/src/
├── models.py                    # Product.rating field
├── routes.py                    # Query includes rating
├── templates/index.html         # Star display
└── static/css/style.css         # Star styling
```

---

## See Also

- [Harness API Playbook](../../docs/HARNESS_API_PLAYBOOK.md) - Pipeline monitoring
- [Liquibase Flows README](../../liquibase-flows/README.md) - Policy checks
- [Terraform README](../../terraform/README.md) - Infrastructure setup
- [Scripts README](../README.md) - All available scripts
- [Troubleshooting Guide](../../docs/TROUBLESHOOTING.md) - Common issues
