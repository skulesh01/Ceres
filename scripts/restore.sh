#!/bin/bash
# Restore script for CERES Docker services
# Supports modular compose (default) and CLEAN monolith (fallback).

set -euo pipefail

# Configuration
BACKUP_DIR="./backups"
RESTORE_TIMESTAMP="${1:?Error: Please specify backup timestamp (YYYYMMDD_HHMMSS)}"

shift || true

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

POSTGRES_BACKUP="$BACKUP_DIR/postgres_backup_$RESTORE_TIMESTAMP.sql"
REDIS_BACKUP="$BACKUP_DIR/redis_backup_$RESTORE_TIMESTAMP.rdb"
VOLUMES_BACKUP="$BACKUP_DIR/volumes_backup_$RESTORE_TIMESTAMP.tar.gz"
LOG_FILE="$BACKUP_DIR/restore_$RESTORE_TIMESTAMP.log"

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

echo -e "${YELLOW}Starting CERES Restore...${NC}" | tee "$LOG_FILE"
echo "Restore Timestamp: $RESTORE_TIMESTAMP" | tee -a "$LOG_FILE"
echo "Project: $PROJECT_NAME" | tee -a "$LOG_FILE"

# Verify backup files exist
echo -e "\n${YELLOW}Verifying backup files...${NC}" | tee -a "$LOG_FILE"
for file in "$POSTGRES_BACKUP" "$REDIS_BACKUP" "$VOLUMES_BACKUP"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Missing backup file: $file${NC}" | tee -a "$LOG_FILE"
        exit 1
    fi
    SIZE=$(du -h "$file" | cut -f1)
    echo -e "${GREEN}✅ Found: $file ($SIZE)${NC}" | tee -a "$LOG_FILE"
done

# Confirm restore
echo -e "\n${YELLOW}WARNING: This will overwrite all data!${NC}" | tee -a "$LOG_FILE"
read -p "Continue with restore? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled" | tee -a "$LOG_FILE"
    exit 0
fi

# Stop services
echo -e "\n${YELLOW}1. Stopping services...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" down --remove-orphans 2>> "$LOG_FILE"
echo -e "${GREEN}✅ Services stopped${NC}" | tee -a "$LOG_FILE"

# Remove old volumes
echo -e "\n${YELLOW}2. Removing old volumes...${NC}" | tee -a "$LOG_FILE"
docker volume rm "${PROJECT_NAME}_pg_data" 2>> "$LOG_FILE" || true
echo -e "${GREEN}✅ Old volumes removed${NC}" | tee -a "$LOG_FILE"

# Start only database services
echo -e "\n${YELLOW}3. Starting database services...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" up -d postgres redis 2>> "$LOG_FILE"
sleep 5
echo -e "${GREEN}✅ Database services started${NC}" | tee -a "$LOG_FILE"

# ==========================================
# Restore PostgreSQL
# ==========================================
echo -e "\n${YELLOW}4. Restoring PostgreSQL database...${NC}" | tee -a "$LOG_FILE"
cat "$POSTGRES_BACKUP" | docker compose "${compose_args[@]}" exec -T postgres psql \
    -U postgres \
    -d ceres_db \
    --no-password 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PostgreSQL restore completed${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ PostgreSQL restore failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# Restore Redis
# ==========================================
echo -e "\n${YELLOW}5. Restoring Redis data...${NC}" | tee -a "$LOG_FILE"
REDIS_ID=$(docker compose "${compose_args[@]}" ps -q redis | tr -d '\r')
if [ -z "$REDIS_ID" ]; then
    echo -e "${RED}❌ Redis container not found (is the 'redis' service running?)${NC}" | tee -a "$LOG_FILE"
    exit 1
fi
docker cp "$REDIS_BACKUP" "$REDIS_ID:/data/dump.rdb" 2>> "$LOG_FILE"
docker compose "${compose_args[@]}" restart redis 2>> "$LOG_FILE"
sleep 2

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Redis restore completed${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ Redis restore failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# Restore Volumes
# ==========================================
echo -e "\n${YELLOW}6. Restoring volumes...${NC}" | tee -a "$LOG_FILE"

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
for s in "${volume_suffixes[@]}"; do
    v="${PROJECT_NAME}_${s}"
    volume_mounts+=("-v" "$v:/${s}")
done

docker run --rm \
    "${volume_mounts[@]}" \
    -v "$PWD/backups:/backup:ro" \
    alpine:latest tar xzf "/backup/volumes_backup_$RESTORE_TIMESTAMP.tar.gz" -C / 2>> "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Volumes restore completed${NC}" | tee -a "$LOG_FILE"
else
    echo -e "${RED}❌ Volumes restore failed${NC}" | tee -a "$LOG_FILE"
    exit 1
fi

# ==========================================
# Start all services
# ==========================================
echo -e "\n${YELLOW}7. Starting all services...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" up -d 2>> "$LOG_FILE"
sleep 5

echo -e "\n${GREEN}═══════════════════════════════════${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}✅ RESTORE COMPLETED SUCCESSFULLY${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}═══════════════════════════════════${NC}" | tee -a "$LOG_FILE"

echo -e "\n${YELLOW}All services are starting up...${NC}" | tee -a "$LOG_FILE"
docker compose "${compose_args[@]}" ps | tee -a "$LOG_FILE"

echo -e "\n${YELLOW}Log saved to: $LOG_FILE${NC}"
