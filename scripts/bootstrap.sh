#!/usr/bin/env bash
set -euo pipefail

echo "================================"
echo "CERES Bootstrap & Initialization"
echo "================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# 1. Check dependencies
log_info "Checking dependencies..."
source "$SCRIPT_DIR/check-dependencies.sh" || {
  log_error "Dependency check failed"
  exit 1
}

# 2. Initialize environment
log_info "Initializing environment..."
source "$SCRIPT_DIR/init-environment.sh" || {
  log_error "Environment initialization failed"
  exit 1
}

# 3. Validate k8s/docker setup
log_info "Validating k8s/docker setup..."
if command -v kubectl &>/dev/null; then
  kubectl cluster-info >/dev/null 2>&1 || log_warn "kubectl available but cluster not accessible"
else
  log_warn "kubectl not found, skipping cluster validation"
fi

if command -v docker &>/dev/null; then
  docker ps >/dev/null 2>&1 || log_warn "docker not accessible (may need sudo)"
else
  log_warn "docker not found"
fi

# 4. Validate project structure
log_info "Validating project structure..."
if [[ -d "$PROJECT_ROOT/config" && -d "$PROJECT_ROOT/scripts" && -f "$PROJECT_ROOT/README.md" ]]; then
  log_info "Project structure OK"
else
  log_error "Project structure incomplete"
  exit 1
fi

echo ""
log_info "Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. Set environment variables: export REMOTE_HOST=... REMOTE_USER=... SSH_KEY_PATH=..."
echo "  2. Configure secrets: GH_REPO=owner/repo ./scripts/gh-ops/gh-actions.sh secret ..."
echo "  3. Deploy: ./scripts/deploy-ops/deploy-k8s.sh /srv/ceres/k8s"
echo ""
