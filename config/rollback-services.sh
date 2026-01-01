#!/bin/bash
# Rollback Ceres Services Only
# Usage: bash rollback-services.sh
# This keeps the Kubernetes cluster intact, only removes Ceres services

NAMESPACE="ceres"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}CERES SERVICES ROLLBACK${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "This will delete all Ceres services but keep cluster intact."
echo "K8s cluster will remain operational and can be redeployed."
echo ""
read -p "Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo -e "${YELLOW}Starting service rollback...${NC}"

# Backup manifests
echo "Backing up current services..."
mkdir -p ./rollback-backups
kubectl get all -n $NAMESPACE -o yaml > ./rollback-backups/services-backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true

# Delete Ceres namespace (easier than deleting individual resources)
echo "Deleting Ceres namespace..."
kubectl delete namespace $NAMESPACE 2>/dev/null || true

# Wait for namespace to be deleted
echo "Waiting for namespace deletion..."
sleep 10

# Verify deletion
echo ""
echo -e "${GREEN}Rollback Complete!${NC}"
echo ""
echo "Verifying deletion..."
if kubectl get namespace $NAMESPACE 2>/dev/null; then
    echo -e "${RED}WARNING: Namespace still exists${NC}"
else
    echo -e "${GREEN}Namespace successfully deleted${NC}"
fi

echo ""
echo "Current cluster status:"
kubectl get nodes
echo ""
echo "To redeploy services:"
echo "1. Create namespace: kubectl create namespace ceres"
echo "2. Apply manifests: kubectl apply -f ceres-k8s-manifests.yaml"
echo ""
