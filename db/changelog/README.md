# Database Changelog - Bagel Store

This directory contains Liquibase changesets for managing the Bagel Store database schema and seed data.

## Structure

```
db/changelog/
├── changelog-master.yaml          # Master changelog (YAML format)
├── changesets/                    # Individual changesets (formatted SQL)
│   ├── 001-create-products-table.sql
│   ├── 002-create-inventory-table.sql
│   ├── 003-create-orders-table.sql
│   ├── 004-create-order-items-table.sql
│   ├── 005-create-indexes.sql
│   ├── 006-seed-products.sql
│   └── 007-seed-inventory.sql
└── README.md                      # This file
```

## Database Schema

### Tables

**products**
- `id` (SERIAL PRIMARY KEY)
- `name` (VARCHAR(100) NOT NULL)
- `description` (TEXT)
- `price` (DECIMAL(10, 2) NOT NULL)
- `created_at` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

**inventory**
- `product_id` (INTEGER PRIMARY KEY, FK to products)
- `quantity` (INTEGER NOT NULL DEFAULT 0)
- `last_updated` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP)

**orders**
- `id` (SERIAL PRIMARY KEY)
- `order_date` (TIMESTAMP DEFAULT CURRENT_TIMESTAMP)
- `total_amount` (DECIMAL(10, 2) NOT NULL)
- `status` (VARCHAR(50) NOT NULL DEFAULT 'pending')

**order_items**
- `id` (SERIAL PRIMARY KEY)
- `order_id` (INTEGER NOT NULL, FK to orders)
- `product_id` (INTEGER NOT NULL, FK to products)
- `quantity` (INTEGER NOT NULL)
- `price` (DECIMAL(10, 2) NOT NULL)

### Indexes

- `idx_order_items_order_id` - Optimize order item lookups
- `idx_order_items_product_id` - Optimize product queries
- `idx_orders_status` - Optimize status filtering
- `idx_orders_date` - Optimize date-based queries

## Changeset Naming Convention

Changesets follow this pattern: `NNN-descriptive-name.sql`

- `NNN` - Three-digit sequential number (001, 002, etc.)
- `descriptive-name` - Kebab-case description of the change
- `.sql` - Formatted SQL file extension

**Examples:**
- `001-create-products-table.sql`
- `006-seed-products.sql`
- `010-add-product-category.sql` (future example)

## Formatted SQL Pattern

All changesets use Liquibase formatted SQL syntax:

```sql
--liquibase formatted sql
--changeset author:changeset-id

-- Your SQL statements here
CREATE TABLE example (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

--rollback DROP TABLE example;
```

**Key Requirements:**
- First line must be `--liquibase formatted sql`
- Second line must be `--changeset author:id`
- Must include `--rollback` statement (required by policy checks)
- Blank line between header and SQL

## Local Testing

### Prerequisites

1. **Start PostgreSQL** via Docker Compose:
   ```bash
   cd app
   docker compose up -d postgres
   ```

2. **Verify PostgreSQL is running:**
   ```bash
   docker compose ps postgres
   # Should show postgres container as healthy
   ```

### Liquibase Commands

All commands use the Liquibase Secure Docker image.

**Validate Changelog Syntax:**
```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  validate
```

**Check Status (Dry Run):**
```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  status --verbose
```

**Apply Changes:**
```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  update
```

**Rollback Last Change:**
```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  rollback-count 1
```

**Generate Changelog from Existing Database (if needed):**
```bash
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-generated.yaml \
  generate-changelog
```

## Policy Checks Compliance

The following Liquibase policy checks are enforced at **BLOCKER** severity:

### 1. RollbackRequired
**Requirement:** All changesets MUST include rollback statements.

✅ **Compliant:**
```sql
--liquibase formatted sql
--changeset demo:example
CREATE TABLE example (id SERIAL PRIMARY KEY);
--rollback DROP TABLE example;
```

❌ **Non-compliant:**
```sql
--liquibase formatted sql
--changeset demo:example
CREATE TABLE example (id SERIAL PRIMARY KEY);
-- Missing rollback statement
```

### 2. SqlSelectStarWarn
**Requirement:** Avoid `SELECT *` statements.

✅ **Compliant:**
```sql
INSERT INTO inventory (product_id, quantity)
SELECT id, 50 FROM products;
```

❌ **Non-compliant:**
```sql
INSERT INTO inventory (product_id, quantity)
SELECT * FROM products;  -- Don't use SELECT *
```

### 3. CheckTablesForIndex
**Requirement:** Tables should have appropriate indexes.

✅ **Compliant:** See changeset 005-create-indexes.sql

### 4. TableColumnLimit
**Requirement:** Tables cannot exceed 50 columns.

All our tables are well under this limit.

### 5-12. Destructive Operation Checks
**Requirement:** Avoid DROP, TRUNCATE, and risky permission changes.

These checks prevent:
- `ChangeDropColumnWarn` - Dropping columns
- `ChangeDropTableWarn` - Dropping tables
- `ChangeTruncateTableWarn` - Truncating tables
- `ModifyDataTypeWarn` - Changing data types
- `SqlGrantAdminWarn` - GRANT with ADMIN OPTION
- `SqlGrantOptionWarn` - GRANT with GRANT OPTION
- `SqlGrantWarn` - GRANT statements
- `SqlRevokeWarn` - REVOKE statements

