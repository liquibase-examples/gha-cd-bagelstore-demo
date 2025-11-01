# Harness Delegate EC2 Infrastructure
#
# Creates EC2 instance to run Harness delegate with:
# - IAM instance profile for AWS authentication (no long-term credentials)
# - Spot instance for cost optimization (~70% savings)
# - Security group for network access
# - User data script for automated setup
#
# The delegate uses IAM instance profile to access AWS services:
# - App Runner (describe, update services)
# - RDS (describe instances)
# - Secrets Manager (get database credentials)
# - S3 (get/put artifacts)
# - ECR (pull custom delegate image)

# Data source: Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for Delegate
# Allows EC2 instance to assume this role and get temporary credentials
resource "aws_iam_role" "harness_delegate" {
  name        = "${var.demo_id}-harness-delegate-role"
  description = "IAM role for Harness delegate running on EC2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    demo_id    = var.demo_id
    managed_by = "terraform"
    purpose    = "harness-delegate"
  }
}

# IAM Policy: App Runner Access
# Allows delegate to deploy and update App Runner services
resource "aws_iam_role_policy" "delegate_apprunner" {
  name = "apprunner-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AppRunnerDeployments"
        Effect = "Allow"
        Action = [
          "apprunner:DescribeService",
          "apprunner:UpdateService",
          "apprunner:ListServices",
          "apprunner:ListTagsForResource"
        ]
        Resource = "arn:aws:apprunner:${var.aws_region}:*:service/${local.name_prefix}-*"
      }
    ]
  })
}

# IAM Policy: RDS Access
# Read-only access to RDS for metadata and connection info
resource "aws_iam_role_policy" "delegate_rds" {
  name = "rds-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RDSMetadata"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy: Secrets Manager Access
# Allows delegate to retrieve database credentials
resource "aws_iam_role_policy" "delegate_secrets" {
  name = "secrets-manager-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GetDatabaseCredentials"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.demo_id}/rds/*"
      }
    ]
  })
}

# IAM Policy: S3 Access
# Allows delegate to read/write artifacts and flow files
resource "aws_iam_role_policy" "delegate_s3" {
  name = "s3-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.name_prefix}-*",
          "arn:aws:s3:::${local.name_prefix}-*/*"
        ]
      }
    ]
  })
}

# IAM Policy: ECR Access
# Allows delegate to pull custom delegate image and application images
resource "aws_iam_role_policy" "delegate_ecr" {
  name = "ecr-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr-public:GetAuthorizationToken",
          "sts:GetServiceBearerToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRImagePull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPublicImagePull"
        Effect = "Allow"
        Action = [
          "ecr-public:BatchCheckLayerAvailability",
          "ecr-public:GetDownloadUrlForLayer",
          "ecr-public:BatchGetImage",
          "ecr-public:DescribeRepositories",
          "ecr-public:ListImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy: SSM Access
# Allows AWS Systems Manager Session Manager for secure instance access
resource "aws_iam_role_policy_attachment" "delegate_ssm" {
  role       = aws_iam_role.harness_delegate.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Policy: CloudWatch Logs Access
# Allows delegate to send logs to CloudWatch
resource "aws_iam_role_policy" "delegate_cloudwatch" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.harness_delegate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsPush"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/ec2/${var.demo_id}-delegate*"
      }
    ]
  })
}

# IAM Instance Profile
# Attaches IAM role to EC2 instance
resource "aws_iam_instance_profile" "harness_delegate" {
  name = "${var.demo_id}-harness-delegate-profile"
  role = aws_iam_role.harness_delegate.name

  tags = {
    demo_id    = var.demo_id
    managed_by = "terraform"
  }
}

