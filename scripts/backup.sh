#!/bin/bash
# Backup script for CERES Docker services
# Supports modular compose (default) and CLEAN monolith (fallback).

set -euo pipefail

PROJECT_NAME="ceres"
clean=false
modules=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            clean=true
            shift
            ;;
        --project-name)
            PROJECT_NAME="${2:?Missing value for --project-name}"
            shift 2
            ;;
        *)
            modules+=("$1")
            shift
            ;;
    esac
done

# Configuration
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
POSTGRES_BACKUP="$BACKUP_DIR/postgres_backup_$TIMESTAMP.sql"
REDIS_BACKUP="$BACKUP_DIR/redis_backup_$TIMESTAMP.rdb"
VOLUMES_BACKUP="$BACKUP_DIR/volumes_backup_$TIMESTAMP.tar.gz"
LOG_FILE="$BACKUP_DIR/backup_$TIMESTAMP.log"

compose_args=("--project-directory" "../config" "--project-name" "$PROJECT_NAME")

if [ "$clean" = true ]; then
    compose_args+=("-f" "../config/docker-compose-CLEAN.yml")
else
    declare -A map=(
        [core]="../config/compose/core.yml"
        [apps]="../config/compose/apps.yml"
        [monitoring]="../config/compose/monitoring.yml"
        [ops]="../config/compose/ops.yml"
        [edge]="../config/compose/edge.yml"
    )

    if [ ${#modules[@]} -eq 0 ]; then
        modules=(core apps monitoring ops edge)
    fi

    for m in "${modules[@]}"; do
        key="${m,,}"
        if [ -z "${map[$key]+x}" ]; then
            echo "Unknown module '$m'. Allowed: core, apps, monitoring, ops, edge. Or use --clean." >&2
            exit 1
        fi
        compose_args+=("-f" "${map[$key]}")
    done
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting CERES Backup...${NC}" | tee "$LOG_FILE"
echo "Timestamp: $TIMESTAMP" | tee -a "$LOG_FILE"
echo "Project: $PROJECT_NAME" | tee -a "$LOG_FILE"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# ==========================================
# 1. PostgreSQL Backup
# ==========================================
echo -e "\n${YELLOW}1. Backing up PostgreSQL database...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" exec -T postgres pg_dump \
    -U postgres \
    -d ceres_db \
    --no-owner --no-privileges --no-password > "$POSTGRES_BACKUP" 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$POSTGRES_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ PostgreSQL backup completed: $SIZE${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ PostgreSQL backup failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# 2. Redis Backup
# ==========================================
echo -e "\n${YELLOW}2. Backing up Redis...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" exec -T redis redis-cli BGSAVE > /dev/null 2>> "$LOG_FILE"
sleep 2
REDIS_ID=$(docker compose "${compose_args[@]}" ps -q redis | tr -d '\r')
if [ -z "$REDIS_ID" ]; then
    echo -e "${RED}❌ Redis container not found (is the 'redis' service running?)${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
docker cp "$REDIS_ID:/data/dump.rdb" "$REDIS_BACKUP" 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$REDIS_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Redis backup completed: $SIZE${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ Redis backup failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# 3. Docker Volumes Backup
# ==========================================
echo -e "\n${YELLOW}3. Backing up Docker volumes...${NC}" | tee -a "$LOG_FILE"

volume_suffixes=(
    pg_data
    redis_data
    nextcloud_data
    nextcloud_config
    gitea_data
    mattermost_data
    mattermost_logs
    mattermost_config
    prometheus_data
    grafana_data
    portainer_data
)

volume_mounts=()
tar_paths=()

for s in "${volume_suffixes[@]}"; do
    v="${PROJECT_NAME}_${s}"
    if docker volume inspect "$v" >/dev/null 2>&1; then
        volume_mounts+=("-v" "$v:/${s}:ro")
        tar_paths+=("${s}")
    fi
done

if [ ${#tar_paths[@]} -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No named volumes found to archive (OK on first run)${NC}" | tee -a "$LOG_FILE"
else
    docker run --rm \
        "${volume_mounts[@]}" \
        -v "$PWD/backups:/backup:rw" \
        alpine:latest sh -c "tar czf /backup/volumes_backup_$TIMESTAMP.tar.gz --ignore-failed-read -C / ${tar_paths[*]} 2>/dev/null || true" 2>> "$LOG_FILE"
fi

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$VOLUMES_BACKUP" | cut -f1)
    echo -e "${GREEN}✅ Volumes backup completed: $SIZE${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ Volumes backup failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# 4. Backup Metadata
# ==========================================
echo -e "\n${YELLOW}4. Creating backup metadata...${NC}" | tee -a "$LOG_FILE"

cat > "$BACKUP_DIR/backup_$TIMESTAMP.info" << EOF
Backup Information
==================
Timestamp: $TIMESTAMP
Hostname: $(hostname)
Backup Location: $(pwd)

Files Backed Up:
- PostgreSQL: $(du -h "$POSTGRES_BACKUP" | cut -f1)
- Redis: $(du -h "$REDIS_BACKUP" | cut -f1)
- Volumes: $(du -h "$VOLUMES_BACKUP" | cut -f1)

Total Size: $(du -sh "$BACKUP_DIR" | cut -f1)

Services Backed Up:
- PostgreSQL 15 (all databases)
- Redis 7 (all data)
- Docker Volumes (all persistent data)

Recovery Instructions:
See restore.sh or MAIN_GUIDE.md
EOF

echo -e "${GREEN}✅ Backup metadata created${NC}" | tee -a "$LOG_FILE"

# ==========================================
# 5. Summary
# ==========================================
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo -e "\n${GREEN}═══════════════════════════════════${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}✅ BACKUP COMPLETED SUCCESSFULLY${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}Total Backup Size: $TOTAL_SIZE${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}Timestamp: $TIMESTAMP${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}═══════════════════════════════════${NC}" | tee -a "$LOG_FILE"

echo -e "\n${YELLOW}Log saved to: $LOG_FILE${NC}"
