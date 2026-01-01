#!/bin/bash
# Data Backup Script for Ceres Services
# Usage: bash backup-ceres-data.sh [backup-dir]
# Creates comprehensive backup of all persistent data

BACKUP_DIR="${1:-./_ceres-backups}"
NAMESPACE="ceres"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Starting Ceres data backup...${NC}"
echo "Backup directory: $BACKUP_DIR"
echo ""

# 1. PostgreSQL Backup
echo -e "${YELLOW}1. Backing up PostgreSQL...${NC}"
kubectl exec -it postgres-0 -n $NAMESPACE -- \
  pg_dump -U postgres --all-databases > \
  "$BACKUP_DIR/postgres-full-$TIMESTAMP.sql"
echo -e "${GREEN}   PostgreSQL backup complete${NC}"

# 2. Redis Backup
echo -e "${YELLOW}2. Backing up Redis...${NC}"
kubectl exec -it redis-0 -n $NAMESPACE -- redis-cli BGSAVE > /dev/null
sleep 2
kubectl cp $NAMESPACE/redis-0:/data/dump.rdb \
  "$BACKUP_DIR/redis-dump-$TIMESTAMP.rdb"
echo -e "${GREEN}   Redis backup complete${NC}"

# 3. Nextcloud Data
echo -e "${YELLOW}3. Backing up Nextcloud...${NC}"
kubectl exec -it nextcloud-0 -n $NAMESPACE -- \
  tar -czf /tmp/nextcloud-data-$TIMESTAMP.tar.gz /var/www/html/data
kubectl cp $NAMESPACE/nextcloud-0:/tmp/nextcloud-data-$TIMESTAMP.tar.gz \
  "$BACKUP_DIR/nextcloud-data-$TIMESTAMP.tar.gz"
echo -e "${GREEN}   Nextcloud backup complete${NC}"

# 4. Gitea Repositories
echo -e "${YELLOW}4. Backing up Gitea repositories...${NC}"
kubectl exec -it gitea-0 -n $NAMESPACE -- \
  tar -czf /tmp/gitea-repos-$TIMESTAMP.tar.gz /data
kubectl cp $NAMESPACE/gitea-0:/tmp/gitea-repos-$TIMESTAMP.tar.gz \
  "$BACKUP_DIR/gitea-repos-$TIMESTAMP.tar.gz"
echo -e "${GREEN}   Gitea backup complete${NC}"

# 5. Kubernetes manifests
echo -e "${YELLOW}5. Backing up K8s manifests...${NC}"
kubectl get all -n $NAMESPACE -o yaml > \
  "$BACKUP_DIR/k8s-manifests-$TIMESTAMP.yaml"
kubectl get pvc -n $NAMESPACE -o yaml > \
  "$BACKUP_DIR/k8s-pvc-$TIMESTAMP.yaml"
kubectl get configmap -n $NAMESPACE -o yaml > \
  "$BACKUP_DIR/k8s-configmap-$TIMESTAMP.yaml"
kubectl get secrets -n $NAMESPACE -o yaml > \
  "$BACKUP_DIR/k8s-secrets-$TIMESTAMP.yaml"
echo -e "${GREEN}   Kubernetes manifests backup complete${NC}"

# 6. Create summary
echo -e "${YELLOW}6. Creating backup summary...${NC}"
cat > "$BACKUP_DIR/backup-manifest-$TIMESTAMP.txt" << EOF
Ceres Data Backup
=================
Date: $(date)
Timestamp: $TIMESTAMP

Files included:
1. postgres-full-$TIMESTAMP.sql
   - Complete PostgreSQL database dump
   - All databases and schemas
   - Restore: psql -f file.sql

2. redis-dump-$TIMESTAMP.rdb
   - Redis RDB snapshot
   - All cached data
   - Restore: Copy to /data/dump.rdb and restart Redis

3. nextcloud-data-$TIMESTAMP.tar.gz
   - Nextcloud data directory
   - User files and configurations
   - Restore: tar -xz and copy to /var/www/html/data

4. gitea-repos-$TIMESTAMP.tar.gz
   - All Gitea repositories
   - Git configuration
   - Restore: tar -xz and copy to /data

5. k8s-manifests-$TIMESTAMP.yaml
   - All Kubernetes deployments, services, etc.
   - Use to redeploy services

6. k8s-pvc-$TIMESTAMP.yaml
   - Persistent Volume Claim definitions

7. k8s-configmap-$TIMESTAMP.yaml
   - Configuration maps

8. k8s-secrets-$TIMESTAMP.yaml
   - Kubernetes secrets

Total size: $(du -sh "$BACKUP_DIR" | cut -f1)

Restore procedure:
1. Ensure cluster is running
2. Restore databases: kubectl exec -i postgres-0 -n ceres -- psql -U postgres < postgres-full.sql
3. Restore Redis: kubectl cp redis-dump.rdb ceres/redis-0:/data/dump.rdb && kubectl delete pod redis-0
4. Restore Nextcloud: kubectl cp nextcloud-data.tar.gz ceres/nextcloud-0:/tmp/ && kubectl exec -it nextcloud-0 -n ceres -- tar -xz -C /
5. Restore Gitea: kubectl cp gitea-repos.tar.gz ceres/gitea-0:/tmp/ && kubectl exec -it gitea-0 -n ceres -- tar -xz -C /

Backup valid until: $(date -d "+90 days" 2>/dev/null || echo "90 days from creation")
EOF

echo -e "${GREEN}   Backup manifest created${NC}"

# Final summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Backup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
ls -lh "$BACKUP_DIR/"
echo ""
echo "Total backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "Recommendation: Copy to external storage"
echo "  scp -r $BACKUP_DIR/ backup-server:/backups/"
echo ""
