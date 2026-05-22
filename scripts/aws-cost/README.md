# AWS Cost Optimization Scripts

Hibernate and resume AWS infrastructure to save costs when demos aren't running.

## Cost Savings

| Resource | Monthly Cost | Status |
|----------|--------------|--------|
| RDS (db.t3.micro) | $15-20 | Stoppable |
| App Runner (4 services) | $20 | Pausable |
| EC2 Spot Instance | $12 | Terminable |
| **Total Savings** | **$47-52/month** | **90% reduction** |

## Quick Start

```bash
# Hibernate (stop all resources)
./scripts/aws-cost/hibernate-infrastructure.sh

# Resume (start all resources)
./scripts/aws-cost/resume-infrastructure.sh

# Check health
./scripts/aws-cost/verify-infrastructure-health.sh
```

## Scripts

### hibernate-infrastructure.sh

Stops all AWS resources in the correct order to save costs.

**What it does:**
1. Runs pre-flight safety checks (AWS credentials, active deployments)
2. Captures current infrastructure state from Terraform
3. Terminates EC2 delegate (~8 seconds)
4. Pauses App Runner services (~2 minutes for all 4 environments)
5. Stops RDS instance (~4-5 minutes)
6. Saves state to `../aws-cost-state/hibernate-state.json`

**Time:** ~6 minutes total

**Usage:**
```bash
# Interactive hibernation (with confirmation)
./scripts/aws-cost/hibernate-infrastructure.sh

# Quick hibernation (no prompts, skip safety checks)
./scripts/aws-cost/hibernate-infrastructure.sh --force --no-confirm

# With reason tracking
./scripts/aws-cost/hibernate-infrastructure.sh --reason "Weekend shutdown"
```

**Options:**
- `--force` - Skip safety checks (active pipeline warnings)
- `--no-confirm` - Skip confirmation prompt
- `--reason "TEXT"` - Record reason for hibernation in state file
- `--help` - Show detailed help

**Exit codes:**
- `0` - Success (all resources stopped)
- `1` - Pre-flight check failed (AWS credentials, terraform missing)
- `2` - Partial failure (some resources stopped)
- `3` - Complete failure (no resources stopped)

### resume-infrastructure.sh

Starts all AWS resources in reverse order and verifies health.

**What it does:**
1. Loads state from `../aws-cost-state/hibernate-state.json`
2. Starts RDS instance (~5-10 minutes)
3. Resumes App Runner services (~2-5 minutes for all 4 environments)
4. Recreates EC2 delegate via Terraform (~3-5 minutes)
5. Runs comprehensive health checks (~30 seconds)

**Time:** ~10-15 minutes total

**Usage:**
```bash
# Standard resume (with health check)
./scripts/aws-cost/resume-infrastructure.sh

# Quick resume (skip health verification)
./scripts/aws-cost/resume-infrastructure.sh --skip-health-check

# No confirmation prompt
./scripts/aws-cost/resume-infrastructure.sh --force
```

**Options:**
- `--skip-health-check` - Skip health verification (faster resume)
- `--force` - Skip confirmation prompt
- `--help` - Show detailed help

**Exit codes:**
- `0` - Success (all resources running and healthy)
- `1` - Pre-flight check failed (state file missing, AWS credentials)
- `2` - Partial failure (some resources started but unhealthy)
- `3` - Complete failure (resources failed to start)

**Important notes:**
- Delegate will get a **new public IP address** (spot instance is recreated)
- App Runner services keep the **same URLs** (configuration preserved)
- RDS data is **fully preserved** (stopped instance, not destroyed)

### verify-infrastructure-health.sh

Quick health check to verify infrastructure is operational.

**What it checks:**

**Level 1: Infrastructure Status (AWS API)**
- RDS: `status=available`
- App Runner dev/test/staging/prod: `status=RUNNING`
- EC2 delegate: `state=running`

