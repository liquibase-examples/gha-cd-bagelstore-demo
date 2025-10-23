# Contributing to Harness Bagel Store Demo

## Development Workflow

### Phase Completion Checklist

When completing a phase or feature:

1. **Test locally** using Docker Compose (see [app/TESTING.md](app/TESTING.md))
2. **Run automated tests** if changes affect UI or database:
   ```bash
   cd app
   uv run pytest
   ```
3. **Update documentation** if patterns change
4. **Commit with descriptive message** following conventional commits style
5. **Push to trigger CI/CD workflows**

### File Organization

- **App code**: `app/src/` - Flask application with Blueprint architecture
- **Database**: `db/changelog/` - Master YAML + SQL changesets
- **Infrastructure**: `terraform/` - All AWS resources
- **CI/CD**: `.github/workflows/` - GitHub Actions
- **Deployment**: `harness/` - Harness pipelines and delegate
- **Flow files**: `liquibase-flows/` - Uploaded to S3 by Terraform
- **Documentation**: `docs/` - Technical documentation
- **Scripts**: `scripts/` - Diagnostic and helper scripts

## Before Committing: Security Checklist

### Infrastructure Changes (Terraform)

- [ ] No hardcoded AWS account names or IDs
- [ ] No hardcoded VPC/subnet/security group IDs
- [ ] No organization-specific values in `default` blocks
- [ ] All secrets use variables (never hardcoded)
- [ ] `terraform.tfvars.example` includes all required variables

### Application Changes

- [ ] No credentials in code (use `.env` files)
- [ ] `.env.example` exists with placeholders
- [ ] Secrets use environment variables or AWS Secrets Manager

### Git Safety Checks

Run these commands before committing:

```bash
# Verify .gitignore is working
git check-ignore -v app/.env terraform/terraform.tfvars harness/.env

# Check for accidentally staged secrets
git diff --staged | grep -i "password\|secret\|token\|key"
```

## Testing Requirements

### Local Testing

```bash
cd app
docker compose up --build     # Start app (http://localhost:5001)
uv run pytest                 # Run all tests
docker compose build --no-cache  # Rebuild after template changes
```

### Test Coverage

All changes that affect application logic or database schema should include tests:

- **Unit tests**: Test individual functions/classes
- **Integration tests**: Test database interactions
- **E2E tests**: Test full user workflows (Playwright)

See [app/TESTING.md](app/TESTING.md) for comprehensive testing guide.

## Code Style

### Python

- Use `uv` for dependency management (not `pip`)
- Follow PEP 8 style guide
- Add type hints for new functions
- Use docstrings for public APIs

```bash
# Install dependencies
cd app
uv sync

# Add new package
uv add <package>
```

### SQL Changesets

- Use formatted SQL files (not inline SQL in YAML)
- One changeset per file in `db/changelog/changesets/`
- Update `db/changelog/changelog-master.yaml` with new changeset
- Include rollback SQL where possible

See [db/changelog/README.md](db/changelog/README.md) for format requirements.

### Terraform

- Use variables for all environment-specific values
- Document complex resources with inline comments
- Update `terraform.tfvars.example` when adding new variables
- Test with `terraform plan` before committing

## Commit Message Format

Use conventional commits style:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(app): Add bagel inventory management page

Adds new /inventory route with CRUD operations for bagel stock.
Includes integration tests and database migrations.

Closes #42
```

```
fix(terraform): Correct Route53 zone lookup for custom domains

Zone lookup was using wrong filter causing deployment failures.
Now uses domain name filter instead of zone ID.
```

## Pull Request Process

1. **Create feature branch** from `main`
2. **Make changes** following guidelines above
3. **Run tests locally** and verify CI passes
4. **Update documentation** if needed
5. **Submit PR** with clear description
6. **Address review feedback** promptly
7. **Squash commits** if needed before merge

## Documentation Updates

Update relevant documentation when making changes:

- **README.md**: Project overview changes
- **SETUP.md**: Setup process changes
- **app/README.md**: Application architecture changes
- **terraform/README.md**: Infrastructure changes
- **CLAUDE.md**: AI guidance patterns (if new patterns emerge)
- **docs/TROUBLESHOOTING.md**: New common issues

## Getting Help

### 1. Check Documentation

Start with the [Documentation Index](CLAUDE.md#documentation-index).

### 2. Run Diagnostic Scripts

```bash
./scripts/setup/check-dependencies.sh  # General issues
./scripts/setup/diagnose-aws.sh        # AWS-specific issues
```

### 3. Review Logs

```bash
docker compose logs app       # Application logs
docker compose logs postgres  # Database logs
```

### 4. AI-Assisted Help

- Type `/setup` for guided setup assistance
- See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues

## Questions or Issues?

- **Documentation**: See [README.md](README.md) and [docs/](docs/) directory
- **Setup**: See [SETUP.md](SETUP.md)
- **Security**: See [SECURITY.md](SECURITY.md)
- **Troubleshooting**: See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
