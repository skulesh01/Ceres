#!/bin/bash
# Quick deployment script for CERES Platform
# Auto-detects environment and chooses best build method

set -e

echo "🚀 CERES Platform v3.0.0 - Quick Deploy"
echo "========================================"
echo ""

# Step 1: Wake up Proxmox server if configured
if [ -f "config/network.yaml" ]; then
    echo "🌐 Checking network configuration..."
    
    # Check if WOL is enabled
    if grep -q "enabled: true" config/network.yaml; then
        echo "📡 Wake-on-LAN enabled - waking up Proxmox server..."
        ./scripts/wol.sh config/network.yaml proxmox || echo "⚠️  WOL failed, continuing anyway..."
    fi
fi
echo ""

# Detect if Docker is available
if command -v docker &> /dev/null; then
    echo "✅ Docker found - using Docker build"
    echo "📦 Building CERES CLI with Docker (no Go installation needed)..."
    ./scripts/docker-build.sh
else
    echo "⚠️  Docker not found - using auto-install"
    echo "📥 Installing Go and building CERES CLI..."
    ./scripts/setup-go.sh
fi

echo ""
echo "✅ CERES CLI deployed successfully!"
echo ""
echo "🎯 Next steps:"
echo "  1. Validate: ./bin/ceres validate"
echo "  2. Configure: ./bin/ceres config show"
echo "  3. Deploy: ./bin/ceres deploy --dry-run"
echo ""
