#!/bin/bash
# k3s installation script for Ubuntu/Debian

set -e

echo "========================================="
echo "Installing k3s on Debian/Ubuntu"
echo "========================================="
echo ""

# 1. Update system
echo "[1/4] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq
echo "✓ Done"

# 2. Install k3s
echo "[2/4] Installing k3s (this may take 5-10 minutes)..."
export INSTALL_K3S_SKIP_DOWNLOAD=false
curl -sfL https://get.k3s.io | sh -
echo "✓ Done"

# 3. Wait for k3s to initialize
echo "[3/4] Waiting for k3s to initialize (60 seconds)..."
sleep 60

# 4. Verify installation
echo "[4/4] Verifying installation..."
k3s --version
kubectl get nodes || true

echo ""
echo "========================================="
echo "✓ k3s installation completed!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  kubectl get pods -a"
echo "  kubectl get svc"
echo ""
