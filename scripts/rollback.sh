#!/bin/bash
# CERES Rollback Script
# Safely rollback to previous version or specific backup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "↩️  CERES Rollback Utility"
echo "========================="
echo ""

# Check if Velero is installed
if ! kubectl get namespace velero &> /dev/null; then
    echo -e "${RED}❌ Velero not installed. Cannot perform rollback.${NC}"
    echo "Install Velero first: kubectl apply -f deployment/velero.yaml"
    exit 1
fi

# List available backups
echo "📋 Available backups:"
echo ""

BACKUPS=$(kubectl get backups -n velero -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.startTimestamp}{"\n"}{end}' 2>/dev/null)

if [ -z "$BACKUPS" ]; then
    echo -e "${YELLOW}⚠️  No backups found${NC}"
    echo ""
    echo "Create a backup first:"
    echo "  ./scripts/configure-backup.sh"
    exit 1
fi

echo "$BACKUPS" | nl
echo ""

# Ask user which backup to restore
read -p "Select backup number to restore (or 'q' to quit): " BACKUP_NUM

if [ "$BACKUP_NUM" == "q" ] || [ "$BACKUP_NUM" == "Q" ]; then
    echo "Rollback cancelled"
    exit 0
fi

BACKUP_NAME=$(echo "$BACKUPS" | sed -n "${BACKUP_NUM}p" | awk '{print $1}')

if [ -z "$BACKUP_NAME" ]; then
    echo -e "${RED}❌ Invalid backup number${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Selected backup: ${BACKUP_NAME}${NC}"
echo ""

# Warning
echo -e "${YELLOW}⚠️  WARNING: This will restore from backup and may overwrite current data!${NC}"
echo ""
read -p "Type 'yes' to confirm rollback: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Create restore
echo ""
echo "🔄 Creating restore from backup: ${BACKUP_NAME}..."

RESTORE_NAME="restore-$(date +%Y%m%d-%H%M%S)"

cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: ${RESTORE_NAME}
  namespace: velero
spec:
  backupName: ${BACKUP_NAME}
  includedNamespaces:
  - '*'
  restorePVs: true
EOF

echo "Restore created: ${RESTORE_NAME}"
echo ""
echo "⏳ Waiting for restore to complete..."

# Monitor restore progress
for i in {1..60}; do
    RESTORE_STATUS=$(kubectl get restore ${RESTORE_NAME} -n velero -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    
    case "$RESTORE_STATUS" in
        "Completed")
            echo -e "${GREEN}✅ Restore completed successfully${NC}"
            break
            ;;
        "Failed"|"PartiallyFailed")
            echo -e "${RED}❌ Restore failed${NC}"
            kubectl describe restore ${RESTORE_NAME} -n velero | tail -30
            exit 1
            ;;
        "InProgress")
            echo -n "."
            ;;
        *)
            echo -n "."
            ;;
    esac
    
    sleep 2
done

echo ""

# Restart deployments to pick up restored state
echo "🔄 Restarting deployments..."

NAMESPACES="ceres gitlab monitoring mattermost nextcloud wiki portainer minio vault redmine"

for NS in $NAMESPACES; do
    if kubectl get namespace "$NS" &> /dev/null; then
        echo "  Restarting pods in namespace: $NS"
        kubectl rollout restart deployment -n "$NS" 2>/dev/null || true
    fi
done

echo ""

# Summary
echo "===================================="
echo -e "${GREEN}✅ Rollback Complete!${NC}"
echo ""
echo "📝 Restore details:"
echo "  Backup: ${BACKUP_NAME}"
echo "  Restore: ${RESTORE_NAME}"
echo ""
echo "🔍 Check restore status:"
echo "  kubectl describe restore ${RESTORE_NAME} -n velero"
echo ""
echo "⏳ Wait for all pods to restart:"
echo "  kubectl get pods -A | grep -v Running"
echo ""
echo "🏥 Run health check:"
echo "  ./scripts/health-check.sh"
echo ""
