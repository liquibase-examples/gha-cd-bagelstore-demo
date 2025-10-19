#!/usr/bin/env bash

# Bagel Store Demo - AWS Diagnostics
# Comprehensive AWS configuration diagnostics and troubleshooting
# Compatible with: macOS, Windows (WSL)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Track overall status
ISSUES_FOUND=false

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
    ISSUES_FOUND=true
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ISSUES_FOUND=true
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Print action message
print_action() {
    echo -e "${CYAN}→${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get AWS CLI version
get_aws_version() {
    aws --version 2>&1 | grep -oE 'aws-cli/[0-9]+\.[0-9]+\.[0-9]+' | cut -d'/' -f2
}

# Check AWS CLI installation
check_aws_cli() {
    print_header "AWS CLI Installation"

    if ! command_exists aws; then
        print_error "AWS CLI is not installed"
        echo ""
        print_info "Install AWS CLI:"
        echo "  macOS: brew install awscli"
        echo "  Windows (WSL): https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        echo ""
        return 1
    fi

    local version
    version=$(get_aws_version)
    print_success "AWS CLI version $version installed"

    # Check if version is >= 2.0
    local major_version
    major_version=$(echo "$version" | cut -d'.' -f1)
    if [ "$major_version" -lt 2 ]; then
        print_warning "AWS CLI v1.x detected. Version 2.x recommended for SSO support"
        echo ""
        print_action "Upgrade: brew upgrade awscli (macOS)"
    fi
}

# List all configured profiles
list_profiles() {
    print_header "Configured Profiles"

    if [ ! -f ~/.aws/config ]; then
        print_warning "No AWS config file found at ~/.aws/config"
        echo ""
        print_info "Configure AWS with: aws configure"
        echo "  Or for SSO: aws configure sso"
        return 1
    fi

    # Extract profile names from config
    local profiles
    profiles=$(grep -E '^\[profile ' ~/.aws/config | sed 's/\[profile \(.*\)\]/\1/' 2>/dev/null || echo "")

    # Also check for [default] profile
    if grep -q '^\[default\]' ~/.aws/config 2>/dev/null; then
        profiles="default"$'\n'"$profiles"
    fi

    if [ -z "$profiles" ]; then
        print_warning "No profiles configured"
        echo ""
        print_info "Configure a profile:"
        echo "  Basic: aws configure"
        echo "  SSO:   aws configure sso"
        return 1
    fi

    echo "Found $(echo "$profiles" | wc -l | tr -d ' ') profile(s):"
    echo ""

    while IFS= read -r profile; do
        [ -z "$profile" ] && continue
        print_info "Profile: $profile"

        # Check if SSO or credentials-based
        if [ "$profile" = "default" ]; then
            local config_section="default"
        else
            local config_section="profile $profile"
        fi

        # Check for SSO configuration (check both sso_start_url and sso_session)
        local sso_start_url sso_session sso_account_id
        sso_start_url=$(awk "/^\[$config_section\]/,/^\[/ {if (/sso_start_url/) print \$3}" ~/.aws/config 2>/dev/null)
        sso_session=$(awk "/^\[$config_section\]/,/^\[/ {if (/sso_session/) print \$3}" ~/.aws/config 2>/dev/null)
        sso_account_id=$(awk "/^\[$config_section\]/,/^\[/ {if (/sso_account_id/) print \$3}" ~/.aws/config 2>/dev/null)

        if [ -n "$sso_start_url" ] || [ -n "$sso_session" ]; then
            echo "         Type: SSO"
            if [ -n "$sso_session" ]; then
                echo "         SSO Session: $sso_session"
            fi
            if [ -n "$sso_account_id" ]; then
                echo "         SSO Account: $sso_account_id"
            fi
        else
            # Check if credentials exist
            if grep -q "^\[$profile\]" ~/.aws/credentials 2>/dev/null; then
                echo "         Type: IAM Credentials"
            else
                # Check for role_arn (assume role)
                local role_arn
                role_arn=$(awk "/^\[$config_section\]/,/^\[/ {if (/role_arn/) print \$3}" ~/.aws/config 2>/dev/null)
                if [ -n "$role_arn" ]; then
                    echo "         Type: Assume Role"
                    echo "         Role ARN: $role_arn"
                else
                    echo "         Type: Unknown (incomplete configuration)"
                fi
            fi
        fi

        # Show region
        local region
        region=$(awk "/^\[$config_section\]/,/^\[/ {if (/^region/) print \$3}" ~/.aws/config 2>/dev/null)
        if [ -n "$region" ]; then
            echo "         Region: $region"
        fi

        echo ""
    done <<< "$profiles"
}

# Check active profile
check_active_profile() {
    print_header "Active Profile"

    # Check AWS_PROFILE environment variable
    if [ -n "$AWS_PROFILE" ]; then
        print_success "Active profile: $AWS_PROFILE (via AWS_PROFILE environment variable)"
        return 0
    fi

    # Check AWS_DEFAULT_PROFILE
    if [ -n "$AWS_DEFAULT_PROFILE" ]; then
        print_success "Active profile: $AWS_DEFAULT_PROFILE (via AWS_DEFAULT_PROFILE)"
        return 0
    fi

    # Check if default profile exists
    if grep -q '^\[default\]' ~/.aws/config 2>/dev/null || \
       grep -q '^\[default\]' ~/.aws/credentials 2>/dev/null; then
        print_info "Using 'default' profile (no AWS_PROFILE set)"
        return 0
    fi

    print_warning "No active profile detected"
    echo ""
    print_info "Set active profile:"
    echo "  export AWS_PROFILE=<profile-name>"
    echo "  Or configure default: aws configure"
}

# Check SSO session status
check_sso_status() {
    print_header "SSO Session Status"

    local current_profile="${AWS_PROFILE:-default}"

    # Determine config section name
    local config_section
    if [ "$current_profile" = "default" ]; then
        config_section="default"
    else
        config_section="profile $current_profile"
    fi

    # Check if this is an SSO profile
    local sso_start_url
    sso_start_url=$(awk "/^\[$config_section\]/,/^\[/ {if (/sso_start_url/) print \$3}" ~/.aws/config 2>/dev/null)

    if [ -z "$sso_start_url" ]; then
        print_info "Profile '$current_profile' does not use SSO"
        return 0
    fi

    print_info "Profile '$current_profile' uses SSO"

    # Check SSO cache directory
    if [ ! -d ~/.aws/sso/cache ]; then
        print_warning "No SSO cache found - not logged in"
        echo ""
        print_action "Login with: aws sso login --profile $current_profile"
        return 1
    fi

    # Try to validate SSO session by making an API call
    if aws sts get-caller-identity --profile "$current_profile" >/dev/null 2>&1; then
        print_success "SSO session is active and valid"
        return 0
    else
        print_warning "SSO session expired or invalid"
        echo ""
        print_action "Login with: aws sso login --profile $current_profile"
        return 1
    fi
}

# Test AWS authentication
test_authentication() {
    print_header "Authentication Test"

    local current_profile="${AWS_PROFILE:-default}"

    echo "Testing authentication for profile: $current_profile"
    echo ""

    # Try to get caller identity
    local identity
    if identity=$(aws sts get-caller-identity --output json 2>&1); then
        print_success "Successfully authenticated to AWS"
        echo ""

        # Parse and display identity info
        local account
        local arn
        local user_id
        account=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
        arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
        user_id=$(echo "$identity" | grep -o '"UserId": "[^"]*"' | cut -d'"' -f4)

        print_info "AWS Account: $account"
        print_info "Identity ARN: $arn"
        print_info "User ID: $user_id"
    else
        print_error "Failed to authenticate to AWS"
        echo ""
        echo "Error details:"
        echo "$identity" | sed 's/^/  /'
        echo ""

        # Provide specific guidance based on error
        if echo "$identity" | grep -q "ExpiredToken"; then
            print_action "SSO session expired. Login with: aws sso login --profile $current_profile"
        elif echo "$identity" | grep -q "InvalidClientTokenId"; then
            print_action "Invalid credentials. Reconfigure with: aws configure --profile $current_profile"
        elif echo "$identity" | grep -q "could not be found"; then
            print_action "Profile not found. List profiles with: aws configure list-profiles"
        else
            print_action "Check your AWS configuration in ~/.aws/config and ~/.aws/credentials"
        fi

        return 1
    fi
}

# Check for common configuration issues
check_common_issues() {
    print_header "Common Configuration Issues"

    local issues_found=false

    # Check for typos in directory name
    if [ -d ~/.aaws ]; then
        print_warning "Found ~/.aaws directory (should be ~/.aws)"
        echo "         This is likely a typo - AWS configuration should be in ~/.aws/"
        issues_found=true
    fi

    # Check file permissions
    if [ -f ~/.aws/credentials ]; then
        local perms
        perms=$(stat -f "%A" ~/.aws/credentials 2>/dev/null || stat -c "%a" ~/.aws/credentials 2>/dev/null)
        if [ "$perms" != "600" ]; then
            print_warning "Credentials file permissions are $perms (should be 600)"
            echo ""
            print_action "Fix with: chmod 600 ~/.aws/credentials"
            issues_found=true
        fi
    fi

    # Check for empty config
    if [ -f ~/.aws/config ] && [ ! -s ~/.aws/config ]; then
        print_warning "Config file exists but is empty"
        issues_found=true
    fi

    # Check for conflicting environment variables
    if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_PROFILE" ]; then
        print_warning "Both AWS_ACCESS_KEY_ID and AWS_PROFILE are set"
        echo "         AWS_ACCESS_KEY_ID takes precedence and will override profile"
        issues_found=true
    fi

    if ! $issues_found; then
        print_success "No common configuration issues found"
    fi
}

# Check required permissions for this project
check_permissions() {
    print_header "Required Permissions Check"

    print_info "Checking permissions required for Bagel Store Demo..."
    echo ""

    # Test S3 access
    echo -n "Testing S3 access... "
    if aws s3 ls >/dev/null 2>&1; then
        print_success "S3 access OK"
    else
        print_warning "Cannot list S3 buckets (required for Liquibase flows)"
    fi

    # Test Secrets Manager access
    echo -n "Testing Secrets Manager access... "
    if aws secretsmanager list-secrets --max-results 1 >/dev/null 2>&1; then
        print_success "Secrets Manager access OK"
    else
        print_warning "Cannot access Secrets Manager (required for database credentials)"
    fi

    # Test RDS access
    echo -n "Testing RDS access... "
    if aws rds describe-db-instances --max-records 1 >/dev/null 2>&1; then
        print_success "RDS access OK"
    else
        print_warning "Cannot access RDS (required for database infrastructure)"
    fi

    echo ""
    print_info "Note: Permission warnings are OK if you haven't deployed infrastructure yet"
}

# Provide next steps
provide_next_steps() {
    print_header "Next Steps"

    if ! $ISSUES_FOUND; then
        print_success "AWS configuration looks good!"
        echo ""
        print_info "You're ready to:"
        echo "  1. Deploy infrastructure: cd terraform && terraform apply"
        echo "  2. Start local development: cd app && docker compose up"
        echo ""
        return 0
    fi

    print_info "Address the issues above, then:"
    echo ""
    echo "  1. Verify configuration: aws configure list"
    echo "  2. Test authentication: aws sts get-caller-identity"
    echo "  3. Re-run diagnostics: ./scripts/diagnose-aws.sh"
    echo ""

    print_info "Common fixes:"
    echo "  • SSO login:        aws sso login --profile <profile-name>"
    echo "  • Set profile:      export AWS_PROFILE=<profile-name>"
    echo "  • Reconfigure:      aws configure"
    echo "  • Configure SSO:    aws configure sso"
    echo ""
}

# Main execution
main() {
    clear

    print_header "AWS Configuration Diagnostics"

    echo "This script will check your AWS configuration and identify any issues."
    echo "Run this whenever you have AWS authentication problems."
    echo ""

    # Run all checks
    check_aws_cli || exit 1
    list_profiles
    check_active_profile
    check_sso_status
    test_authentication
    check_common_issues
    check_permissions
    provide_next_steps

    echo ""

    if $ISSUES_FOUND; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main
