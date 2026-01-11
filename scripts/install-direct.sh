#!/bin/bash
# CERES - Installation Script for Linux

echo "╔════════════════════════════════════════════════════════╗"
echo "║  CERES - Docker + k3s Installation                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "[1/3] Installing Docker..."
case $OS in
    ubuntu|debian)
        apt-get update -qq
        apt-get install -y curl wget gnupg lsb-release ca-certificates
        
        # Docker repo
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        systemctl start docker
        systemctl enable docker
        ;;
    rhel|centos|fedora)
        yum install -y curl wget gnupg lsb-release ca-certificates
        yum install -y docker
        systemctl start docker
        systemctl enable docker
        ;;
esac

echo "✓ Docker installed"
echo ""

echo "[2/3] Installing k3s..."
curl -sfL https://get.k3s.io | sh -
systemctl restart k3s || true

echo "✓ k3s installed"
echo ""

echo "[3/3] Verifying installation..."
docker --version
k3s --version
kubectl get nodes

echo ""
echo "✓ INSTALLATION COMPLETE"
echo ""
echo "kubeconfig location: /etc/rancher/k3s/k3s.yaml"
