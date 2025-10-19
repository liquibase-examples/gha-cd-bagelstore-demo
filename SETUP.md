# Bagel Store Demo - Setup Guide

Complete setup instructions for first-time developers on Windows, macOS, and Linux.

---

## Quick Start (For Experienced Developers)

```bash
# Clone repository
git clone https://github.com/your-org/harness-gha-bagelstore.git
cd harness-gha-bagelstore

# Check dependencies
./scripts/setup/check-dependencies.sh

# Configure local environment
cd app
cp .env.example .env
# Edit .env with your credentials

# Start application
docker compose up --build

# In another terminal, run tests
cd app
uv run pytest
```

Access the application at [http://localhost:5001](http://localhost:5001)

**For AI-assisted setup:** If using Claude Code, just type `setup` at the prompt.

---

## Detailed Setup Instructions

### Table of Contents

1. [Prerequisites](#prerequisites)
2. [Platform-Specific Setup](#platform-specific-setup)
3. [Verify Installation](#verify-installation)
4. [Configure Local Environment](#configure-local-environment)
5. [First Run](#first-run)
6. [Next Steps](#next-steps)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

This project requires the following tools:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **Docker Desktop** | Latest | Local development and testing |
| **Docker Compose** | Latest | Multi-container orchestration |
| **Git** | 2.0+ | Version control |
| **Python** | 3.11+ | Application runtime |
| **uv** | 0.1.0+ | Fast Python package manager |
| **Terraform** | 1.0+ | Infrastructure provisioning (AWS deployment) |
| **AWS CLI** | 2.0+ | AWS configuration (AWS deployment) |

### Required vs Optional

**Required for Local Development:**
- Docker Desktop (includes Docker Compose)
- Git
- Python 3.11+
- uv

**Required for AWS Deployment:**
- All of the above, plus:
- Terraform
- AWS CLI
- AWS account with appropriate permissions

---

## Platform-Specific Setup

Choose your operating system:

- [Windows Setup](#windows-setup)
- [macOS Setup](#macos-setup)

### Windows Setup

**Prerequisites:**
- Windows 10 version 2004 or higher (Build 19041 or higher)
- WSL 2 (Windows Subsystem for Linux) installed

#### Step 1: Install WSL 2

Open PowerShell as Administrator and run:

```powershell
wsl --install
```

This installs WSL 2 with Ubuntu by default. Restart your computer when prompted.

After restart, open Ubuntu from the Start menu and create a username/password.

#### Step 2: Install Docker Desktop

1. Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)
2. Run the installer
3. **Important:** Enable "Use WSL 2 based engine" in Settings → General
4. Under Settings → Resources → WSL Integration, enable your Ubuntu distribution

Verify Docker is working:

```bash
docker --version
docker compose version
```

#### Step 3: Install Git

**Option A - Git for Windows (Recommended):**
1. Download from [git-scm.com](https://git-scm.com/downloads)
2. Run installer with default options

**Option B - WSL Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install git
```

#### Step 4: Install Python 3.11+

**Option A - In WSL Ubuntu (Recommended):**
```bash
sudo apt-get update
sudo apt-get install python3.11 python3.11-venv python3-pip
```

**Option B - Windows native:**
1. Download from [python.org](https://www.python.org/downloads/)
2. Run installer, check "Add Python to PATH"

#### Step 5: Install uv

In WSL Ubuntu terminal:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your terminal and verify:
```bash
uv --version
```

#### Step 6: Install Terraform (Optional - for AWS deployment)

**Option A - WSL Ubuntu:**
```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

**Option B - Chocolatey:**
```powershell
choco install terraform
```

#### Step 7: Install AWS CLI (Optional - for AWS deployment)

**Option A - WSL Ubuntu:**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

**Option B - Windows installer:**
Download from [AWS CLI installer](https://awscli.amazonaws.com/AWSCLIV2.msi)

**Important for Windows Users:**
- Use WSL Ubuntu terminal for all bash commands
- Clone the repository in your WSL home directory: `/home/yourusername/`
- Docker Desktop must be running before using `docker` commands
- Git Bash also works but WSL 2 is recommended for best compatibility

---

### macOS Setup

#### Step 1: Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Step 2: Install Docker Desktop

**Option A - Download:**
1. Download [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop)
2. Open the .dmg file and drag Docker to Applications
3. Start Docker Desktop from Applications

**Option B - Homebrew:**
```bash
brew install --cask docker
```

Verify installation:
```bash
docker --version
docker compose version
```

#### Step 3: Install Git

```bash
brew install git
```

Or download from [git-scm.com](https://git-scm.com/downloads)

#### Step 4: Install Python 3.11+

```bash
brew install python@3.11
```

Verify:
```bash
python3 --version
```

#### Step 5: Install uv

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Restart your terminal and verify:
```bash
uv --version
```

#### Step 6: Install Terraform (Optional - for AWS deployment)

```bash
brew install terraform
```

#### Step 7: Install AWS CLI (Optional - for AWS deployment)

**Option A - Homebrew:**
```bash
brew install awscli
```

**Option B - Official installer:**
Download from [AWS CLI for macOS](https://awscli.amazonaws.com/AWSCLIV2.pkg)

---

## Verify Installation

We provide an automated dependency checker that verifies all tools are installed with correct versions.

### Run Dependency Check

```bash
cd harness-gha-bagelstore
./scripts/setup/check-dependencies.sh
```

The script will:
- ✓ Check for all required tools
- ✓ Verify minimum version requirements
- ✓ Test Docker daemon is running
- ✓ Check AWS configuration (if installed)
- ✓ Provide installation instructions for missing tools

**Expected output if all checks pass:**

```
═══════════════════════════════════════════════════════════
  All required dependencies are installed!
═══════════════════════════════════════════════════════════

ℹ Next steps:
  1. Configure app/.env (if not already done)
  2. Start local development: cd app && docker compose up
  3. Run tests: cd app && uv run pytest
```

**If checks fail:**
- Follow the installation instructions provided by the script
- Re-run the script until all checks pass

---

## Configure Local Environment

### Step 1: Clone Repository

```bash
git clone https://github.com/your-org/harness-gha-bagelstore.git
cd harness-gha-bagelstore
```

### Step 2: Configure Application Environment

Create a local environment file for the Flask application:

```bash
cd app
cp .env.example .env
```

Edit `app/.env` with your preferred credentials:

```bash
# Example .env content
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/dev
SECRET_KEY=dev-secret-key-change-in-production
FLASK_ENV=development
PORT=5000

# Demo user credentials (for local development and testing)
DEMO_USERNAME=demo
DEMO_PASSWORD=SecurePassword123!
```

**Important:**
- `.env` is gitignored and never committed
- Choose a strong password for `DEMO_PASSWORD`
- These credentials are used for local testing only

### Step 3: Configure AWS (Optional - Only for AWS Deployment)

If you plan to deploy to AWS, you'll need to:
1. Configure AWS credentials (SSO or access keys)
2. Create terraform configuration file

**Skip this section if you're only doing local development.**

#### Choose Your AWS Authentication Method

**Which authentication method should I use?**

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **AWS SSO** | Enterprise/Organization accounts | Secure, temporary credentials, MFA support | Requires SSO setup, sessions expire |
| **IAM Access Keys** | Personal AWS accounts, CI/CD | Simple setup, long-lived | Less secure, manual rotation needed |

**Decision Guide:**
- ✅ **Use AWS SSO** if your organization uses AWS SSO
- ✅ **Use Access Keys** if you have a personal AWS account or simple setup
- ⚠️ Never commit access keys to Git

#### Option A: Configure AWS SSO (Enterprise/Organization)

**Prerequisites:**
- Your organization must have AWS SSO configured
- You need your SSO start URL (e.g., `https://mycompany.awsapps.com/start`)

**Setup Steps:**

1. Run the SSO configuration wizard:
   ```bash
   aws configure sso
   ```

2. Enter your organization's SSO details when prompted:
   ```
   SSO start URL: https://your-org.awsapps.com/start
   SSO region: us-east-1
   SSO registration scopes: sso:account:access
   ```

3. A browser will open for authentication
   - Log in with your organization credentials
   - Approve the AWS CLI access request

4. Select your AWS account and role from the list

5. Configure the CLI profile:
   ```
   CLI default client Region: us-east-1
   CLI default output format: json
   CLI profile name: my-project
   ```

6. Log in to activate your SSO session:
   ```bash
   aws sso login --profile my-project
   ```

7. Set as active profile:
   ```bash
   export AWS_PROFILE=my-project
   ```

   Make permanent by adding to `~/.zshrc` or `~/.bashrc`:
   ```bash
   echo 'export AWS_PROFILE=my-project' >> ~/.zshrc
   ```

8. Verify it works:
   ```bash
   aws sts get-caller-identity
   ```

**Common SSO Issues:**

| Problem | Solution |
|---------|----------|
| "SSO session expired" | Run: `aws sso login --profile <profile-name>` |
| "No profile specified" | Set: `export AWS_PROFILE=<profile-name>` |
| "Invalid grant" error | Re-run: `aws configure sso` |

#### Option B: Configure IAM Access Keys (Personal/Simple)

**Prerequisites:**
- AWS account with IAM user created
- Access key ID and secret access key

**Create Access Keys:**
1. Log in to [AWS Console](https://console.aws.amazon.com)
2. Go to IAM → Users → Your User → Security Credentials
3. Click "Create access key" → Choose "Command Line Interface (CLI)"
4. Save the Access Key ID and Secret Access Key

**Configure AWS CLI:**

```bash
aws configure
```

Enter your credentials when prompted:
```
AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name: us-east-1
Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

#### Run AWS Diagnostics

After configuring AWS, run our diagnostic script to verify everything:

```bash
./scripts/setup/diagnose-aws.sh
```

This comprehensive script will:
- ✅ Check AWS CLI installation and version
- ✅ List all configured profiles
- ✅ Show which profile is currently active
- ✅ Test authentication and permissions
- ✅ Verify SSO session status (if applicable)
- ✅ Identify common configuration errors

**Troubleshooting:** If you encounter any AWS issues, always run this diagnostic script first!

#### Configure Terraform Variables

Once AWS credentials are working, create your Terraform configuration:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
demo_id      = "demo1"
aws_region   = "us-east-1"
aws_username = "your-aws-username"  # Get with: aws sts get-caller-identity
db_username  = "postgres"
db_password  = "ChangeMe123!SecurePassword"
github_org   = "your-github-org"
github_pat   = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Optional: Enable custom DNS (requires Route53)
enable_route53 = false
```

**Security Note:**
- `terraform.tfvars` is gitignored and never committed
- Use strong passwords for production deployments
- See [terraform/README.md](terraform/README.md) for detailed AWS setup

---

## First Run

### Start Local Development Environment

1. **Ensure Docker Desktop is running**

2. **Start the application stack:**
   ```bash
   cd app
   docker compose up --build
   ```

   This will:
   - Start PostgreSQL database
   - Build the Flask application image
   - Initialize database schema
   - Start the web server

3. **Wait for services to be ready** (first run may take 2-3 minutes):
   ```
   ✔ Container app-postgres-1  Healthy
   ✔ Container app-app-1       Started
   ```

4. **Access the application:**
   - Open browser to [http://localhost:5001](http://localhost:5001)
   - Login with credentials from your `.env` file

**Important Notes:**
- **Port 5001** is used externally (macOS uses 5000 for AirPlay)
- Press `Ctrl+C` to stop the containers
- Use `docker compose down` to stop and remove containers

### Run Automated Tests

In a new terminal:

```bash
cd app
uv run pytest
```

Expected output:
```
================ test session starts ================
collected 15 items

tests/test_health_check.py ....           [ 26%]
tests/test_e2e_shopping.py ...........    [100%]

================ 15 passed in 12.34s ================
```

For more testing options, see [app/TESTING.md](app/TESTING.md).

---

## Next Steps

### Local Development

You're now ready to develop locally! See:
- [app/README.md](app/README.md) - Application architecture and development
- [app/TESTING.md](app/TESTING.md) - Comprehensive testing guide
- [CLAUDE.md](CLAUDE.md) - Development patterns and best practices

### AWS Deployment and CI/CD

To set up the complete CI/CD pipeline:

1. **Configure GitHub Secrets** (Repository Settings → Secrets and variables → Actions):
   ```
   AWS_ACCESS_KEY_ID       - For S3 and Secrets Manager access
   AWS_SECRET_ACCESS_KEY   - For S3 and Secrets Manager access
   LIQUIBASE_LICENSE_KEY   - Liquibase Pro/Secure license key (required!)
   HARNESS_WEBHOOK_URL     - Harness pipeline webhook
   DEMO_ID                 - Demo instance identifier (e.g., "demo1")
   ```

   **Getting a Liquibase License:**
   - Free trial: https://www.liquibase.com/trial
   - Required for Flow files and policy checks
   - Needed for GitHub Actions workflows

2. **Provision AWS Infrastructure:**
   - See [terraform/README.md](terraform/README.md)

3. **Set Up Harness CD:**
   - See [harness/README.md](harness/README.md)

4. **Complete Deployment Workflow:**
   - See [README.md](README.md)

### Learning the System

Explore these resources to understand the complete system:
- [README.md](README.md) - Architecture overview and demo walkthrough
- [requirements-design-plan.md](requirements-design-plan.md) - Complete system design
- [liquibase-flows/README.md](liquibase-flows/README.md) - Database change management

---

## Troubleshooting

### Docker Issues

**Problem:** Docker daemon not running
```
Cannot connect to the Docker daemon
```

**Solution:**
- **macOS/Windows:** Start Docker Desktop from Applications
- **Linux:** `sudo systemctl start docker`

---

**Problem:** Port 5000 or 5001 already in use
```
Error starting userland proxy: listen tcp4 0.0.0.0:5001: bind: address already in use
```

**Solution:**
```bash
# Find process using the port
lsof -ti:5001

# Kill the process
lsof -ti:5001 | xargs kill

# Or use a different port in docker-compose.yml
```

---

**Problem:** Permission denied when running Docker
```
permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
- **Linux:** Add user to docker group: `sudo usermod -aG docker $USER` (then log out/in)
- **macOS/Windows:** Docker Desktop should handle permissions automatically

---

### Python/uv Issues

**Problem:** uv command not found
```
bash: uv: command not found
```

**Solution:**
```bash
# Reinstall uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Restart terminal or source profile
source ~/.bashrc  # or ~/.zshrc on macOS
```

---

**Problem:** Python version too old
```
Python 3.9.x found, but >= 3.11 required
```

**Solution:**
- Install Python 3.11+ using platform-specific instructions above
- Ensure `python3 --version` shows 3.11+

---

### AWS Issues

**ALWAYS run the AWS diagnostic script first for AWS issues:**
```bash
./scripts/setup/diagnose-aws.sh
```

This will identify the exact problem and provide specific solutions.

---

**Problem:** AWS credentials not configured
```
Unable to locate credentials
```

**Solution:**
```bash
# Configure AWS credentials
aws configure sso  # For SSO
# Or
aws configure      # For access keys

# Verify
aws sts get-caller-identity

# If still not working
./scripts/setup/diagnose-aws.sh
```

---

**Problem:** SSO session expired
```
An error occurred (ExpiredToken) when calling the GetCallerIdentity operation
```

**Solution:**
```bash
# Login again
aws sso login --profile <your-profile-name>

# Verify
aws sts get-caller-identity
```

---

**Problem:** Wrong AWS profile active
```
Using credentials from a different account than expected
```

**Solution:**
```bash
# List all profiles
aws configure list-profiles

# Set the correct profile
export AWS_PROFILE=<profile-name>

# Verify which profile is active
./scripts/setup/diagnose-aws.sh
```

---

**Problem:** Typo in AWS config path
```
~/.aaws/credentials or ~/.aaws/config exists
```

**Solution:**
```bash
# The correct path is ~/.aws/ (not ~/.aaws/)
# Move files to correct location
mv ~/.aaws/* ~/.aws/
rmdir ~/.aaws
```

---

**Problem:** Invalid AWS permissions
```
AccessDenied errors when running AWS commands
```

**Solution:**
```bash
# Check which permissions you have
./scripts/setup/diagnose-aws.sh

# The script will test:
# - S3 access (required for Liquibase flows)
# - Secrets Manager access (required for DB credentials)
# - RDS access (required for database)

# Contact your AWS administrator if you're missing permissions
```

---

**Problem:** Terraform command not found
```
bash: terraform: command not found
```

**Solution:**
- Install Terraform using platform-specific instructions above
- Verify: `terraform --version`

---

### Application Issues

**Problem:** Tests failing after first run
```
FAILED tests/test_e2e_shopping.py::test_login_success
```

**Solution:**
```bash
# Rebuild containers without cache
docker compose build --no-cache
docker compose up -d

# Re-run tests
uv run pytest
```

---

**Problem:** Database connection errors
```
psycopg2.OperationalError: could not connect to server
```

**Solution:**
```bash
# Check database is running
docker compose ps

# Check database logs
docker compose logs postgres

# Restart services
docker compose restart
```

---

### Getting Help

1. **Check documentation:**
   - [app/TESTING.md](app/TESTING.md) - Testing troubleshooting
   - [CLAUDE.md](CLAUDE.md) - Common issues and solutions
   - [README.md](README.md) - Architecture and workflows

2. **Use automated checkers:**
   ```bash
   # General dependency check
   ./scripts/setup/check-dependencies.sh

   # AWS-specific diagnostics
   ./scripts/setup/diagnose-aws.sh
   ```

3. **AI-assisted help (Claude Code users):**
   - Type `setup` for guided setup assistance
   - Describe your issue for troubleshooting help

4. **Review logs:**
   ```bash
   # Application logs
   docker compose logs app

   # Database logs
   docker compose logs postgres

   # All logs
   docker compose logs
   ```

5. **Reset environment:**
   ```bash
   # Stop and remove all containers
   docker compose down

   # Remove volumes (WARNING: deletes database data)
   docker compose down -v

   # Rebuild from scratch
   docker compose up --build
   ```

---

## Additional Resources

### Documentation
- [Docker Documentation](https://docs.docker.com/)
- [Python uv Documentation](https://docs.astral.sh/uv/)
- [Terraform Documentation](https://developer.hashicorp.com/terraform)
- [AWS CLI Documentation](https://docs.aws.amazon.com/cli/)
- [Liquibase Documentation](https://docs.liquibase.com/)
- [Flask Documentation](https://flask.palletsprojects.com/)

### Project-Specific
- [README.md](README.md) - Project overview and architecture
- [CLAUDE.md](CLAUDE.md) - AI assistant instructions and patterns
- [requirements-design-plan.md](requirements-design-plan.md) - System design document

### Support
- GitHub Issues: Report bugs or request features
- Team Chat: Reach out to the development team

---

**Happy coding! 🥯**
