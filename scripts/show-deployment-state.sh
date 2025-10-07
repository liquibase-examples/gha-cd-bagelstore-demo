#!/bin/bash
# Show current deployment state for all local environments
#
# Usage:
#   ./scripts/show-deployment-state.sh

set -e

echo "=== Local Deployment State ==="
echo ""

# Show .env file state
if [ -f .env ]; then
  echo "📄 .env file versions:"
  grep "^VERSION_" .env | sort
  echo ""
else
  echo "⚠️  No .env file found (run: cp .env.example .env)"
  echo ""
fi

# Show running container state
echo "🐳 Running containers:"
echo ""
printf "%-11s | %-14s | %-6s | %s\n" "Environment" "Version" "Health" "URL"
printf "%-11s-+-%-14s-+-%-6s-+-%s\n" "-----------" "--------------" "------" "----"

for env in dev test staging prod; do
  case $env in
    dev)     PORT=5001 ;;
    test)    PORT=5002 ;;
    staging) PORT=5003 ;;
    prod)    PORT=5004 ;;
  esac

  # Check if container is running
  CONTAINER_ID=$(docker ps -q -f name=bagel-app-$env 2>/dev/null || echo "")

  if [ -n "$CONTAINER_ID" ]; then
    # Get version from /version endpoint
    VERSION=$(curl -s http://localhost:$PORT/version 2>/dev/null | jq -r '.version // "UNKNOWN"' 2>/dev/null || echo "DOWN")

    # Get health status
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")

    if [ "$HEALTH" = "200" ]; then
      STATUS="✅ OK"
    else
      STATUS="❌ DOWN"
    fi

    URL="http://localhost:$PORT"
  else
    VERSION="NOT RUNNING"
    STATUS="⚪ STOP"
    URL="-"
  fi

  printf "%-11s | %-14s | %-6s | %s\n" "$env" "$VERSION" "$STATUS" "$URL"
done

echo ""
echo "💡 Tips:"
echo "   • View logs:    docker compose -f docker-compose-demo.yml logs -f app-<env>"
echo "   • Deploy:       Run Harness pipeline or update .env + docker compose up -d"
echo "   • Reset all:    ./scripts/reset-local-environments.sh latest"
echo "   • Stop all:     docker compose -f docker-compose-demo.yml down"
echo ""
