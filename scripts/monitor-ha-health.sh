#!/bin/bash
# Continuous Health Monitoring for CERES HA
# Monitors PostgreSQL, Redis, and Sentinel health

set -e

POSTGRES_NODES=("postgres-1" "postgres-2" "postgres-3")
REDIS_NODES=("redis-1" "redis-2" "redis-3")
SENTINEL_NODES=("redis-sentinel-1" "redis-sentinel-2" "redis-sentinel-3")
SENTINEL_PORTS=(26379 26380 26381)

# Load environment
if [ -f ".env" ]; then
  source .env
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Health check for PostgreSQL
check_postgres() {
  local node=$1
  
  if docker exec "$node" pg_isready -U postgres &> /dev/null; then
    echo -e "${GREEN}✓${NC} $node is healthy"
    
    # Get additional info
    local status=$(docker exec "$node" psql -U postgres -t -c "SELECT role FROM pg_roles WHERE rolname='postgres';" 2>/dev/null || echo "unknown")
    local role=$(docker exec "$node" psql -U postgres -t -c "SELECT pg_is_in_recovery()::text;" 2>/dev/null || echo "unknown")
    
    if [ "$role" = "f" ]; then
      echo -e "  Role: ${BLUE}PRIMARY${NC}"
    else
      echo -e "  Role: ${YELLOW}REPLICA${NC}"
    fi
  else
    echo -e "${RED}✗${NC} $node is DOWN"
    return 1
  fi
}

# Health check for Redis
check_redis() {
  local node=$1
  
  if docker exec "$node" redis-cli -a "${REDIS_PASSWORD}" ping &> /dev/null; then
    echo -e "${GREEN}✓${NC} $node is healthy"
    
    # Get replication role
    local role=$(docker exec "$node" redis-cli -a "${REDIS_PASSWORD}" info replication | grep role | cut -d: -f2 | tr -d '\r')
    
    if [ "$role" = "master" ]; then
      echo -e "  Role: ${BLUE}MASTER${NC}"
    else
      echo -e "  Role: ${YELLOW}REPLICA${NC}"
    fi
  else
    echo -e "${RED}✗${NC} $node is DOWN"
    return 1
  fi
}

# Health check for Sentinel
check_sentinel() {
  local node=$1
  local port=$2
  
  if docker exec "$node" redis-cli -p "$port" -a "${REDIS_SENTINEL_PASSWORD}" ping &> /dev/null; then
    echo -e "${GREEN}✓${NC} $node is healthy"
    
    # Get monitored master info
    docker exec "$node" redis-cli -p "$port" -a "${REDIS_SENTINEL_PASSWORD}" \
      sentinel masters 2>/dev/null | head -5 || echo "  (monitoring ceres-redis-cluster)"
  else
    echo -e "${RED}✗${NC} $node is DOWN"
    return 1
  fi
}

# Check HAProxy stats
check_haproxy() {
  if curl -s http://localhost:8404/stats &> /dev/null; then
    echo -e "${GREEN}✓${NC} HAProxy is healthy"
  else
    echo -e "${RED}✗${NC} HAProxy is DOWN"
    return 1
  fi
}

# Get cluster summary
get_cluster_summary() {
  echo ""
  echo -e "${BLUE}========== CLUSTER SUMMARY ==========${NC}"
  
  # PostgreSQL summary
  echo -e "${BLUE}PostgreSQL:${NC}"
  local pg_healthy=0
  for node in "${POSTGRES_NODES[@]}"; do
    if docker exec "$node" pg_isready -U postgres &> /dev/null; then
      ((pg_healthy++))
    fi
  done
  echo "  Status: $pg_healthy/${#POSTGRES_NODES[@]} nodes healthy"
  
  # Redis summary
  echo -e "${BLUE}Redis:${NC}"
  local redis_healthy=0
  for node in "${REDIS_NODES[@]}"; do
    if docker exec "$node" redis-cli -a "${REDIS_PASSWORD}" ping &> /dev/null; then
      ((redis_healthy++))
    fi
  done
  echo "  Status: $redis_healthy/${#REDIS_NODES[@]} nodes healthy"
  
  # Sentinel summary
  echo -e "${BLUE}Sentinel:${NC}"
  local sentinel_healthy=0
  for node in "${SENTINEL_NODES[@]}"; do
    port=${SENTINEL_PORTS[$((${#SENTINEL_NODES[@]} - 1))]}
    if docker exec "$node" redis-cli -p "$port" -a "${REDIS_SENTINEL_PASSWORD}" ping &> /dev/null; then
      ((sentinel_healthy++))
    fi
  done
  echo "  Status: $sentinel_healthy/${#SENTINEL_NODES[@]} nodes healthy"
  
  echo ""
}

# Main monitoring loop
main() {
  clear
  
  echo -e "${GREEN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║       CERES HIGH AVAILABILITY HEALTH MONITOR               ║"
  echo "║                  (Updated every 30 seconds)                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  
  while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}═══════════════ Check at $timestamp ═══════════════${NC}"
    echo ""
    
    # PostgreSQL checks
    echo -e "${BLUE}PostgreSQL Cluster:${NC}"
    for node in "${POSTGRES_NODES[@]}"; do
      check_postgres "$node"
    done
    echo ""
    
    # Redis checks
    echo -e "${BLUE}Redis Cluster:${NC}"
    for node in "${REDIS_NODES[@]}"; do
      check_redis "$node"
    done
    echo ""
    
    # Sentinel checks
    echo -e "${BLUE}Redis Sentinel:${NC}"
    for i in "${!SENTINEL_NODES[@]}"; do
      check_sentinel "${SENTINEL_NODES[$i]}" "${SENTINEL_PORTS[$i]}"
    done
    echo ""
    
    # HAProxy check
    echo -e "${BLUE}Load Balancer:${NC}"
    check_haproxy
    echo ""
    
    # Cluster summary
    get_cluster_summary
    
    echo -e "${YELLOW}Press Ctrl+C to exit. Refreshing in 30 seconds...${NC}"
    sleep 30
    clear
  done
}

# Trap interrupt signal
trap 'echo -e "\n${YELLOW}Health monitoring stopped${NC}"; exit 0' INT

main "$@"
