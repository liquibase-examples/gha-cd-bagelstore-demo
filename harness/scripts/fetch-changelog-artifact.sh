#!/bin/bash
# Fetch Changelog Artifact from GitHub Actions
#
# Downloads the changelog artifact from GitHub Actions artifact storage
# and extracts it to a Docker volume for use by Liquibase.
#
# Usage:
#   fetch-changelog-artifact.sh <VERSION> <GITHUB_ORG> <GITHUB_PAT>
#
# Arguments:
#   VERSION      - Git tag/version (e.g., v1.0.0)
#   GITHUB_ORG   - GitHub organization name (e.g., liquibase-examples)
#   GITHUB_PAT   - GitHub Personal Access Token for API authentication
#
# Exit Codes:
#   0 - Success
#   1 - Artifact not found or download failed

set -e

# ===== Argument Parsing =====
if [ $# -ne 3 ]; then
  echo "Usage: $0 <VERSION> <GITHUB_ORG> <GITHUB_PAT>"
  echo "Example: $0 v1.0.0 liquibase-examples ghp_xxxxx"
  exit 1
fi

VERSION="$1"
GITHUB_ORG="$2"
GITHUB_PAT="$3"

# ===== Configuration =====
REPO="${GITHUB_ORG}/gha-cd-bagelstore-demo"
ARTIFACT_NAME="changelog-${VERSION}"
VOLUME_NAME="harness-changelog-data"
WORK_DIR="/changelog"

# ===== Main Logic =====
echo "=== Fetching Changelog Artifact ==="
echo "Version: ${VERSION}"
echo "Repository: ${REPO}"
echo "Artifact: ${ARTIFACT_NAME}"
echo "Volume: ${VOLUME_NAME}"

# Create Docker volume if it doesn't exist
docker volume create "${VOLUME_NAME}" >/dev/null 2>&1 || true

# Get artifact download URL from GitHub API
echo "Querying GitHub API for artifact..."
ARTIFACT_URL=$(curl -s \
  -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${REPO}/actions/artifacts?name=${ARTIFACT_NAME}" \
  | jq -r '.artifacts[0].archive_download_url')

if [ -z "$ARTIFACT_URL" ] || [ "$ARTIFACT_URL" = "null" ]; then
  echo "❌ Failed to find artifact: ${ARTIFACT_NAME}"
  echo "Available artifacts:"
  curl -s \
    -H "Authorization: token ${GITHUB_PAT}" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${REPO}/actions/artifacts" \
    | jq -r '.artifacts[] | .name'
  exit 1
fi

echo "Downloading from: ${ARTIFACT_URL}"

# Download and extract into Docker volume using a temporary container
TEMP_CONTAINER="changelog-fetch-$$"

# Run container in background to download and extract
docker run --rm \
  -v "${VOLUME_NAME}:${WORK_DIR}" \
  -e "GITHUB_PAT=${GITHUB_PAT}" \
  -e "ARTIFACT_URL=${ARTIFACT_URL}" \
  -e "VERSION=${VERSION}" \
  --name "${TEMP_CONTAINER}" \
  alpine:latest \
  sh -c '
    # Install dependencies
    apk add --no-cache curl unzip >/dev/null 2>&1

    cd /changelog

    # Download artifact
    curl -L \
      -H "Authorization: token ${GITHUB_PAT}" \
      -o artifact.zip \
      "${ARTIFACT_URL}"

    # Extract artifact (GitHub returns a zip containing the tar.gz)
    echo "Extracting artifact..."
    unzip -o -q artifact.zip
    rm artifact.zip

    # Extract the tar.gz changelog
    tar -xzf "bagel-store-changelog-${VERSION}.tar.gz"

    echo "✅ Changelog extracted successfully"
    ls -la
  '

echo ""
echo "✅ fetch-changelog-artifact.sh completed"
echo "   Changelog stored in Docker volume: ${VOLUME_NAME}"