**Level 2: Service Connectivity (HTTP/TCP)**
- RDS: `pg_isready` connection test
- App Runner: `GET /health` returns `200 OK` (all 4 environments)
- Harness delegate: `Connected` status via Harness API

**Time:** ~30 seconds

**Usage:**
```bash
# Quick health check
./scripts/aws-cost/verify-infrastructure-health.sh

# Detailed output (shows retries, timing)
./scripts/aws-cost/verify-infrastructure-health.sh --verbose
```

**Options:**
- `--verbose` - Show detailed output with retry information
- `--help` - Show help

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

## Prerequisites

### Required Tools

1. **AWS CLI** - For managing AWS resources
   ```bash
   brew install awscli  # macOS
   apt-get install awscli  # Linux
   ```

2. **jq** - For JSON parsing
   ```bash
   brew install jq  # macOS
   apt-get install jq  # Linux
   ```

3. **Terraform** - For recreating EC2 delegate
   ```bash
   brew install terraform  # macOS
   ```

4. **pg_isready** (optional) - For RDS connectivity checks
   ```bash
   brew install libpq  # macOS
   apt-get install postgresql-client  # Linux
   ```

5. **GitHub CLI** (optional) - For checking active workflows
   ```bash
   brew install gh  # macOS
   ```

### AWS Configuration

Ensure AWS credentials are configured:

```bash
# Check current credentials
aws sts get-caller-identity

# If not configured, set up AWS SSO
aws configure sso
```

### Terraform State

Scripts expect Terraform to be initialized:

```bash
cd terraform
terraform init
terraform refresh  # Update state with current infrastructure
```

## State File

The scripts use a state file to track hibernated infrastructure: `scripts/aws-cost-state/hibernate-state.json`

**State file contents:**
```json
{
  "version": "1.0",
  "demo_id": "psr",
  "aws_region": "us-east-1",
  "hibernated_at": "2025-12-23T10:30:00Z",
  "hibernated_by": "user@example.com",
  "reason": "Weekend shutdown",

  "rds": {
    "identifier": "psr-rds",
    "endpoint": "psr-rds.abc123.us-east-1.rds.amazonaws.com:5432",
    "address": "psr-rds.abc123.us-east-1.rds.amazonaws.com",
    "port": 5432
  },

  "app_runner": {
    "dev": {
      "service_arn": "arn:aws:apprunner:...",
      "service_url": "abc123.us-east-1.awsapprunner.com",
      "service_id": "abc123"
    },
    "test": { "...": "..." },
    "staging": { "...": "..." },
    "prod": { "...": "..." }
  },

  "ec2_delegate": {
    "spot_request_id": "sir-abc123",
    "instance_id": "i-abc123def456",
    "iam_instance_profile": "psr-harness-delegate-profile"
  },

  "cost_estimate": {
    "monthly_running": 52.00,
    "monthly_hibernated": 0.00,
    "monthly_savings": 52.00,
    "currency": "USD"
  }
}
```

**Important:**
- State files are **gitignored** (contain AWS-specific identifiers)
- State file must exist for resume to work
- If state file is lost, resume will fail (manually recreate via Terraform)

## Important Warnings

### ⚠️ RDS Auto-Start After 7 Days

**AWS automatically starts stopped RDS instances after 7 days.**

If you hibernate for more than 7 days:
- RDS will auto-start on day 7
- You'll start incurring RDS costs ($15-20/month)
- App Runner and EC2 will remain stopped (partial cost savings)

**Workarounds:**
- Resume before 7 days, then hibernate again (resets timer)
- For longer hibernation, consider RDS snapshot + delete (more complex)

### ⚠️ Delegate Gets New IP on Resume

**The EC2 delegate spot instance is terminated and recreated.**

This means:
- New public IP address (cannot preserve with spot instances)
- New spot instance ID
- Same IAM role, security groups, configuration
- Harness delegate will re-register automatically

