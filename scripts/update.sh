#!/bin/bash
# CERES Update Script
# Checks for and applies platform updates

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GITHUB_REPO="skulesh01/Ceres"
CURRENT_VERSION=$(cat VERSION 2>/dev/null || echo "unknown")

echo "🔄 CERES Update Utility"
echo "======================="
echo ""
echo "Current version: ${CURRENT_VERSION}"
echo ""

# Check for updates
echo "🔍 Checking for updates..."

LATEST_VERSION=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "")

if [ -z "$LATEST_VERSION" ]; then
    echo -e "${YELLOW}⚠️  Could not check for updates (no internet or API rate limit)${NC}"
    exit 0
fi

echo "Latest version: ${LATEST_VERSION}"
echo ""

if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
    echo -e "${GREEN}✅ You are running the latest version${NC}"
    exit 0
fi

echo -e "${BLUE}📦 New version available: ${LATEST_VERSION}${NC}"
echo ""

# Show changelog
echo "📋 Changes:"
curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep -A 20 '"body":' | sed 's/"body": "//;s/",$//' | head -20
echo ""

read -p "Update to ${LATEST_VERSION}? [y/N]: " UPDATE_CONFIRM

if [[ ! "$UPDATE_CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Update cancelled"
    exit 0
fi

# Create backup before update
echo ""
echo "💾 Creating backup before update..."

./scripts/configure-backup.sh -y 2>/dev/null || echo "Backup may have failed, continuing..."

# Pull latest code
echo ""
echo "📥 Downloading update..."

if [ -d ".git" ]; then
    git fetch --tags
    git checkout "${LATEST_VERSION}"
else
    echo "Downloading release archive..."
    curl -L "https://github.com/${GITHUB_REPO}/archive/refs/tags/${LATEST_VERSION}.tar.gz" -o "/tmp/ceres-${LATEST_VERSION}.tar.gz"
    tar -xzf "/tmp/ceres-${LATEST_VERSION}.tar.gz" -C /tmp
    cp -r "/tmp/Ceres-${LATEST_VERSION#v}/"* .
fi

# Apply updates
echo ""
echo "🔧 Applying updates..."

# Update deployments
for YAML in deployment/*.yaml; do
    echo "  Applying $(basename $YAML)..."
    kubectl apply -f "$YAML" 2>/dev/null || true
done

# Run migrations if they exist
if [ -f "scripts/migrate-${LATEST_VERSION}.sh" ]; then
    echo "Running migration script..."
    bash "scripts/migrate-${LATEST_VERSION}.sh"
fi

# Update version file
echo "${LATEST_VERSION}" > VERSION

echo ""
echo "===================================="
echo -e "${GREEN}✅ Update Complete!${NC}"
echo ""
echo "Updated: ${CURRENT_VERSION} → ${LATEST_VERSION}"
echo ""
echo "🏥 Running health check..."
./scripts/health-check.sh

echo ""
echo "📝 Review changelog: https://github.com/${GITHUB_REPO}/releases/tag/${LATEST_VERSION}"
echo ""
