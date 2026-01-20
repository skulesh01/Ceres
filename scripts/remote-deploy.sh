#!/bin/bash
# CERES Remote Deployment Script
# Purpose: Deploy CERES to remote server via SSH with automated setup

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <HOST> <USER> [OPTIONS]"
    echo ""
    echo "Example:"
    echo "  $0 192.168.1.3 root"
    echo "  $0 192.168.1.3 root --backup"
    echo ""
    exit 1
fi

SSH_HOST=$1
SSH_USER=$2
BACKUP_FLAG=${3:-}

print_header "CERES Remote Deployment to $SSH_USER@$SSH_HOST"

# 1. Test SSH connectivity
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ssh -o ConnectTimeout=5 "$SSH_USER@$SSH_HOST" "echo 'Connected'" &>/dev/null; then
    print_success "SSH connection successful"
else
    print_error "Cannot connect to $SSH_USER@$SSH_HOST"
    echo "Please check:"
    echo "  1. SSH service is running on target"
    echo "  2. SSH keys are configured (or use password)"
    echo "  3. Firewall allows SSH (port 22)"
    exit 1
fi

# 2. Check prerequisites on remote
echo -e "${YELLOW}Checking remote prerequisites...${NC}"
ssh "$SSH_USER@$SSH_HOST" bash <<'REMOTE_CHECK'
set -e

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "✗ Docker not installed on remote server"
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    echo "✗ Docker Compose not installed on remote server"
    exit 1
fi

# Check Git
if ! command -v git &> /dev/null; then
    echo "✗ Git not installed on remote server"
    exit 1
fi

echo "✓ All prerequisites found"
REMOTE_CHECK

print_success "Remote prerequisites OK"

# 3. Prepare local repository
print_header "Preparing Deployment Files"

# Get current git branch and commit
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse --short HEAD)

echo "  Branch: $CURRENT_BRANCH"
echo "  Commit: $CURRENT_COMMIT"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    print_warning "You have uncommitted changes"
    read -p "Continue anyway? (yes/no) " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Deployment cancelled"
        exit 1
    fi
fi

# 4. Sync files to remote
print_header "Syncing Files to Remote"

# Check if /opt/Ceres exists on remote
if ssh "$SSH_USER@$SSH_HOST" "[ -d /opt/Ceres ]"; then
    print_warning "CERES directory already exists on remote"
    
    # Backup if requested
    if [[ "$BACKUP_FLAG" == "--backup" ]]; then
        echo "Creating backup..."
        ssh "$SSH_USER@$SSH_HOST" bash <<'REMOTE_BACKUP'
            cd /opt/Ceres
            if [ -f scripts/backup.sh ]; then
                bash scripts/backup.sh --name pre-deploy-$(date +%Y%m%d-%H%M%S)
            fi
REMOTE_BACKUP
        print_success "Backup created"
    fi
    
    # Git pull on remote
    echo "Pulling latest changes on remote..."
    ssh "$SSH_USER@$SSH_HOST" bash <<REMOTE_PULL
        cd /opt/Ceres
        git fetch origin
        git checkout $CURRENT_BRANCH
        git pull origin $CURRENT_BRANCH
REMOTE_PULL
    print_success "Repository updated on remote"
else
    # Clone repository to remote
    echo "Cloning repository to remote..."
    
    # Get remote URL
    GIT_REMOTE=$(git config --get remote.origin.url)
    
    ssh "$SSH_USER@$SSH_HOST" bash <<REMOTE_CLONE
        mkdir -p /opt
        cd /opt
        if [[ "$GIT_REMOTE" =~ ^https:// ]] || [[ "$GIT_REMOTE" =~ ^git@ ]]; then
            git clone $GIT_REMOTE Ceres
        else
            echo "Cannot clone remote repository. Please set up Git repo first."
            exit 1
        fi
        cd Ceres
        git checkout $CURRENT_BRANCH
REMOTE_CLONE
    print_success "Repository cloned to /opt/Ceres"
fi

# 5. Run deployment on remote
print_header "Running Deployment on Remote Server"

ssh "$SSH_USER@$SSH_HOST" bash <<'REMOTE_DEPLOY'
set -e

cd /opt/Ceres

echo "Running setup-services.sh..."

# Make setup script executable
chmod +x setup-services.sh

# Run with auto-yes
bash setup-services.sh <<< "yes"

echo ""
echo "Waiting for services to stabilize (30 seconds)..."
sleep 30

echo ""
echo "Service Status:"
docker compose --project-name ceres ps

REMOTE_DEPLOY

print_success "Deployment completed on remote server"

# 6. Verify deployment
print_header "Verifying Deployment"

echo "Checking service health..."
ssh "$SSH_USER@$SSH_HOST" bash <<'REMOTE_VERIFY'
cd /opt/Ceres

# Check PostgreSQL
if docker compose exec -T postgres pg_isready -U postgres &>/dev/null; then
    echo "✓ PostgreSQL is ready"
else
    echo "✗ PostgreSQL is not ready"
fi

# Check Redis
if docker compose exec -T redis redis-cli ping &>/dev/null; then
    echo "✓ Redis is responding"
else
    echo "✗ Redis is not responding"
fi

# Count healthy services
HEALTHY=$(docker compose ps --format json | grep -c "healthy" || true)
RUNNING=$(docker compose ps --format json | wc -l || true)

echo ""
echo "Services: $HEALTHY healthy / $RUNNING total"

REMOTE_VERIFY

# 7. Display access URLs
print_header "Deployment Complete!"

echo -e "${GREEN}CERES is now deployed on $SSH_HOST${NC}"
echo ""
echo -e "${YELLOW}Service URLs:${NC}"
echo "  Keycloak       → http://$SSH_HOST:8080"
echo "  GitLab         → http://$SSH_HOST:8081"
echo "  Nextcloud      → http://$SSH_HOST:8082"
echo "  Redmine        → http://$SSH_HOST:8083"
echo "  Wiki.js        → http://$SSH_HOST:8084"
echo "  Mattermost     → http://$SSH_HOST:8085"
echo "  GitLab SSH     → ssh -p 2222 git@$SSH_HOST"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Access Keycloak: http://$SSH_HOST:8080"
echo "  2. Login with credentials from .env file"
echo "  3. Configure OIDC clients for each service"
echo "  4. See SERVICES_INTEGRATION_GUIDE.md for details"
echo ""
echo "To check status: ssh $SSH_USER@$SSH_HOST 'cd /opt/Ceres && docker compose ps'"
echo "To view logs:    ssh $SSH_USER@$SSH_HOST 'cd /opt/Ceres && docker compose logs -f'"
echo ""

print_header "All Done! 🚀"