**Note:** These are warnings in development but **BLOCKER** in CI/CD pipelines.

## AWS Integration (Production)

In production (GitHub Actions + Harness CD), Liquibase integrates with AWS:

### AWS Secrets Manager
Database credentials are stored in AWS Secrets Manager:

```bash
--username='${awsSecretsManager:demo1/rds/username}'
--password='${awsSecretsManager:demo1/rds/password}'
```

Liquibase natively reads these secrets when provided AWS credentials.

### S3 Flow Files
Flow files and policy checks are stored in S3:

```bash
liquibase flow \
  --flow-file=s3://bagel-store-demo1-liquibase-flows/pr-validation-flow.yaml
```

### Environment Variables in CI/CD
GitHub Actions uses `LIQUIBASE_COMMAND_*` environment variables:

```yaml
env:
  LIQUIBASE_COMMAND_URL: jdbc:postgresql://rds-endpoint:5432/dev
  LIQUIBASE_COMMAND_USERNAME: postgres
  LIQUIBASE_COMMAND_PASSWORD: ${{ secrets.DB_PASSWORD }}
  LIQUIBASE_LICENSE_KEY: ${{ secrets.LIQUIBASE_LICENSE_KEY }}
```

## Adding New Changesets

### Step 1: Create Changeset File

Create a new file in `changesets/` directory:

```bash
# Example: Adding a new bagel type field
cat > db/changelog/changesets/008-add-product-category.sql << 'EOF'
--liquibase formatted sql
--changeset demo:008-add-product-category

-- Add category field to products table
ALTER TABLE products
ADD COLUMN category VARCHAR(50) DEFAULT 'standard';

--rollback ALTER TABLE products DROP COLUMN category;
EOF
```

### Step 2: Update Master Changelog

Add reference in `changelog-master.yaml`:

```yaml
  - include:
      file: changesets/008-add-product-category.sql
      relativeToChangelogFile: true
```

### Step 3: Test Locally

```bash
# 1. Validate syntax
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  validate

# 2. Check what will be applied
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  status --verbose

# 3. Apply the change
docker run --rm \
  -v $(pwd)/db/changelog:/liquibase/changelog \
  liquibase/liquibase-secure:5.0.1 \
  --url=jdbc:postgresql://host.docker.internal:5432/bagelstore \
  --username=postgres \
  --password=postgres \
  --changeLogFile=changelog-master.yaml \
  update
```

### Step 4: Create Pull Request

Once tested locally:

```bash
git add db/changelog/
git commit -m "Add product category field"
git push origin feature/add-product-category
```

GitHub Actions will automatically:
- Validate the changelog
- Run policy checks (BLOCKER severity)
- Report results to the PR

## Troubleshooting

### "Connection refused" Error

**Issue:** Cannot connect to PostgreSQL

**Solution:**
```bash
# Ensure PostgreSQL is running
cd app
docker compose up -d postgres

# Check logs
docker compose logs postgres

# Verify network
docker network ls | grep bagel
```

### "Changeset already executed" Warning

**Issue:** Changeset was already applied

**Solution:** This is normal. Liquibase tracks applied changesets in `databasechangelog` table.

To view applied changesets:
```bash
docker compose exec postgres psql -U postgres -d bagelstore \
  -c "SELECT id, author, filename, dateexecuted FROM databasechangelog;"
```

### "Validation Failed" Error

**Issue:** Syntax error in changeset

**Solution:**
1. Check the error message for line number
2. Verify formatted SQL header is correct
3. Ensure rollback statement exists
4. Test SQL syntax in psql directly

### Policy Check Failures

**Issue:** BLOCKER severity check failed

**Solution:**
- Review the policy check documentation above
- Modify changeset to comply with check
- Common fixes:
  - Add `--rollback` statement
  - Avoid `SELECT *`
  - Don't use `DROP TABLE` in normal changesets
  - Include indexes for new tables

## Best Practices

1. **One Change Per Changeset**: Each changeset should do one logical thing
2. **Always Include Rollbacks**: Required by policy checks
3. **Test Locally First**: Validate before creating PR
4. **Descriptive IDs**: Use meaningful changeset identifiers
5. **Sequential Numbering**: Keep changesets numbered in order
6. **Avoid Modifications**: Never modify existing changesets after they're merged
7. **Use Tags**: Tag database versions for rollback points

## References

- [Liquibase Documentation](https://docs.liquibase.com/)
- [Liquibase Flow Files](https://docs.liquibase.com/commands/flow/home.html)
- [Formatted SQL Changelog](https://docs.liquibase.com/concepts/changelogs/sql-format.html)
- [Policy Checks](https://docs.liquibase.com/commands/quality-checks/home.html)
- [AWS Integration](https://docs.liquibase.com/workflows/liquibase-community/using-liquibase-with-aws.html)

---

**Database Version:** 1.0.0
**Last Updated:** 2025-10-05
**Changesets:** 7 (schema + seed data)
