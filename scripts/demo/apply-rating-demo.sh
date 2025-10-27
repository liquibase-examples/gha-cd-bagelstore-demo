#!/usr/bin/env bash
#
# apply-rating-demo.sh - Apply product rating feature for pipeline demonstration
#
# Usage: ./scripts/demo/apply-rating-demo.sh
#
# What it does:
# 1. Verifies you're on main branch with clean working tree
# 2. Creates unique PR branch: demo/rating-feature-YYYYMMDD-HHMM
# 3. Switches to PR branch
# 4. Applies rating-feature.patch (uncommitted changes)
# 5. Shows next steps for commit/push
#
# This prepares changes for you to commit and push, triggering the pipeline
# deployment through dev → test → staging → prod environments.
#

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get repository root (2 levels up from scripts/demo/)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_FILE="${REPO_ROOT}/scripts/demo/rating-feature.patch"

# Generate unique branch name with timestamp
TIMESTAMP=$(date '+%Y%m%d-%H%M')
BRANCH_NAME="demo/rating-feature-${TIMESTAMP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Apply Product Rating Feature${NC}"
echo -e "${BLUE}  Pipeline Demo Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if patch file exists
if [[ ! -f "${PATCH_FILE}" ]]; then
    echo -e "${RED}❌ Error: Patch file not found${NC}"
    echo "  Expected: ${PATCH_FILE}"
    exit 1
fi

# Check if in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}→${NC} Checking current branch..."
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
    echo -e "${RED}❌ Error: Must be on main branch${NC}"
    echo "  Current branch: ${CURRENT_BRANCH}"
    echo "  Run: git checkout main"
    exit 1
fi
echo -e "${GREEN}✓${NC} On main branch"
echo ""

# Check if git working tree is clean
echo -e "${YELLOW}→${NC} Checking git working tree..."
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${RED}❌ Error: Git working tree is not clean${NC}"
    echo ""
    echo "You have uncommitted changes. Please commit or stash them first:"
    echo "  git status"
    echo ""
    echo "Or run verify script:"
    echo "  ./scripts/demo/verify-demo-state.sh"
    exit 1
fi
echo -e "${GREEN}✓${NC} Working tree is clean"
echo ""

# Create PR branch
echo -e "${YELLOW}→${NC} Creating PR branch: ${BRANCH_NAME}..."
if git rev-parse --verify "${BRANCH_NAME}" >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Branch already exists${NC}"
    echo "  Branch: ${BRANCH_NAME}"
    echo "  Delete it first: git branch -D ${BRANCH_NAME}"
    exit 1
fi

git checkout -b "${BRANCH_NAME}"
echo -e "${GREEN}✓${NC} Created and switched to ${BRANCH_NAME}"
echo ""

# Apply the patch
echo -e "${YELLOW}→${NC} Applying rating feature patch..."
echo "  Patch: ${PATCH_FILE}"
echo ""

if git apply "${PATCH_FILE}"; then
    echo -e "${GREEN}✓${NC} Patch applied successfully"
else
    echo -e "${RED}❌ Error: Failed to apply patch${NC}"
    echo ""
    echo "This might happen if:"
    echo "  • The patch has already been applied"
    echo "  • There are conflicts with current code"
    echo "  • Files have been modified"
    echo ""
    echo "To clean up and try again:"
    echo "  git checkout main"
    echo "  git branch -D ${BRANCH_NAME}"
    echo "  ./scripts/demo/apply-rating-demo.sh"
    exit 1
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Changes Applied (Uncommitted)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show what changed
echo -e "${CYAN}Branch:${NC} ${BRANCH_NAME}"
echo ""

echo -e "${CYAN}Modified files:${NC}"
git status --short
echo ""

echo -e "${CYAN}Change summary:${NC}"
git diff --stat
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Ready for Pipeline Demo!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${CYAN}What was added:${NC}"
echo "  • Database: rating column (1-5 stars) with rollback"
echo "  • Application: Star display (★★★★★) on product cards"
echo "  • Changeset: 008-add-product-ratings.sql"
echo ""

echo -e "${CYAN}Next steps (MANUAL):${NC}"
echo ""
echo -e "  ${YELLOW}1.${NC} Review changes:"
echo "     git diff"
echo ""
echo -e "  ${YELLOW}2.${NC} Commit changes:"
echo "     git commit -am \"Add product ratings feature\""
echo ""
echo -e "  ${YELLOW}3.${NC} Push PR branch to trigger pipeline:"
echo "     git push -u origin ${BRANCH_NAME}"
echo ""
echo -e "  ${YELLOW}4.${NC} Watch deployment progress:"
echo "     • GitHub Actions builds Docker image + creates changelog artifact"
echo "     • Harness deploys through: dev → test → staging → prod"
echo "     • Each stage: Liquibase update → App Runner deploy → health check"
echo ""
echo -e "  ${YELLOW}5.${NC} Verify in each environment:"
echo "     • Star ratings appear below product names"
echo "     • Check database: SELECT name, rating FROM products;"
echo ""
echo -e "  ${YELLOW}6.${NC} Reset demo when done:"
echo "     ./scripts/demo/rollback-rating-demo.sh"
echo ""

echo -e "${CYAN}Monitor pipeline:${NC}"
echo "  • GitHub Actions: gh run list"
echo "  • Harness: ./scripts/harness/get-pipeline-executions.sh"
echo ""

echo -e "${CYAN}Demo state:${NC}"
echo "  • Current branch: ${BRANCH_NAME}"
echo "  • Main branch: Unchanged (still clean)"
echo "  • Changes: Uncommitted on PR branch"
echo ""
