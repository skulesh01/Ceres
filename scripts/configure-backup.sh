#!/bin/bash
# CERES Backup Configuration Script
# Configures Velero for automated backups

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "💾 CERES Backup Configuration"
echo "============================="
echo ""

# Check if Velero is installed
echo "📦 Checking Velero installation..."
if ! kubectl get namespace velero &> /dev/null; then
    echo -e "${RED}❌ Velero namespace not found${NC}"
    echo "Run: kubectl apply -f deployment/velero.yaml"
    exit 1
fi

if ! kubectl get deployment velero -n velero &> /dev/null; then
    echo -e "${RED}❌ Velero deployment not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Velero is installed${NC}"

# Check if MinIO is running
echo "📦 Checking MinIO (backup storage)..."
if kubectl get pods -n minio -l app=minio | grep -q Running; then
    MINIO_IP=$(kubectl get svc minio -n minio -o jsonpath='{.spec.clusterIP}')
    echo -e "${GREEN}✅ MinIO is running at ${MINIO_IP}${NC}"
else
    echo -e "${YELLOW}⚠️  MinIO not running, using local storage${NC}"
    MINIO_IP=""
fi

echo ""

# Create backup storage location
if [ -n "$MINIO_IP" ]; then
    echo "🗄️  Configuring S3-compatible backup storage (MinIO)..."
    
    # Create credentials secret
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: velero-minio-credentials
  namespace: velero
type: Opaque
stringData:
  cloud: |
    [default]
    aws_access_key_id = minioadmin
    aws_secret_access_key = MinIO@Admin2025
EOF

    # Create backup storage location
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups
    prefix: ceres
  config:
    region: minio
    s3ForcePathStyle: "true"
    s3Url: http://${MINIO_IP}:9000
    publicUrl: http://minio.ceres.local
  credential:
    name: velero-minio-credentials
    key: cloud
EOF

    # Create MinIO bucket
    echo "Creating backup bucket in MinIO..."
    kubectl exec -n minio deployment/minio -- mc mb local/velero-backups 2>/dev/null || echo "Bucket may already exist"
    
    echo -e "${GREEN}✅ S3 backup storage configured${NC}"
else
    echo "🗄️  Configuring local backup storage..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups
  config:
    region: local
EOF
    
    echo -e "${GREEN}✅ Local backup storage configured${NC}"
fi

# Create backup schedule
echo ""
echo "⏰ Creating backup schedules..."

# Daily full backup at 2 AM
cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
    - ceres
    - gitlab
    - monitoring
    - mattermost
    - nextcloud
    - wiki
    - mailcow
    - portainer
    - minio
    - vault
    - redmine
    ttl: 720h0m0s  # 30 days
EOF

echo -e "${GREEN}✅ Daily backup schedule created (2:00 AM)${NC}"

# Weekly backup on Sunday at 3 AM
cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-backup
  namespace: velero
spec:
  schedule: "0 3 * * 0"
  template:
    includedNamespaces:
    - "*"
    includedResources:
    - "*"
    ttl: 2160h0m0s  # 90 days
EOF

echo -e "${GREEN}✅ Weekly full backup schedule created (Sunday 3:00 AM)${NC}"

# Create immediate backup for testing
echo ""
read -p "Create an immediate test backup? [y/N]: " CREATE_BACKUP
if [[ "$CREATE_BACKUP" =~ ^[Yy]$ ]]; then
    echo "Creating backup..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: ceres-initial-backup
  namespace: velero
spec:
  includedNamespaces:
  - ceres
  - gitlab
  - monitoring
  ttl: 720h0m0s
EOF

    echo "Waiting for backup to complete..."
    sleep 5
    
    for i in {1..30}; do
        BACKUP_STATUS=$(kubectl get backup ceres-initial-backup -n velero -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [ "$BACKUP_STATUS" == "Completed" ]; then
            echo -e "${GREEN}✅ Backup completed successfully${NC}"
            break
        elif [ "$BACKUP_STATUS" == "Failed" ]; then
            echo -e "${RED}❌ Backup failed${NC}"
            kubectl describe backup ceres-initial-backup -n velero | tail -20
            break
        fi
        echo -n "."
        sleep 2
    done
fi

# Summary
echo ""
echo "===================================="
echo -e "${GREEN}✅ Backup Configuration Complete!${NC}"
echo ""
echo "📝 Backup Schedules:"
echo "  - Daily: 2:00 AM (retention: 30 days)"
echo "  - Weekly: Sunday 3:00 AM (retention: 90 days)"
echo ""
echo "💡 Useful commands:"
echo "  List backups:"
echo "    kubectl get backups -n velero"
echo ""
echo "  Create manual backup:"
echo "    velero backup create my-backup --include-namespaces ceres"
echo ""
echo "  Restore from backup:"
echo "    velero restore create --from-backup BACKUP_NAME"
echo ""
echo "  View backup details:"
echo "    velero backup describe BACKUP_NAME"
echo ""