# CloudWatch Log Groups
# Store delegate logs for secure viewing
resource "aws_cloudwatch_log_group" "delegate_user_data" {
  name              = "/aws/ec2/${var.demo_id}-delegate/user-data"
  retention_in_days = 7

  tags = {
    Name       = "${var.demo_id}-delegate-user-data"
    demo_id    = var.demo_id
    managed_by = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "delegate_container" {
  name              = "/aws/ec2/${var.demo_id}-delegate/container"
  retention_in_days = 7

  tags = {
    Name       = "${var.demo_id}-delegate-container"
    demo_id    = var.demo_id
    managed_by = "terraform"
  }
}

# Security Group for Delegate
# Allows outbound connections to Harness SaaS and AWS services
resource "aws_security_group" "harness_delegate" {
  name        = "${var.demo_id}-harness-delegate-sg"
  description = "Security group for Harness delegate EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # Outbound HTTPS (Harness SaaS and AWS APIs)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to Harness SaaS and AWS APIs"
  }

  # Outbound to RDS (conditional - only if deployment_mode == "aws")
  dynamic "egress" {
    for_each = var.deployment_mode == "aws" ? [1] : []
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [aws_security_group.rds[0].id]
      description     = "PostgreSQL to RDS"
    }
  }

  # Outbound HTTP for package downloads (docker, yum, etc.)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP for package downloads"
  }

  # No inbound access required - using SSM Session Manager for secure shell access

  tags = {
    Name       = "${var.demo_id}-harness-delegate-sg"
    demo_id    = var.demo_id
    managed_by = "terraform"
  }
}

# ECR Repository for Custom Delegate Image
# Stores custom delegate image with baked-in deployment scripts
resource "aws_ecr_repository" "delegate_image" {
  name                 = "${var.demo_id}/harness-delegate"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    demo_id    = var.demo_id
    managed_by = "terraform"
    purpose    = "harness-delegate-custom-image"
  }
}

# ECR Lifecycle Policy
# Keep last 5 images, delete untagged images after 7 days
resource "aws_ecr_lifecycle_policy" "delegate_image" {
  repository = aws_ecr_repository.delegate_image.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["25."] # Harness delegate version prefix
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# EC2 Spot Instance Request
# Cost-optimized delegate host (~70% cheaper than on-demand)
resource "aws_spot_instance_request" "delegate" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.medium"
  spot_type            = "persistent"
  wait_for_fulfillment = true
  spot_price           = "0.03" # Max price (current spot ~$0.0166/hr)

  iam_instance_profile        = aws_iam_instance_profile.harness_delegate.name
  vpc_security_group_ids      = [aws_security_group.harness_delegate.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true # Required for internet access to download packages

  # User data script for automated setup
  user_data = templatefile("${path.module}/user-data-delegate.sh", {
    demo_id                = var.demo_id
    harness_account_id     = var.harness_account_id
    harness_delegate_token = var.harness_delegate_token
    github_repo_url        = "https://github.com/${var.github_org}/${var.github_repo}"
    ecr_repository_url     = aws_ecr_repository.delegate_image.repository_url
    aws_region             = var.aws_region
  })

  # Root volume
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name       = "${var.demo_id}-harness-delegate-root"
      demo_id    = var.demo_id
      managed_by = "terraform"
    }
  }

  tags = {
    Name       = "${var.demo_id}-harness-delegate"
    demo_id    = var.demo_id
    managed_by = "terraform"
    purpose    = "harness-cd-delegate"
  }

  # Lifecycle: Keep instance running even if spot price increases
  lifecycle {
    ignore_changes = [spot_price]
  }
}

# Outputs
output "delegate_instance_id" {
  description = "EC2 instance ID for Harness delegate"
  value       = aws_spot_instance_request.delegate.spot_instance_id
}

output "delegate_public_ip" {
  description = "Public IP address for SSH access"
  value       = aws_spot_instance_request.delegate.public_ip
}

output "delegate_public_dns" {
  description = "Public DNS name for SSH access"
  value       = aws_spot_instance_request.delegate.public_dns
}

output "delegate_iam_role_arn" {
  description = "IAM role ARN used by delegate"
  value       = aws_iam_role.harness_delegate.arn
}

output "delegate_ecr_repository_url" {
  description = "ECR repository URL for custom delegate image"
  value       = aws_ecr_repository.delegate_image.repository_url
}

# Usage Notes:
#
# SSH to delegate:
#   EC2_IP=$(terraform output -raw delegate_public_ip)
#   ssh -i ~/.ssh/your-key.pem ec2-user@$EC2_IP
#
# View delegate logs:
#   ssh ec2-user@$EC2_IP
#   docker logs -f harness-delegate-demo1
#
# Restart delegate:
#   ssh ec2-user@$EC2_IP
#   cd /opt/harness-delegate && docker-compose restart
#
# Test IAM role:
#   ssh ec2-user@$EC2_IP
#   docker exec harness-delegate-demo1 aws sts get-caller-identity
