#!/bin/bash
# High Availability Setup Script for CERES
# Initializes Patroni PostgreSQL cluster, Redis Sentinel, and HAProxy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="${SCRIPT_DIR}/../config/compose"
CONFIG_DIR="${SCRIPT_DIR}/../config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."
  
  if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed"
    exit 1
  fi
  
  if ! command -v docker-compose &> /dev/null; then
    log_error "Docker Compose is not installed"
    exit 1
  fi
  
  log_success "Prerequisites check passed"
}

# Load environment variables
load_env() {
  log_info "Loading environment variables..."
  
  if [ ! -f ".env" ]; then
    log_error ".env file not found"
    echo "Please create .env with required variables:"
    echo "  POSTGRES_PASSWORD=your_password"
    echo "  REDIS_PASSWORD=your_password"
    echo "  REDIS_SENTINEL_PASSWORD=your_password"
    echo "  DOMAIN_NAME=your.domain.com"
    exit 1
  fi
  
  source .env
  log_success "Environment variables loaded"
}

# Create required directories
create_directories() {
  log_info "Creating required directories..."
  
  mkdir -p "${CONFIG_DIR}/patroni"
  mkdir -p "${CONFIG_DIR}/redis"
  mkdir -p "${CONFIG_DIR}/haproxy"
  
  log_success "Directories created"
}

# Generate SSL certificates for Patroni
generate_patroni_certs() {
  log_info "Generating Patroni SSL certificates..."
  
  CERT_DIR="/tmp/patroni-certs"
  mkdir -p "${CERT_DIR}"
  
  # Generate CA
  openssl genrsa -out "${CERT_DIR}/ca-key.pem" 2048
  openssl req -new -x509 -days 365 -key "${CERT_DIR}/ca-key.pem" \
    -out "${CERT_DIR}/ca.pem" -subj "/CN=ceres-ca"
  
  # Generate Patroni cert
  openssl genrsa -out "${CERT_DIR}/patroni-key.pem" 2048
  openssl req -new -key "${CERT_DIR}/patroni-key.pem" \
    -out "${CERT_DIR}/patroni.csr" -subj "/CN=patroni.ceres"
  
  openssl x509 -req -in "${CERT_DIR}/patroni.csr" \
    -CA "${CERT_DIR}/ca.pem" -CAkey "${CERT_DIR}/ca-key.pem" \
    -CAcreateserial -out "${CERT_DIR}/patroni.pem" -days 365
  
  log_success "Patroni certificates generated"
}

# Generate SSL certificates for PostgreSQL
generate_postgres_certs() {
  log_info "Generating PostgreSQL SSL certificates..."
  
  CERT_DIR="/tmp/postgres-certs"
  mkdir -p "${CERT_DIR}"
  
  openssl genrsa -out "${CERT_DIR}/postgres-key.pem" 2048
  openssl req -new -key "${CERT_DIR}/postgres-key.pem" \
    -out "${CERT_DIR}/postgres.csr" -subj "/CN=postgres.ceres"
  
  openssl x509 -req -in "${CERT_DIR}/postgres.csr" \
    -CA "/tmp/patroni-certs/ca.pem" \
    -CAkey "/tmp/patroni-certs/ca-key.pem" \
    -CAcreateserial -out "${CERT_DIR}/postgres.pem" -days 365
  
  log_success "PostgreSQL certificates generated"
}

# Start HA services
start_ha_services() {
  log_info "Starting High Availability services..."
  
  cd "${SCRIPT_DIR}/.."
  
  docker-compose -f "${COMPOSE_DIR}/ha.yml" up -d
  
  log_success "HA services started"
}

# Wait for cluster to be ready
wait_for_cluster() {
  log_info "Waiting for cluster to be ready..."
  
  local max_attempts=60
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if docker exec ceres-postgres-1 pg_isready -U postgres &> /dev/null; then
      log_success "PostgreSQL cluster is ready"
      return 0
    fi
    
    attempt=$((attempt + 1))
    sleep 5
  done
  
  log_error "Cluster failed to start within timeout"
  return 1
}

