#!/bin/bash
# EC2 User Data Script - Automated Harness Delegate Setup
#
# This script runs automatically when EC2 instance launches.
# It installs Docker, creates docker-compose configuration, and starts the delegate.
#
# Template variables (replaced by Terraform):
# - demo_id: Demo instance identifier
# - harness_account_id: Harness account ID
# - harness_delegate_token: Delegate authentication token
# - ecr_repository_url: ECR URL for custom delegate image
# - aws_region: AWS region
#
# Logs: /var/log/cloud-init-output.log

set -e

# Log function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Starting Harness delegate setup..."

# Update system packages
log "Updating system packages..."
dnf update -y

# Install Docker and CloudWatch agent
log "Installing Docker and CloudWatch agent..."
dnf install -y docker git amazon-cloudwatch-agent

# Start Docker service
log "Starting Docker service..."
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group (allows running docker without sudo)
log "Configuring docker group..."
usermod -aG docker ec2-user

# Configure CloudWatch agent
log "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CWCONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/aws/ec2/${demo_id}-delegate/user-data",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/docker-delegate.log",
            "log_group_name": "/aws/ec2/${demo_id}-delegate/container",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWCONFIG

# Start CloudWatch agent
log "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Install Docker Compose v2
log "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="2.24.0"
curl -L "https://github.com/docker/compose/releases/download/v$${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Verify installations
log "Verifying installations..."
docker --version
/usr/local/bin/docker-compose --version

# Create delegate directory
log "Creating delegate directory..."
mkdir -p /opt/harness-delegate
cd /opt/harness-delegate

# Login to ECR to pull custom delegate image
log "Logging into ECR..."
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${ecr_repository_url}

# Get Docker group ID for socket permissions
DOCKER_GID=$(getent group docker | cut -d: -f3)
log "Docker group GID: $DOCKER_GID"

# Create docker-compose.yml
log "Creating docker-compose configuration..."
cat > docker-compose.yml <<EOF
version: '3.7'

services:
  harness-delegate:
    image: ${ecr_repository_url}:latest
    container_name: harness-delegate-${demo_id}
    restart: unless-stopped

    # Resource limits from Harness recommendations
    cpus: 1
    mem_limit: 2g

    # Run as harness user but add docker group for socket access
    user: "1001:$DOCKER_GID"

    environment:
      # ===== REQUIRED: Harness Configuration =====
      ACCOUNT_ID: "${harness_account_id}"
      DELEGATE_TOKEN: "${harness_delegate_token}"

      # ===== Delegate Configuration =====
      DELEGATE_NAME: "${demo_id}-delegate"
      NEXT_GEN: "true"
      DELEGATE_TYPE: "DOCKER"
      DELEGATE_TAGS: "${demo_id}"

      # ===== Networking =====
      MANAGER_HOST_AND_PORT: "https://app.harness.io"

      # ===== AWS Authentication =====
      # NO AWS credentials set here!
      # Delegate automatically uses EC2 instance profile for AWS access
      # This provides temporary credentials that rotate hourly

    volumes:
      # Mount Docker socket to run Liquibase containers
      - /var/run/docker.sock:/var/run/docker.sock

      # Note: Deployment scripts are BAKED INTO IMAGE
      # No volume mount needed (scripts in /opt/harness-delegate/scripts/)

    # ===== Health Check =====
    healthcheck:
      test: ["CMD", "test", "-f", "/opt/harness-delegate/msg/data/watcher-data"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

    # ===== Logging =====
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default:
    name: harness-${demo_id}
EOF

# Pull delegate image
log "Pulling custom delegate image..."
docker-compose pull

# Create systemd service for auto-start with log redirection
log "Creating systemd service..."
cat > /etc/systemd/system/harness-delegate.service <<'EOF'
[Unit]
Description=Harness Delegate
Documentation=https://developer.harness.io/docs/platform/delegates/delegate-concepts/delegate-overview/
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/harness-delegate
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
Restart=on-failure
RestartSec=30

# Reload ECR credentials and pull image before starting
ExecStartPre=/bin/bash -c 'aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_repository_url}'
ExecStartPre=/usr/local/bin/docker-compose pull

[Install]
WantedBy=multi-user.target
EOF

# Create log streaming script for CloudWatch
log "Creating log streaming script..."
cat > /usr/local/bin/stream-delegate-logs.sh <<'LOGSCRIPT'
#!/bin/bash
# Stream delegate container logs to file for CloudWatch
while true; do
  docker logs --tail 100 -f harness-delegate-${demo_id} 2>&1 | tee -a /var/log/docker-delegate.log
  sleep 5
done
LOGSCRIPT
chmod +x /usr/local/bin/stream-delegate-logs.sh

# Create systemd service for log streaming
cat > /etc/systemd/system/delegate-logs.service <<'LOGSERVICE'
[Unit]
Description=Stream Harness Delegate Logs
After=harness-delegate.service
Requires=harness-delegate.service

[Service]
Type=simple
ExecStart=/usr/local/bin/stream-delegate-logs.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
LOGSERVICE

# Reload systemd and start delegate
log "Starting Harness delegate service..."
systemctl daemon-reload
systemctl enable harness-delegate
systemctl start harness-delegate

# Start log streaming service
log "Starting log streaming service..."
systemctl enable delegate-logs
systemctl start delegate-logs

# Wait for container to start
log "Waiting for delegate container to start..."
sleep 10

# Verify delegate is running
if docker ps | grep -q "harness-delegate-${demo_id}"; then
    log "✅ Harness delegate container is running"
    docker ps | grep harness-delegate
else
    log "❌ ERROR: Harness delegate container failed to start"
    docker-compose logs
    exit 1
fi

# Test IAM instance profile authentication
log "Testing IAM instance profile..."
if docker exec harness-delegate-${demo_id} aws sts get-caller-identity > /dev/null 2>&1; then
    log "✅ IAM instance profile is working"
    docker exec harness-delegate-${demo_id} aws sts get-caller-identity
else
    log "⚠️  WARNING: IAM instance profile test failed (may need a few minutes)"
fi

# Verify deployment scripts are present
log "Verifying deployment scripts..."
if docker exec harness-delegate-${demo_id} ls -la /opt/harness-delegate/scripts/ > /dev/null 2>&1; then
    log "✅ Deployment scripts are present"
    docker exec harness-delegate-${demo_id} ls -la /opt/harness-delegate/scripts/
else
    log "❌ ERROR: Deployment scripts not found in image"
    exit 1
fi

log "✅ Harness delegate setup complete!"
log ""
log "Next steps:"
log "1. Verify delegate connection in Harness UI:"
log "   Project Settings → Delegates → ${demo_id}-delegate"
log "   Status should be: Connected (may take 2-3 minutes)"
log ""
log "2. SSH to this instance:"
log "   ssh ec2-user@$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
log ""
log "3. View delegate logs:"
log "   docker logs -f harness-delegate-${demo_id}"
log ""
log "4. Stop local delegate (if running) and test pipeline deployment"
