#!/usr/bin/env bash

# Bagel Store Demo - Dependency Checker
# Checks for required tools and minimum versions across platforms
# Compatible with: macOS, Windows (WSL/Git Bash)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
ALL_CHECKS_PASSED=true

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Darwin*)    echo "Mac";;
        CYGWIN*|MINGW*|MSYS*|Linux*) echo "Windows";;
        *)          echo "Unknown";;
    esac
}

PLATFORM=$(detect_platform)

# Print section header
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
    ALL_CHECKS_PASSED=false
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Compare version numbers (returns 0 if version >= required)
version_compare() {
    local version=$1
    local required=$2

    # Remove 'v' prefix if present
    version=${version#v}
    required=${required#v}

    # Simple version comparison (works for major.minor.patch)
    printf '%s\n%s\n' "$required" "$version" | sort -V -C
}

# Extract version number from command output
get_version() {
    local cmd=$1
    local version_flag=${2:---version}
    local version_output

    version_output=$($cmd $version_flag 2>&1 | head -1)

    # Try to extract version number (handles various formats)
    echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Print installation instructions based on platform
print_install_instructions() {
    local tool=$1
    local install_url=$2

    echo ""
    print_info "Installation instructions for $tool:"
    echo ""

    case $PLATFORM in
        Mac)
            case $tool in
                Docker)
                    echo "  Download Docker Desktop: https://www.docker.com/products/docker-desktop"
                    echo "  Or install via Homebrew: brew install --cask docker"
                    ;;
                Terraform)
                    echo "  brew install terraform"
                    echo "  Or download from: https://www.terraform.io/downloads"
                    ;;
                "AWS CLI")
                    echo "  Download installer: https://awscli.amazonaws.com/AWSCLIV2.pkg"
                    echo "  Or install via Homebrew: brew install awscli"
                    ;;
                uv)
                    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
                    ;;
                Python)
                    echo "  brew install python@3.11"
                    echo "  Or download from: https://www.python.org/downloads/"
                    ;;
                Git)
                    echo "  brew install git"
                    echo "  Or download from: https://git-scm.com/downloads"
                    ;;
            esac
            ;;
        Windows)
            echo "  ${YELLOW}Windows detected - ensure you're using WSL 2${NC}"
            echo ""
            case $tool in
                Docker)
                    echo "  Download Docker Desktop: https://www.docker.com/products/docker-desktop"
                    echo "  Enable WSL 2 backend in Docker Desktop settings"
                    ;;
                Terraform)
                    echo "  In WSL Ubuntu:"
                    echo "  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
                    echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list"
                    echo "  sudo apt update && sudo apt install terraform"
                    ;;
                "AWS CLI")
                    echo "  In WSL Ubuntu:"
                    echo "  curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
                    echo "  unzip awscliv2.zip"
                    echo "  sudo ./aws/install"
                    ;;
                uv)
                    echo "  In WSL Ubuntu:"
                    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
                    ;;
                Python)
                    echo "  In WSL Ubuntu:"
                    echo "  sudo apt-get install python3.11 python3.11-venv python3-pip"
                    ;;
                Git)
                    echo "  In WSL Ubuntu:"
                    echo "  sudo apt-get install git"
                    ;;
            esac
            ;;
    esac
    echo ""
}

# Check individual tool
check_tool() {
    local tool_name=$1
    local cmd=$2
    local min_version=$3
    local version_flag=${4:---version}

    echo -n "Checking $tool_name... "

    if ! command_exists "$cmd"; then
        print_error "$tool_name not found"
        print_install_instructions "$tool_name"
        return 1
    fi

    local version
    version=$(get_version "$cmd" "$version_flag")

    if [ -z "$version" ]; then
        print_warning "$tool_name found but version could not be determined"
        echo "         Installed: $(command -v $cmd)"
        return 0
    fi

    if version_compare "$version" "$min_version"; then
        print_success "$tool_name $version (>= $min_version required)"
        return 0
    else
        print_error "$tool_name $version found, but >= $min_version required"
        print_install_instructions "$tool_name"
        return 1
    fi
}

# Special check for Docker (also checks if daemon is running)
check_docker() {
    echo -n "Checking Docker... "

    if ! command_exists docker; then
        print_error "Docker not found"
        print_install_instructions "Docker"
        return 1
    fi

    local version
    version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [ -z "$version" ]; then
        print_warning "Docker found but version could not be determined"
        return 0
    fi

    print_success "Docker $version installed"

    # Check if Docker daemon is running
    echo -n "Checking Docker daemon... "
    if docker info >/dev/null 2>&1; then
        print_success "Docker daemon is running"
    else
        print_warning "Docker is installed but daemon is not running"
        echo ""
        print_info "Start Docker Desktop or run: sudo systemctl start docker"
    fi
}

# Check for docker compose (plugin or standalone)
check_docker_compose() {
    echo -n "Checking Docker Compose... "

    # Check for compose plugin first
    if docker compose version >/dev/null 2>&1; then
        local version
        version=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Docker Compose (plugin) $version"
        return 0
    fi

    # Fall back to standalone docker-compose
    if command_exists docker-compose; then
        local version
        version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        print_success "Docker Compose (standalone) $version"
        return 0
    fi

    print_error "Docker Compose not found"
    echo ""
    print_info "Docker Compose should be included with Docker Desktop"
    print_info "Or install: https://docs.docker.com/compose/install/"
    return 1
}

