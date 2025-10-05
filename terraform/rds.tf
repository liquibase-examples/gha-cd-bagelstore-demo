# RDS PostgreSQL Instance Configuration
# Single instance with 4 databases (dev, test, staging, prod)

# Security group for RDS
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security group for RDS PostgreSQL instance - ${var.demo_id}"

  # Allow PostgreSQL from anywhere (demo only - not production pattern)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL access (demo only)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-rds-sg"
    }
  )
}

# RDS subnet group using default VPC subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${local.name_prefix}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-rds-subnet-group"
    }
  )
}

# RDS PostgreSQL instance
resource "aws_db_instance" "postgres" {
  identifier     = "${local.name_prefix}-rds"
  engine         = "postgres"
  engine_version = "16.6"

  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"

  db_name  = "postgres"
  username = var.db_username
  password = var.db_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = true

  # Backup and maintenance
  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  skip_final_snapshot     = true

  # High availability (disabled for cost savings)
  multi_az = false

  # Performance and monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 0

  # Deletion protection (disabled for demo teardown)
  deletion_protection = false

  tags = merge(
    local.tags,
    {
      Name = "${local.name_prefix}-rds"
    }
  )
}

# Create databases using null_resource and psql commands
# Note: This requires psql to be installed on the machine running Terraform
resource "null_resource" "create_databases" {
  depends_on = [aws_db_instance.postgres]

  # Trigger recreation when RDS endpoint changes
  triggers = {
    rds_endpoint = aws_db_instance.postgres.endpoint
  }

  # Create dev, test, staging, prod databases
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for RDS to be ready
      sleep 30

      # Create databases
      for db in dev test staging prod; do
        PGPASSWORD='${var.db_password}' psql \
          -h ${aws_db_instance.postgres.address} \
          -U ${var.db_username} \
          -d postgres \
          -c "CREATE DATABASE $db;" || echo "Database $db may already exist"
      done
    EOT
  }
}
