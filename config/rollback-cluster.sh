#!/bin/bash
# Rollback Kubernetes Cluster to Clean State
# Usage: bash rollback-cluster.sh
# WARNING: This is DESTRUCTIVE - use only after failed deployment

set -e

NAMESPACE="ceres"
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${RED}KUBERNETES CLUSTER ROLLBACK${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "${RED}WARNING: This will:${NC}"
echo "1. Delete all pods and services"
echo "2. Delete all deployments"
echo "3. Reset Kubernetes on all nodes"
echo "4. Delete all Docker containers"
echo ""
echo "This process is IRREVERSIBLE for running data."
echo ""
read -p "Type 'YES' to continue: " confirm
if [ "$confirm" != "YES" ]; then
    echo "Rollback cancelled."
    exit 0
fi

echo -e "${YELLOW}Starting rollback...${NC}"

# Backup manifests first (just in case)
echo "Backing up current cluster state..."
mkdir -p ./rollback-backups
kubectl get all -n $NAMESPACE -o yaml > ./rollback-backups/backup-$(date +%Y%m%d-%H%M%S).yaml 2>/dev/null || true

# Delete all services
echo "Deleting services..."
kubectl delete service --all -n $NAMESPACE 2>/dev/null || true

# Delete all deployments
echo "Deleting deployments..."
kubectl delete deployment --all -n $NAMESPACE 2>/dev/null || true

# Delete all statefulsets
echo "Deleting statefulsets..."
kubectl delete statefulset --all -n $NAMESPACE 2>/dev/null || true

# Wait for pods to terminate
echo "Waiting for pods to terminate..."
sleep 20

# Drain nodes
for node in k8s-master-1 k8s-worker-1 k8s-worker-2; do
    echo "Draining node: $node"
    kubectl drain $node --ignore-daemonsets --delete-emptydir-data 2>/dev/null || true
done

# Reset Kubernetes on each node
echo -e "${YELLOW}Resetting Kubernetes...${NC}"

# Master node
echo "Resetting master (k8s-master-1)..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.1.10 << 'MASTER_EOF'
sudo kubeadm reset -f 2>/dev/null || true
sudo docker system prune -af --volumes 2>/dev/null || true
echo "Master reset complete"
MASTER_EOF

# Worker nodes
for worker_ip in 192.168.1.11 192.168.1.12; do
    worker_name="k8s-worker-${worker_ip: -1}"
    echo "Resetting worker ($worker_name)..."
    ssh -o StrictHostKeyChecking=no ubuntu@$worker_ip << WORKER_EOF
sudo kubeadm reset -f 2>/dev/null || true
sudo docker system prune -af --volumes 2>/dev/null || true
echo "Worker reset complete"
WORKER_EOF
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Rollback Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Cluster is now in clean state."
echo ""
echo "Next steps:"
echo "1. Reinitialize Kubernetes cluster"
echo "2. Join worker nodes"
echo "3. Deploy services again"
echo ""
echo "To restart: bash k8s-proxmox-deploy.sh"
echo ""