**Impact:**
- If you hardcoded the delegate IP somewhere, it will break
- SSH access requires new IP: `terraform output delegate_public_ip`
- No impact on Harness pipelines (delegate registers by name)

### ⚠️ App Runner Configuration Preserved

**App Runner services are paused, not deleted.**

This means:
- Same service URLs (no DNS changes required)
- Same service ARNs
- Same auto-scaling configuration
- Same environment variables and secrets

**What you keep:**
- All application configuration
- Custom domain mappings (if configured)
- VPC connector settings

## Troubleshooting

### Hibernate Issues

**Problem:** `terraform.tfvars not found`
- **Cause:** Running from wrong directory or file missing
- **Fix:** Run from project root: `./scripts/aws-cost/hibernate-infrastructure.sh`

**Problem:** `Failed to get terraform outputs`
- **Cause:** Terraform not initialized or state file missing
- **Fix:** `cd terraform && terraform init && terraform refresh`

**Problem:** Active pipeline detected but want to proceed
- **Cause:** Safety check found running Harness pipeline
- **Fix:** Use `--force` flag to skip safety checks

**Problem:** RDS stop timeout
- **Cause:** RDS instance taking longer than 10 minutes to stop
- **Fix:** Check AWS console, may need to wait longer or check for issues

### Resume Issues

**Problem:** `State file not found`
- **Cause:** Never ran hibernate, or state file was deleted
- **Fix:** Can't resume without state - manually start resources via AWS console

**Problem:** `Terraform apply failed`
- **Cause:** Delegate recreation failed (spot capacity, permissions)
- **Fix:** Check `/tmp/tf-apply.log`, manually run: `cd terraform && terraform apply -target=aws_spot_instance_request.delegate`

**Problem:** RDS start timeout
- **Cause:** RDS taking longer than 10 minutes to start
- **Fix:** Check AWS console, extend wait time, or check for AWS issues

**Problem:** App Runner resume timeout
- **Cause:** App Runner services taking longer than 5 minutes
- **Fix:** Check service logs: `aws apprunner list-operations --service-arn <ARN>`

**Problem:** Health check fails after successful resume
- **Cause:** Services need more time to stabilize
- **Fix:** Wait 1-2 minutes, run health check again: `./scripts/aws-cost/verify-infrastructure-health.sh`

### Health Check Issues

**Problem:** `pg_isready not found`
- **Cause:** PostgreSQL client tools not installed
- **Fix:** Install: `brew install libpq` (macOS) or `apt-get install postgresql-client` (Linux)

**Problem:** Delegate shows "Not connected yet"
- **Cause:** Delegate container still starting (takes 1-2 min after EC2 starts)
- **Fix:** Wait 1-2 minutes, run health check again

**Problem:** App Runner returns HTTP 503
- **Cause:** App starting but database not connected yet
- **Fix:** Wait 30 seconds for database connection, retry health check

## Best Practices

### When to Hibernate

**Good times:**
- End of work day (save overnight costs)
- Weekends (save ~$14 for 2 days)
- Extended breaks (holidays, vacations)
- After demo completion (when no activity planned)

**Bad times:**
- During active development (frequent start/stop is inefficient)
- When demos are scheduled soon (<2 hours away)
- When CI/CD pipelines are running

### Workflow Recommendations

1. **Check for active work first**
   ```bash
   # Check Harness pipelines
   ./scripts/harness/get-pipeline-executions.sh

   # Check GitHub Actions
   gh run list --limit 5
   ```

2. **Hibernate with reason**
   ```bash
   ./scripts/aws-cost/hibernate-infrastructure.sh --reason "End of day - no demos tomorrow"
   ```

3. **Resume before demos**
   ```bash
   # Give yourself 15 minutes before demo
   ./scripts/aws-cost/resume-infrastructure.sh
   ```

