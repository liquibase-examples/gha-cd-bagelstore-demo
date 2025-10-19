#!/bin/bash
# Reset all local environments to a specific version (or latest)
#
# Usage:
#   ./scripts/reset-local-environments.sh [version]
#
# Examples:
#   ./scripts/reset-local-environments.sh latest
#   ./scripts/reset-local-environments.sh v1.0.0

set -e

VERSION=${1:-latest}

echo "=== Resetting Local Environments ==="
echo "Target version: $VERSION"
echo ""

# Ensure .env file exists
if [ ! -f .env ]; then
  echo "Creating .env from template"
  cp .env.example .env
fi

# Update all version variables in .env file
sed -i.bak "s/^VERSION_DEV=.*/VERSION_DEV=${VERSION}/" .env
sed -i.bak "s/^VERSION_TEST=.*/VERSION_TEST=${VERSION}/" .env
sed -i.bak "s/^VERSION_STAGING=.*/VERSION_STAGING=${VERSION}/" .env
sed -i.bak "s/^VERSION_PROD=.*/VERSION_PROD=${VERSION}/" .env

# Remove backup file
rm -f .env.bak

echo "✅ Updated .env file:"
grep "^VERSION_" .env

# Pull images and restart services
echo ""
echo "Pulling images and restarting services..."
docker compose -f docker-compose-demo.yml pull
docker compose -f docker-compose-demo.yml up -d

echo ""
echo "✅ All environments reset to version: $VERSION"
echo ""
echo "Run: ./scripts/show-deployment-state.sh to verify"
