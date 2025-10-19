#!/bin/bash
#
# Harness API Wrapper Script
# 
# Automatically loads HARNESS_API_KEY from harness/.env and makes authenticated API calls.
#
# Usage:
#   ./scripts/harness/harness-api.sh GET <endpoint> [jq_filter]
#   ./scripts/harness/harness-api.sh POST <endpoint> <json_data> [jq_filter]
#
# Examples:
#   # Get pipeline executions
#   ./scripts/harness/harness-api.sh GET "/pipeline/api/pipelines/execution/v2/LpMDt6PiSEWxlvrf0A4MhA?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" ".data.pipelineExecutionSummary.status"
#
#   # List pipelines
#   ./scripts/harness/harness-api.sh GET "/pipeline/api/pipelines/list?accountIdentifier=_dYBmxlLQu61cFhvdkV4Jw&orgIdentifier=default&projectIdentifier=bagel_store_demo" ".data.content[].name"
#
#   # Trigger pipeline via webhook
#   ./scripts/harness/harness-api.sh POST "https://app.harness.io/gateway/pipeline/api/webhook/custom/..." '{"version":"v1.0.0"}'

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error and exit
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Function to print info
info() {
    echo -e "${GREEN}$1${NC}" >&2
}

# Function to print warning
warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

# Load API key from harness/.env
load_api_key() {
    local env_file=""
    
    # Try to find harness/.env
    if [ -f "harness/.env" ]; then
        env_file="harness/.env"
    elif [ -f "../harness/.env" ]; then
        env_file="../harness/.env"
    elif [ -f "../../harness/.env" ]; then
        env_file="../../harness/.env"
    else
        error "Cannot find harness/.env file. Run from project root or ensure file exists."
    fi
    
    # Source the file
    source "$env_file"
    
    # Validate API key is set
    if [ -z "${HARNESS_API_KEY:-}" ]; then
        error "HARNESS_API_KEY not found in $env_file"
    fi
    
    # Validate API key format (should start with 'pat.')
    if [[ ! "$HARNESS_API_KEY" =~ ^pat\. ]]; then
        error "HARNESS_API_KEY has invalid format (should start with 'pat.')"
    fi
    
    info "✓ Loaded API key from $env_file (${#HARNESS_API_KEY} chars)"
}

# Function to make GET request
api_get() {
    local endpoint="$1"
    local jq_filter="${2:-.}"
    
    # Add base URL if not present
    if [[ ! "$endpoint" =~ ^https?:// ]]; then
        endpoint="https://app.harness.io${endpoint}"
    fi
    
    info "GET $endpoint"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X GET "$endpoint" \
        -H "x-api-key: ${HARNESS_API_KEY}" \
        -H "Content-Type: application/json")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Check HTTP status
    if [ "$http_code" != "200" ]; then
        error "HTTP $http_code: $(echo "$body" | jq -r '.message // .error // .' 2>/dev/null || echo "$body")"
    fi
    
    # Apply jq filter if specified
    if [ "$jq_filter" != "." ]; then
        echo "$body" | jq -r "$jq_filter"
    else
        echo "$body" | jq .
    fi
}

# Function to make POST request
api_post() {
    local endpoint="$1"
    local data="$2"
    local jq_filter="${3:-.}"
    
    # Add base URL if not present
    if [[ ! "$endpoint" =~ ^https?:// ]]; then
        endpoint="https://app.harness.io${endpoint}"
    fi
    
    info "POST $endpoint"
    
    local response
    response=$(curl -s -w "\n%{http_code}" \
        -X POST "$endpoint" \
        -H "x-api-key: ${HARNESS_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$data")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Check HTTP status
    if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
        error "HTTP $http_code: $(echo "$body" | jq -r '.message // .error // .' 2>/dev/null || echo "$body")"
    fi
    
    # Apply jq filter if specified
    if [ "$jq_filter" != "." ]; then
        echo "$body" | jq -r "$jq_filter"
    else
        echo "$body" | jq .
    fi
}

# Main script
main() {
    # Check arguments
    if [ $# -lt 2 ]; then
        cat << 'USAGE'
Harness API Wrapper Script

Usage:
  ./scripts/harness-api.sh GET <endpoint> [jq_filter]
  ./scripts/harness-api.sh POST <endpoint> <json_data> [jq_filter]

Arguments:
  GET|POST    HTTP method
  endpoint    API endpoint (with or without https://app.harness.io prefix)
  json_data   JSON data for POST requests
  jq_filter   Optional jq filter to apply to response (default: ".")

Examples:
  # Get execution status
  ./scripts/harness-api.sh GET "/pipeline/api/pipelines/execution/v2/ABC123?accountIdentifier=..." ".data.pipelineExecutionSummary.status"

  # List pipelines
  ./scripts/harness-api.sh GET "/pipeline/api/pipelines/list?accountIdentifier=..." ".data.content[].name"

  # Trigger webhook
  ./scripts/harness-api.sh POST "https://app.harness.io/gateway/pipeline/api/webhook/custom/..." '{"version":"v1.0.0"}'

Environment:
  Reads HARNESS_API_KEY from harness/.env
USAGE
        exit 1
    fi
    
    local method="$1"
    shift
    
    # Load API key
    load_api_key
    
    # Execute based on method
    case "$method" in
        GET|get)
            api_get "$@"
            ;;
        POST|post)
            if [ $# -lt 2 ]; then
                error "POST requires endpoint and JSON data arguments"
            fi
            api_post "$@"
            ;;
        *)
            error "Unknown method: $method (use GET or POST)"
            ;;
    esac
}

main "$@"
