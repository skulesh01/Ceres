#!/bin/bash
# CERES Services Setup & Integration Script
# Purpose: Auto-generate secrets, setup Keycloak clients, initialize services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

generate_secret() {
    openssl rand -base64 32 | tr -d '\n'
}

# Main execution
print_header "CERES Services Setup & Integration"

# 1. Check if .env exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found"
    echo "Creating .env from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success ".env created from template"
    else
        print_error ".env.example not found. Please create .env manually."
        exit 1
    fi
fi

# 2. Generate missing secrets
print_header "Generating OIDC Secrets"

if ! grep -q "GITLAB_OIDC_SECRET" .env || grep "GITLAB_OIDC_SECRET=CHANGE_ME" .env; then
    GITLAB_SECRET=$(generate_secret)
    sed -i "s/GITLAB_OIDC_SECRET=.*/GITLAB_OIDC_SECRET=$GITLAB_SECRET/" .env
    print_success "GitLab OIDC Secret: $GITLAB_SECRET"
fi

if ! grep -q "MM_OIDC_SECRET" .env || grep "MM_OIDC_SECRET=CHANGE_ME" .env; then
    MM_SECRET=$(generate_secret)
    sed -i "s/MM_OIDC_SECRET=.*/MM_OIDC_SECRET=$MM_SECRET/" .env
    print_success "Mattermost OIDC Secret: $MM_SECRET"
fi

if ! grep -q "REDMINE_OIDC_SECRET" .env || grep "REDMINE_OIDC_SECRET=CHANGE_ME" .env; then
    REDMINE_SECRET=$(generate_secret)
    sed -i "s/REDMINE_OIDC_SECRET=.*/REDMINE_OIDC_SECRET=$REDMINE_SECRET/" .env
    print_success "Redmine OIDC Secret: $REDMINE_SECRET"
fi

if ! grep -q "WIKIJS_OIDC_SECRET" .env || grep "WIKIJS_OIDC_SECRET=CHANGE_ME" .env; then
    WIKIJS_SECRET=$(generate_secret)
    sed -i "s/WIKIJS_OIDC_SECRET=.*/WIKIJS_OIDC_SECRET=$WIKIJS_SECRET/" .env
    print_success "Wiki.js OIDC Secret: $WIKIJS_SECRET"
fi

# 3. Create Docker network if not exists
print_header "Docker Network Setup"

if docker network inspect compose_internal &>/dev/null; then
    print_success "Network 'compose_internal' already exists"
else
    docker network create compose_internal --driver bridge
    print_success "Network 'compose_internal' created"
fi

# 4. Display service URLs
print_header "Service Access URLs"

DOMAIN=$(grep "^DOMAIN=" .env | cut -d'=' -f2)
echo -e "${YELLOW}Using Domain: ${NC}$DOMAIN"
echo ""

echo -e "${YELLOW}Initial Setup (Direct Ports):${NC}"
echo "  Keycloak       → http://localhost:8080"
echo "  GitLab         → http://localhost:8081"
echo "  Nextcloud      → http://localhost:8082"
echo "  Redmine        → http://localhost:8083"
echo "  Wiki.js        → http://localhost:8084"
echo "  Mattermost     → http://localhost:8085"
echo "  GitLab SSH     → ssh -p 2222 git@localhost"
echo ""

echo -e "${YELLOW}Production (Reverse Proxy):${NC}"
echo "  Keycloak       → https://auth.$DOMAIN"
echo "  GitLab         → https://gitlab.$DOMAIN"
echo "  Nextcloud      → https://nextcloud.$DOMAIN"
echo "  Redmine        → https://redmine.$DOMAIN"
echo "  Wiki.js        → https://wiki.$DOMAIN"
echo "  Mattermost     → https://chat.$DOMAIN"
echo ""

# 5. Check prerequisites
print_header "Checking Prerequisites"

CHECKS_PASSED=0
CHECKS_TOTAL=0

# Check Docker
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker installed: $DOCKER_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    print_error "Docker not installed"
fi

# Check Docker Compose
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if docker compose version &> /dev/null; then
    DC_VERSION=$(docker compose version)
    print_success "Docker Compose installed: $DC_VERSION"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    print_error "Docker Compose not installed"
fi

# Check PostgreSQL Volume
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if docker volume inspect compose_postgres_data &>/dev/null 2>&1; then
    print_warning "PostgreSQL volume already exists (will use existing data)"
else
    print_success "PostgreSQL volume will be created fresh"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
fi

echo ""
echo -e "Prerequisites check: ${CHECKS_PASSED}/${CHECKS_TOTAL} passed"
echo ""

# 6. Deployment confirmation
print_header "Ready to Deploy"

echo -e "${YELLOW}Configuration Summary:${NC}"
echo "  • Domain: $DOMAIN"
echo "  • Database: PostgreSQL + 6 dedicated databases"
echo "  • Cache: Redis with session store"
echo "  • Auth: Keycloak OIDC provider"
echo "  • Services: GitLab, Nextcloud, Mattermost, Redmine, Wiki.js"
echo ""

read -p "Deploy CERES services now? (yes/no) " -n 3 -r
echo
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    print_header "Starting Deployment"
    
    # Create compose command with all configs
    COMPOSE_CMD="docker-compose \
        --env-file .env \
        -f config/compose/base.yml \
        -f config/compose/core.yml \
        -f config/compose/apps.yml"
    
    echo "Running: $COMPOSE_CMD up -d"
    $COMPOSE_CMD up -d
    
    print_success "Deployment started!"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Wait 30-60 seconds for services to initialize"
    echo "  2. Check status: docker-compose ps"
    echo "  3. Access Keycloak: http://localhost:8080"
    echo "  4. Login with: admin / $KEYCLOAK_ADMIN_PASSWORD"
    echo "  5. Configure OIDC clients for each service"
    echo "  6. See SERVICES_INTEGRATION_GUIDE.md for detailed setup"
    echo ""
    
    # Show service startup status
    print_header "Service Startup Status"
    sleep 5
    $COMPOSE_CMD ps
else
    echo -e "${YELLOW}Deployment cancelled${NC}"
    echo ""
    echo "To deploy manually, run:"
    echo ""
    echo "  docker-compose --env-file .env \\"
    echo "    -f config/compose/base.yml \\"
    echo "    -f config/compose/core.yml \\"
    echo "    -f config/compose/apps.yml \\"
    echo "    up -d"
    echo ""
fi

print_header "Setup Complete!"
