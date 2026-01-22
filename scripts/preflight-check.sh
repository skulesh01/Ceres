#!/bin/bash
# CERES Pre-flight Check Script
# Validates system requirements before deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔍 CERES Pre-flight System Check"
echo "================================="
echo ""

FAILED=0

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then 
    echo -e "${YELLOW}⚠️  Not running as root. Some checks may require sudo.${NC}"
fi

# 1. Check RAM
echo "📊 Checking RAM..."
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ]; then
    echo -e "${RED}❌ Insufficient RAM: ${TOTAL_RAM}GB (minimum 16GB required)${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✅ RAM: ${TOTAL_RAM}GB${NC}"
fi

# 2. Check CPU cores
echo "💻 Checking CPU..."
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 4 ]; then
    echo -e "${RED}❌ Insufficient CPU cores: ${CPU_CORES} (minimum 4 required)${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✅ CPU cores: ${CPU_CORES}${NC}"
fi

# 3. Check disk space
echo "💾 Checking disk space..."
FREE_DISK=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$FREE_DISK" -lt 100 ]; then
    echo -e "${YELLOW}⚠️  Low disk space: ${FREE_DISK}GB free (recommended 100GB+)${NC}"
else
    echo -e "${GREEN}✅ Disk space: ${FREE_DISK}GB free${NC}"
fi

# 4. Check kubectl
echo "🔧 Checking kubectl..."
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | cut -d'"' -f4 || echo "unknown")
    echo -e "${GREEN}✅ kubectl installed: ${KUBECTL_VERSION}${NC}"
else
    echo -e "${RED}❌ kubectl not found${NC}"
    FAILED=$((FAILED + 1))
fi

# 5. Check Kubernetes cluster
echo "☸️  Checking Kubernetes cluster..."
if kubectl cluster-info &> /dev/null; then
    K8S_VERSION=$(kubectl version -o json 2>/dev/null | grep -o '"gitVersion":"[^"]*' | tail -1 | cut -d'"' -f4 || echo "unknown")
    echo -e "${GREEN}✅ Kubernetes cluster accessible: ${K8S_VERSION}${NC}"
    
    # Check if K3s
    if kubectl version 2>&1 | grep -q "k3s"; then
        echo -e "${GREEN}✅ K3s detected${NC}"
    fi
else
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    FAILED=$((FAILED + 1))
fi

# 6. Check Helm (optional)
echo "📦 Checking Helm..."
if command -v helm &> /dev/null; then
    HELM_VERSION=$(helm version --short 2>/dev/null | cut -d'+' -f1 || echo "unknown")
    echo -e "${GREEN}✅ Helm installed: ${HELM_VERSION}${NC}"
else
    echo -e "${YELLOW}⚠️  Helm not found (optional, but recommended)${NC}"
fi

# 7. Check network connectivity
echo "🌐 Checking network..."
if ping -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${GREEN}✅ Internet connectivity${NC}"
else
    echo -e "${YELLOW}⚠️  No internet connection (offline mode)${NC}"
fi

# 8. Check required ports
echo "🔌 Checking ports..."
PORTS_TO_CHECK=(80 443 6443)
for PORT in "${PORTS_TO_CHECK[@]}"; do
    if ss -tuln 2>/dev/null | grep -q ":$PORT " || netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        echo -e "${YELLOW}⚠️  Port $PORT is already in use${NC}"
    else
        echo -e "${GREEN}✅ Port $PORT available${NC}"
    fi
done

# 9. Check Docker (if not K3s)
echo "🐳 Checking container runtime..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo -e "${GREEN}✅ Docker installed: ${DOCKER_VERSION}${NC}"
elif command -v containerd &> /dev/null; then
    echo -e "${GREEN}✅ containerd installed${NC}"
elif command -v crio &> /dev/null; then
    echo -e "${GREEN}✅ CRI-O installed${NC}"
else
    echo -e "${YELLOW}⚠️  No container runtime detected${NC}"
fi

# 10. Check namespaces
echo "📂 Checking existing deployments..."
if kubectl get ns ceres &> /dev/null; then
    POD_COUNT=$(kubectl get pods -n ceres --no-headers 2>/dev/null | wc -l)
    echo -e "${YELLOW}⚠️  CERES namespace exists (${POD_COUNT} pods running)${NC}"
    echo "   This deployment will update existing resources"
else
    echo -e "${GREEN}✅ Clean installation${NC}"
fi

# Summary
echo ""
echo "================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All critical checks passed!${NC}"
    echo "Ready to deploy CERES Platform."
    exit 0
else
    echo -e "${RED}❌ ${FAILED} critical check(s) failed${NC}"
    echo "Please fix the issues above before deploying."
    exit 1
fi
