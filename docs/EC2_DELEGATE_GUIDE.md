# EC2 Delegate Operations Guide

This guide covers deploying, operating, and troubleshooting the Harness delegate running on AWS EC2.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Initial Deployment](#initial-deployment)
- [Daily Operations](#daily-operations)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Cost Management](#cost-management)
- [Updating the Delegate](#updating-the-delegate)

---

## Overview

### Architecture

```
AWS EC2 Instance (t3.medium spot)
  ↓
  IAM Instance Profile (temporary AWS credentials)
    ↓
    Docker + Docker Compose (systemd service)
      ↓
      Custom Harness Delegate (ECR image)
        - Base: Official Harness delegate
        - Added: Deployment scripts (baked in)
        - Tools: jq, AWS CLI v2, Docker CLI, Terraform
```

### Key Features

- **IAM Authentication**: No long-term AWS credentials stored
- **Cost-Optimized**: Spot instance (~70% cheaper than on-demand)
- **Auto-Restart**: Systemd service ensures delegate always runs
- **Immutable Scripts**: Deployment scripts baked into Docker image
- **24/7 Availability**: Always-on delegate (not dependent on laptop)

---

## Prerequisites

Before deploying the EC2 delegate, ensure you have:

1. **AWS Access**:
   - AWS credentials configured (AWS SSO, IAM user, or aws-vault)
   - Permissions to create EC2, IAM, ECR, and Security Group resources
   - VPC with public subnet (for EC2 internet access)

2. **Harness Access**:
   - Harness account ID
   - Harness delegate token (from Project Settings → Delegates → Tokens)
   - Harness API key (for Terraform provider)

3. **Local Tools**:
   - Terraform >= 1.5.0
   - Docker running locally
   - AWS CLI v2
   - SSH key pair for EC2 access

4. **Terraform Variables**:
   - Update `terraform/terraform.tfvars` with your values:
     ```hcl
     demo_id                 = "demo1"
     harness_account_id      = "your-account-id"
     harness_delegate_token  = "your-delegate-token"
     github_pat              = "your-github-pat"
     liquibase_license_key   = "your-liquibase-license"
     # ... other variables
     ```

---

## Initial Deployment

### Step 1: Build Custom Delegate Image

Build the custom delegate image with baked-in deployment scripts:

```bash
# From repository root
./scripts/build-delegate-image.sh

# Or specify AWS region
./scripts/build-delegate-image.sh us-east-1
```

**What this does**:
- Builds Docker image with deployment scripts
- Tags image with delegate version and `latest`
- Pushes to ECR repository (created by Terraform)

**Expected output**:
```
✓ Building custom Harness delegate image...
✓ Checking prerequisites...
✓ Docker is running
✓ AWS credentials configured: arn:aws:iam::123456789012:user/your-user
✓ Terraform state found
✓ Getting ECR repository URL from Terraform...
✓ ECR repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/demo1/harness-delegate
✓ Logging into ECR...
✓ Building Docker image...
✓ Image built successfully
✓ Tagging image for ECR...
✓ Pushing image to ECR (this may take a few minutes)...
✓ Custom delegate image successfully built and pushed to ECR
```

### Step 2: Deploy EC2 Infrastructure

Deploy the EC2 instance and supporting infrastructure:

```bash
cd terraform
terraform init   # First time only
terraform plan   # Review changes
terraform apply  # Deploy
```

**Resources created**:
- IAM role with least-privilege policies (App Runner, RDS, S3, Secrets Manager, ECR)
- IAM instance profile (attaches role to EC2)
- Security group (HTTPS outbound, SSH inbound, RDS access)
- ECR repository for custom delegate image
- EC2 spot instance (t3.medium, Amazon Linux 2023)
- EBS gp3 volume (30GB, encrypted)

**Expected time**: 3-5 minutes

### Step 3: Verify Delegate Connection

1. **Wait for user data script** (~3-5 minutes):
   ```bash
   # Get EC2 public IP
   EC2_IP=$(terraform output -raw delegate_public_ip)

   # SSH to instance and watch logs
   ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_IP
   tail -f /var/log/cloud-init-output.log
   ```

2. **Check delegate status**:
   ```bash
   # View delegate logs
   docker logs -f harness-delegate-demo1

   # Check IAM credentials
   docker exec harness-delegate-demo1 aws sts get-caller-identity

   # Verify scripts present
   docker exec harness-delegate-demo1 ls -la /opt/harness-delegate/scripts/
   ```

3. **Verify in Harness UI**:
   - Navigate to: **Project Settings** → **Delegates**
   - Look for: `demo1-delegate`
   - Status should be: **Connected** (green)
   - Last heartbeat: < 1 minute ago

---

## Daily Operations

### Viewing Delegate Logs

```bash
# SSH to EC2
EC2_IP=$(cd terraform && terraform output -raw delegate_public_ip)
ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_IP

# View live logs
docker logs -f harness-delegate-demo1

# View last 100 lines
docker logs --tail 100 harness-delegate-demo1

# Search logs for errors
docker logs harness-delegate-demo1 2>&1 | grep -i error
```

### Restarting the Delegate

```bash
# Method 1: Docker Compose restart (preserves container)
cd /opt/harness-delegate
docker-compose restart

# Method 2: Recreate container (full restart)
docker-compose down
docker-compose up -d

# Method 3: Systemd service (recommended)
sudo systemctl restart harness-delegate
```

### Stopping/Starting the Delegate

```bash
# Stop delegate
sudo systemctl stop harness-delegate

# Start delegate
sudo systemctl start harness-delegate

# Check service status
sudo systemctl status harness-delegate
```

### Updating Deployment Scripts

If you need to update deployment scripts (in `harness/scripts/`):

```bash
# 1. Edit scripts locally
vim harness/scripts/deploy-application.sh

# 2. Rebuild and push image
./scripts/build-delegate-image.sh

# 3. SSH to EC2 and pull new image
ssh ec2-user@$EC2_IP
cd /opt/harness-delegate

# 4. Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ECR_REPO_URL>

# 5. Pull new image
docker-compose pull

# 6. Restart delegate
docker-compose up -d

# 7. Verify new scripts
docker exec harness-delegate-demo1 cat /opt/harness-delegate/scripts/deploy-application.sh | head -20
```

---

## Monitoring

### Key Metrics to Watch

1. **Delegate Health**:
   - Harness UI → Project Settings → Delegates → Check "Connected" status
   - Last heartbeat should be < 1 minute

2. **EC2 Health**:
   - AWS Console → EC2 → Instances → Check instance state
   - CloudWatch Metrics: CPU utilization, memory, disk

3. **Docker Container Health**:
   ```bash
   # Check container status
   docker ps | grep harness-delegate

   # Check health check status
   docker inspect harness-delegate-demo1 | jq '.[0].State.Health'
   ```

4. **IAM Credentials**:
   ```bash
   # Verify IAM role is working
   docker exec harness-delegate-demo1 aws sts get-caller-identity

   # Should show:
   # {
   #   "UserId": "AIDAXXXXXXXXXXXXXXXXX:i-0123456789abcdef0",
   #   "Account": "123456789012",
   #   "Arn": "arn:aws:sts::123456789012:assumed-role/demo1-harness-delegate-role/i-0123456789abcdef0"
   # }
   ```

### Setting Up CloudWatch Alarms (Optional)

```bash
# Create alarm for high CPU usage
aws cloudwatch put-metric-alarm \
  --alarm-name delegate-high-cpu \
  --alarm-description "Alert when delegate CPU > 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID> \
  --evaluation-periods 2

# Create alarm for delegate disconnection
# (Requires custom metric from Harness API monitoring script)
```

---

## Troubleshooting

### Delegate Not Connecting to Harness

**Symptoms**: Delegate shows "Disconnected" in Harness UI

**Diagnosis**:
```bash
# 1. Check container is running
docker ps | grep harness-delegate

# 2. Check logs for connection errors
docker logs harness-delegate-demo1 | grep -i "error\|failed\|connection"

# 3. Verify Harness credentials
docker exec harness-delegate-demo1 env | grep -E "ACCOUNT_ID|DELEGATE_TOKEN"

# 4. Test network connectivity
docker exec harness-delegate-demo1 curl -I https://app.harness.io
```

**Solutions**:
- Verify delegate token is correct (check `terraform.tfvars`)
- Verify account ID matches Harness UI
- Check security group allows HTTPS outbound (port 443)
- Restart delegate: `docker-compose restart`
- Check EC2 instance has internet access (NAT gateway if private subnet)

### AWS Commands Fail with Permission Errors

**Symptoms**: Deployment scripts fail with "Access Denied" errors

**Diagnosis**:
```bash
# Test IAM permissions
docker exec harness-delegate-demo1 aws sts get-caller-identity
docker exec harness-delegate-demo1 aws apprunner list-services
docker exec harness-delegate-demo1 aws secretsmanager get-secret-value --secret-id demo1/rds/username
```

**Solutions**:
- Verify IAM role policies in `terraform/delegate-ec2.tf`
- Check instance profile is attached: `aws ec2 describe-instances --instance-ids <ID>`
- Update IAM policies: `cd terraform && terraform apply`
- Wait 2-3 minutes for IAM changes to propagate
- Restart delegate after IAM changes

### Deployment Scripts Not Found

**Symptoms**: Pipeline fails with "No such file or directory: /opt/harness-delegate/scripts/..."

**Diagnosis**:
```bash
# Check if scripts are in image
docker exec harness-delegate-demo1 ls -la /opt/harness-delegate/scripts/

# Check image version
docker inspect harness-delegate-demo1 | jq '.[0].Config.Image'
```

**Solutions**:
- Rebuild image with scripts: `./scripts/build-delegate-image.sh`
- Pull new image on EC2: `docker-compose pull && docker-compose up -d`
- Verify Dockerfile has `COPY scripts /opt/harness-delegate/scripts`

### Spot Instance Terminated

**Symptoms**: EC2 instance suddenly stops, delegate disconnects

**Diagnosis**:
```bash
# Check spot instance status
aws ec2 describe-spot-instance-requests \
  --filters "Name=tag:Name,Values=demo1-harness-delegate"
```

**Solutions**:
- Spot instances can be terminated if AWS needs capacity (rare for t3.medium)
- Terraform will automatically recreate spot request
- Redeploy: `terraform apply`
- Alternative: Change to on-demand instance (update `delegate-ec2.tf`)

### High Memory Usage

**Symptoms**: Delegate OOM killed, EC2 instance swap thrashing

**Diagnosis**:
```bash
# Check container memory
docker stats harness-delegate-demo1 --no-stream

# Check EC2 memory
free -h
```

**Solutions**:
- Increase EC2 instance type: `t3.medium` → `t3.large` (in `delegate-ec2.tf`)
- Increase container memory limit (in `docker-compose.yml` on EC2)
- Reduce concurrent pipeline executions

---

## Security

### IAM Role Permissions

The delegate IAM role has **least-privilege** access:

```hcl
# App Runner: Update services only (scoped to demo_id)
apprunner:DescribeService
apprunner:UpdateService
Resource: arn:aws:apprunner:*:*:service/demo1-*

# RDS: Read metadata only
rds:DescribeDBInstances

# Secrets Manager: Read DB credentials only
secretsmanager:GetSecretValue
Resource: arn:aws:secretsmanager:*:*:secret:demo1/rds/*

# S3: Access demo buckets only
s3:GetObject, s3:PutObject
Resource: arn:aws:s3:::demo1-*/*

# ECR: Pull images only
ecr:BatchGetImage, ecr:GetAuthorizationToken
```

**Security benefits**:
- No long-term credentials (instance profile provides temporary credentials)
- Resource-scoped permissions (can't access other demos' resources)
- Automatic credential rotation (every hour via AWS STS)
- CloudTrail audit logging (all API calls tracked)

### SSH Access

**Restrict SSH access** to your IP:

```bash
# Update security group in terraform/delegate-ec2.tf
resource "aws_security_group" "harness_delegate" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_IP/32"]  # Change from 0.0.0.0/0
    description = "SSH access from your IP"
  }
}

# Apply changes
terraform apply
```

**Alternative: Use AWS Systems Manager Session Manager** (no SSH key needed):

```bash
# Install session manager plugin
# https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

# Connect without SSH key
aws ssm start-session --target <INSTANCE_ID>
```

### Secrets Management

**Never commit these files**:
- `terraform/terraform.tfvars` (contains delegate token)
- `terraform/.terraform/*` (state files)
- `harness/.env` (local delegate config)

**Rotate secrets regularly**:
```bash
# Rotate delegate token (every 90 days)
# 1. Create new token in Harness UI
# 2. Update terraform.tfvars
# 3. Redeploy: terraform apply
```

---

## Cost Management

### Current Costs (~$15-20/month)

| Resource | Configuration | Monthly Cost |
|----------|--------------|--------------|
| EC2 t3.medium spot | 2 vCPU, 4GB, 730 hrs | ~$12 |
| EBS gp3 volume | 30GB | $2.40 |
| Data transfer | Minimal | $1 |
| ECR storage | <1GB | $0.10 |
| **Total** | | **~$15.50** |

### Cost Optimization Strategies

1. **Use Spot Instances** (already implemented):
   - 70% cheaper than on-demand
   - Low interruption rate for t3.medium (<5%)

2. **Stop during off-hours** (if not using webhooks):
   ```bash
   # Stop at 7 PM daily
   aws ec2 stop-instances --instance-ids <INSTANCE_ID>

   # Start at 8 AM daily
   aws ec2 start-instances --instance-ids <INSTANCE_ID>

   # Automate with cron or EventBridge
   ```
   **Savings**: ~40% reduction (~$8/month total)

3. **Use smaller instance** (t3.small):
   - Works for light workloads (< 5 concurrent deployments)
   - $6/month spot pricing (~50% savings on EC2 cost)

4. **Delete unused ECR images**:
   - Lifecycle policy already configured (keep last 5 images)
   - Manually delete old images: `aws ecr batch-delete-image`

---

## Updating the Delegate

### Quarterly Delegate Version Updates

Harness recommends updating delegates every 3-6 months for security patches.

**Process**:

1. **Check current version**:
   ```bash
   docker exec harness-delegate-demo1 env | grep DELEGATE_VERSION
   ```

2. **Find latest version**:
   - Visit: https://developer.harness.io/release-notes/delegate
   - Or check: `us-docker.pkg.dev/gar-prod-setup/harness-public/harness/delegate` tags

3. **Update Dockerfile**:
   ```bash
   vim harness/Dockerfile.delegate
   # Change: ARG DELEGATE_VERSION=25.XX.XXXXX
   ```

4. **Rebuild and deploy**:
   ```bash
   # Rebuild image
   ./scripts/build-delegate-image.sh

   # SSH to EC2
   ssh ec2-user@$EC2_IP
   cd /opt/harness-delegate

   # Pull new image
   aws ecr get-login-password | docker login --username AWS --password-stdin <ECR_REPO>
   docker-compose pull

   # Restart with new version
   docker-compose up -d

   # Verify version
   docker exec harness-delegate-demo1 env | grep DELEGATE_VERSION
   ```

5. **Verify in Harness UI**:
   - Project Settings → Delegates → demo1-delegate
   - Version should show new version number

---

## Additional Resources

- [Harness Delegate Documentation](https://developer.harness.io/docs/platform/delegates/delegate-concepts/delegate-overview/)
- [AWS EC2 Spot Instances Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-best-practices.html)
- [IAM Roles for EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Harness API Playbook](HARNESS_API_PLAYBOOK.md)

---

## Quick Reference Commands

```bash
# View delegate logs
ssh ec2-user@$EC2_IP "docker logs -f harness-delegate-demo1"

# Restart delegate
ssh ec2-user@$EC2_IP "cd /opt/harness-delegate && docker-compose restart"

# Test IAM credentials
ssh ec2-user@$EC2_IP "docker exec harness-delegate-demo1 aws sts get-caller-identity"

# View deployment scripts
ssh ec2-user@$EC2_IP "docker exec harness-delegate-demo1 ls -la /opt/harness-delegate/scripts/"

# Update deployment scripts
./scripts/build-delegate-image.sh
ssh ec2-user@$EC2_IP "cd /opt/harness-delegate && docker-compose pull && docker-compose up -d"

# Check spot instance status
aws ec2 describe-spot-instance-requests --filters "Name=tag:Name,Values=demo1-harness-delegate"

# View CloudWatch logs
aws logs tail /aws/ec2/demo1-delegate --follow
```