4. **Verify health before demo**
   ```bash
   ./scripts/aws-cost/verify-infrastructure-health.sh
   ```

### Cost Optimization Tips

1. **Hibernate nightly** if no overnight work planned
   - Save: ~$1.75/night × 5 nights = $8.75/week
   - Annual savings: ~$450/year

2. **Weekend hibernation** (Friday evening to Monday morning)
   - Save: ~$14/weekend × 52 weekends = $728/year

3. **Extended hibernation** (1 week during vacation)
   - Save: ~$12/week (remember RDS 7-day limit)

4. **Combine with terraform destroy** for longer periods
   - If gone >7 days, consider destroying infrastructure instead
   - Recreate when back: `terraform apply`
   - Loses data but maximum cost savings

## Monitoring

### Check Current Infrastructure Status

```bash
# Via scripts
./scripts/aws-cost/verify-infrastructure-health.sh

# Via AWS CLI
aws rds describe-db-instances --db-instance-identifier <DEMO_ID>-rds --query 'DBInstances[0].DBInstanceStatus'
aws apprunner list-services --query 'ServiceSummaryList[?ServiceName==`<DEMO_ID>-dev`].Status'
aws ec2 describe-instances --filters "Name=tag:demo_id,Values=<DEMO_ID>" --query 'Reservations[0].Instances[0].State.Name'
```

### Track Hibernation History

State files include hibernation metadata:

```bash
# View last hibernation details
jq -r '. | "Hibernated: \(.hibernated_at) by \(.hibernated_by) - Reason: \(.reason)"' scripts/aws-cost-state/hibernate-state.json
```

### Estimate Cost Savings

```bash
# From state file
jq -r '.cost_estimate | "Savings: $\(.monthly_savings)/month"' scripts/aws-cost-state/hibernate-state.json

# Calculate actual savings (days hibernated)
HIBERNATED_AT=$(jq -r '.hibernated_at' scripts/aws-cost-state/hibernate-state.json)
DAYS_HIBERNATED=$(( ($(date +%s) - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$HIBERNATED_AT" +%s)) / 86400 ))
SAVINGS=$(echo "$DAYS_HIBERNATED * 1.75" | bc)
echo "Estimated savings: \$$SAVINGS"
```

## Integration with Other Scripts

### Pre-hibernate Checks

```bash
# Check for active work before hibernating
./scripts/harness/get-pipeline-executions.sh | grep -i running
gh run list --limit 5 --json status | jq '.[] | select(.status=="in_progress")'
```

### Post-resume Validation

```bash
# Full deployment state check
./scripts/deployment/show-deployment-state.sh

# Harness delegate verification
./scripts/harness/verify-harness-entities.sh
```

## Automation (Future Enhancement)

These scripts can be integrated into automated workflows:

**Example: GitHub Actions scheduled hibernation**
```yaml
name: Nightly Hibernate
on:
  schedule:
    - cron: '0 22 * * 1-5'  # 10 PM weeknights
jobs:
  hibernate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      - name: Hibernate Infrastructure
        run: ./scripts/aws-cost/hibernate-infrastructure.sh --force --no-confirm --reason "Nightly automated hibernation"
```

**Example: Lambda scheduled resume**
- EventBridge rule triggers Lambda at 8 AM
- Lambda invokes resume script via SSM Run Command
- CloudWatch monitors for failures

## Support

For issues or questions:

1. Check [docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)
2. Check [scripts/README.md](../README.md) for related scripts
3. View script logs: `/tmp/tf-apply.log` (Terraform errors)
4. Check AWS console for resource-specific issues

## See Also

- [terraform/README.md](../../terraform/README.md) - Infrastructure documentation
- [docs/AWS_SETUP.md](../../docs/AWS_SETUP.md) - AWS configuration guide
- [scripts/harness/README.md](../harness/README.md) - Harness pipeline monitoring
- [SECURITY.md](../../SECURITY.md) - Secrets and credentials management
