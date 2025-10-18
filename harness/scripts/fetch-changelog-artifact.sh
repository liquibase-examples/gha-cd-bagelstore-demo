#!/bin/bash
# Fetch Changelog Artifact from GitHub Actions
#
# Downloads the changelog artifact from GitHub Actions artifact storage
# and extracts it to /tmp/changelog for use by Liquibase.
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
REPO="${GITHUB_ORG}/harness-gha-bagelstore"
ARTIFACT_NAME="changelog-${VERSION}"
WORK_DIR="/tmp/changelog"

# ===== Main Logic =====
echo "=== Fetching Changelog Artifact ==="
echo "Version: ${VERSION}"
echo "Repository: ${REPO}"
echo "Artifact: ${ARTIFACT_NAME}"

# Create working directory
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

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

# Download artifact (GitHub returns a zip containing the tar.gz)
curl -L \
  -H "Authorization: token ${GITHUB_PAT}" \
  -o artifact.zip \
  "${ARTIFACT_URL}"

# Unzip the artifact
echo "Extracting artifact..."
unzip -q artifact.zip
rm artifact.zip

# Extract the tar.gz changelog
tar -xzf "bagel-store-changelog-${VERSION}.tar.gz"

echo "✅ Changelog extracted successfully"
ls -la
