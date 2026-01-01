#!/bin/bash

# CERES Installation Guide
# Full automated setup for Proxmox/k3s deployment

set -euo pipefail

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║           CERES - Automated Installation & Setup                 ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo "Error: Cannot detect OS"
    exit 1
fi

echo "[1/5] Updating system packages..."
case "$OS" in
    ubuntu|debian)
        sudo apt-get update -qq
        sudo apt-get install -y -qq git curl wget ca-certificates
        ;;
    rhel|centos|fedora)
        sudo yum install -y -q git curl wget ca-certificates
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "[2/5] Installing Docker..."
if ! command -v docker &>/dev/null; then
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo bash /tmp/get-docker.sh
    sudo usermod -aG docker $USER || true
    echo "Docker installed. You may need to log out and back in."
else
    echo "Docker already installed"
fi

echo "[3/5] Installing k3s (lightweight Kubernetes)..."
if ! command -v k3s &>/dev/null; then
    curl -sfL https://get.k3s.io | sh -
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $USER ~/.kube/config
    echo "k3s installed"
else
    echo "k3s already installed"
fi

echo "[4/5] Installing kubectl..."
if ! command -v kubectl &>/dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "kubectl installed"
else
    echo "kubectl already installed"
fi

echo "[5/5] Validating installation..."
echo ""
echo "Checking versions:"
docker --version
k3s --version
kubectl version --client

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Clone CERES repo: git clone <repo> /srv/ceres"
echo "  2. cd /srv/ceres && ./scripts/bootstrap.sh"
echo "  3. Configure environment: cp .env.example .env && nano .env"
echo "  4. Deploy: ./scripts/deploy.sh all"
echo ""