# Check Python version
check_python() {
    echo -n "Checking Python... "

    local python_cmd=""

    # Try python3 first, then python
    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python; then
        python_cmd="python"
    else
        print_error "Python not found"
        print_install_instructions "Python"
        return 1
    fi

    local version
    version=$($python_cmd --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if version_compare "$version" "3.11.0"; then
        print_success "Python $version (>= 3.11 required)"
        return 0
    else
        print_error "Python $version found, but >= 3.11 required"
        print_install_instructions "Python"
        return 1
    fi
}

# Check AWS CLI configuration
check_aws_config() {
    echo -n "Checking AWS CLI configuration... "

    if ! command_exists aws; then
        print_warning "AWS CLI not installed (skipping config check)"
        return 0
    fi

    # Show active profile if set
    if [ -n "$AWS_PROFILE" ]; then
        echo ""
        print_info "Active profile: $AWS_PROFILE (via AWS_PROFILE)"
        echo -n "Testing authentication... "
    fi

    # Check if AWS credentials are configured
    if aws sts get-caller-identity >/dev/null 2>&1; then
        print_success "AWS credentials configured and working"
        local identity arn
        identity=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
        echo "         Identity: $identity"

        # Check if using SSO
        local current_profile="${AWS_PROFILE:-default}"
        if grep -q "sso_session\|sso_start_url" ~/.aws/config 2>/dev/null; then
            local sso_session
            if [ "$current_profile" = "default" ]; then
                sso_session=$(awk '/^\[default\]/,/^\[/ {if (/sso_session/) print $3}' ~/.aws/config 2>/dev/null)
            else
                sso_session=$(awk "/^\[profile $current_profile\]/,/^\[/ {if (/sso_session/) print \$3}" ~/.aws/config 2>/dev/null)
            fi
            if [ -n "$sso_session" ]; then
                echo "         Auth type: SSO (session: $sso_session)"
            fi
        fi
    else
        print_warning "AWS CLI installed but authentication failed"
        echo ""
        print_info "Run diagnostics: ./scripts/diagnose-aws.sh"
        echo ""
        print_info "Or configure AWS credentials:"
        echo "  • aws configure sso (recommended for SSO)"
        echo "  • aws configure (for access keys)"
        echo "  • export AWS_PROFILE=<profile-name>"
    fi
}

# Main execution
main() {
    clear

    print_header "Bagel Store Demo - Dependency Check"

    echo "Platform: $PLATFORM"
    echo "Date: $(date)"
    echo ""

    print_header "Required Tools"

    # Core requirements
    check_docker
    check_docker_compose
    check_tool "Terraform" "terraform" "1.0.0"
    check_tool "Git" "git" "2.0.0"
    check_python
    check_tool "uv" "uv" "0.1.0"

    print_header "Optional Tools (for AWS Deployment)"

    check_tool "AWS CLI" "aws" "2.0.0"
    check_aws_config

    print_header "Configuration Files"

    # Check for configuration files
    echo -n "Checking app/.env... "
    if [ -f "app/.env" ]; then
        print_success "Found"
    else
        print_warning "Not found"
        echo ""
        print_info "Create app/.env from template:"
        echo "  cd app && cp .env.example .env"
        echo "  Then edit app/.env with your demo credentials"
    fi

    echo -n "Checking terraform/terraform.tfvars... "
    if [ -f "terraform/terraform.tfvars" ]; then
        print_success "Found"
    else
        print_warning "Not found (required for AWS deployment)"
        echo ""
        print_info "Create terraform/terraform.tfvars from template:"
        echo "  cd terraform && cp terraform.tfvars.example terraform.tfvars"
        echo "  Then edit terraform/terraform.tfvars with your values"
    fi

    print_header "Environment Variables (for CI/CD)"

    # Check for Liquibase license key
    echo -n "Checking LIQUIBASE_LICENSE_KEY... "
    if [ -n "$LIQUIBASE_LICENSE_KEY" ]; then
        print_success "Set (${#LIQUIBASE_LICENSE_KEY} characters)"
    else
        print_warning "Not set (required for CI/CD workflows)"
        echo ""
        print_info "Liquibase license is needed for:"
        echo "  • GitHub Actions workflows (PR validation, main CI)"
        echo "  • Liquibase Flow files and policy checks"
        echo "  • Must be added as GitHub Secret: LIQUIBASE_LICENSE_KEY"
        echo ""
        print_info "Get a license key from: https://www.liquibase.com/"
        echo ""
        print_info "For local testing only (not committed to Git):"
        echo "  export LIQUIBASE_LICENSE_KEY='your-key-here'"
    fi

    print_header "Summary"

    if [ "$ALL_CHECKS_PASSED" = true ]; then
        echo ""
        print_success "All required dependencies are installed!"
        echo ""
        print_info "Next steps:"
        echo "  1. Configure app/.env (if not already done)"
        echo "  2. Start local development: cd app && docker compose up"
        echo "  3. Run tests: cd app && uv run pytest"
        echo ""
        print_info "For complete setup instructions, see: SETUP.md"
        echo ""
        exit 0
    else
        echo ""
        print_error "Some dependencies are missing or need updates"
        echo ""
        print_info "Install missing tools using the instructions above"
        print_info "Then run this script again to verify"
        echo ""
        print_info "For detailed setup help, see: SETUP.md"
        print_info "Or run: claude-code and type 'setup' for AI-guided setup"
        echo ""
        exit 1
    fi
}

# Run main function
main