# Initialize PostgreSQL with replication
init_postgres_replication() {
  log_info "Initializing PostgreSQL replication..."
  
  # Create replication user
  docker exec ceres-postgres-1 psql -U postgres -c \
    "CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD '${POSTGRES_PASSWORD}';" \
    2>/dev/null || true
  
  # Grant replication privileges
  docker exec ceres-postgres-1 psql -U postgres -c \
    "GRANT ALL PRIVILEGES ON DATABASE postgres TO replicator;" \
    2>/dev/null || true
  
  log_success "PostgreSQL replication initialized"
}

# Check Redis cluster health
check_redis_health() {
  log_info "Checking Redis cluster health..."
  
  local max_attempts=30
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if docker exec ceres-redis-1 redis-cli -a "${REDIS_PASSWORD}" ping &> /dev/null; then
      log_success "Redis cluster is healthy"
      
      # Show cluster info
      echo ""
      log_info "Redis Cluster Status:"
      docker exec ceres-redis-1 redis-cli -a "${REDIS_PASSWORD}" info replication
      echo ""
      return 0
    fi
    
    attempt=$((attempt + 1))
    sleep 2
  done
  
  log_error "Redis cluster failed to become healthy"
  return 1
}

# Verify HAProxy configuration
verify_haproxy() {
  log_info "Verifying HAProxy configuration..."
  
  docker exec ceres-haproxy haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c
  
  log_success "HAProxy configuration is valid"
}

# Display cluster status
display_cluster_status() {
  log_info "Displaying cluster status..."
  
  echo ""
  echo -e "${BLUE}========== POSTGRESQL CLUSTER STATUS ==========${NC}"
  docker exec ceres-postgres-1 pg_isready -U postgres
  echo ""
  
  echo -e "${BLUE}========== REDIS CLUSTER STATUS ==========${NC}"
  docker exec ceres-redis-1 redis-cli -a "${REDIS_PASSWORD}" info server | grep redis_version
  docker exec ceres-redis-1 redis-cli -a "${REDIS_PASSWORD}" info replication
  echo ""
  
  echo -e "${BLUE}========== SENTINEL STATUS ==========${NC}"
  docker exec ceres-redis-sentinel-1 redis-cli -p 26379 -a "${REDIS_SENTINEL_PASSWORD}" \
    sentinel masters 2>/dev/null || echo "Sentinel info not available"
  echo ""
  
  echo -e "${BLUE}========== HAPROXY STATS ==========${NC}"
  echo "Web UI: http://localhost:8404/stats"
  echo ""
}

# Main execution
main() {
  echo -e "${GREEN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║          CERES HIGH AVAILABILITY SETUP SCRIPT              ║"
  echo "║     PostgreSQL Patroni + Redis Sentinel + HAProxy          ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  
  check_prerequisites
  load_env
  create_directories
  generate_patroni_certs
  generate_postgres_certs
  start_ha_services
  
  log_info "Waiting for services to initialize..."
  sleep 10
  
  wait_for_cluster
  init_postgres_replication
  check_redis_health
  verify_haproxy
  
  display_cluster_status
  
  echo -e "${GREEN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║          HIGH AVAILABILITY SETUP COMPLETED!                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo ""
  echo "Access Points:"
  echo "  • PostgreSQL HA: localhost:5432 (via HAProxy)"
  echo "  • Redis HA:      localhost:6379 (via HAProxy)"
  echo "  • HAProxy Stats: http://localhost:8404/stats"
  echo ""
  echo "PostgreSQL Cluster Nodes:"
  echo "  • postgres-1: localhost:5432"
  echo "  • postgres-2: localhost:5433"
  echo "  • postgres-3: localhost:5434"
  echo ""
  echo "Redis Cluster Nodes:"
  echo "  • redis-1: localhost:6379 (master)"
  echo "  • redis-2: localhost:6380 (replica)"
  echo "  • redis-3: localhost:6381 (replica)"
  echo ""
  echo "Redis Sentinel:"
  echo "  • sentinel-1: localhost:26379"
  echo "  • sentinel-2: localhost:26380"
  echo "  • sentinel-3: localhost:26381"
  echo ""
}

main "$@"
