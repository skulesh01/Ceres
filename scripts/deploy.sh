#!/usr/bin/env bash
set -euo pipefail

# Full deployment orchestrator
# Usage: ./deploy.sh [check|init|build|deploy|smoke|all]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOY_OPS="$SCRIPT_DIR/deploy-ops"

ACTION="${1:-all}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}▶${NC} $*"; }
log_step() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${BLUE}$*${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
log_error() { echo -e "${RED}✗ $*${NC}"; }

case "$ACTION" in
  check)
    log_step "Checking Dependencies"
    bash "$SCRIPT_DIR/check-dependencies.sh"
    ;;
  init)
    log_step "Initializing Environment"
    bash "$SCRIPT_DIR/init-environment.sh"
    ;;
  bootstrap)
    log_step "Full Bootstrap"
    bash "$SCRIPT_DIR/bootstrap.sh"
    ;;
  build)
    log_step "Building/Validating Manifests"
    if [[ -d "$PROJECT_ROOT/config/k8s" ]]; then
      kubectl kustomize "$PROJECT_ROOT/config/k8s" >/dev/null 2>&1 && log_info "Manifests valid" || log_error "Invalid manifests"
    else
      log_info "No k8s manifests found (expected at config/k8s)"
    fi
    ;;
  deploy)
    log_step "Deploying to Kubernetes"
    if [[ -z "${K8S_MANIFEST_PATH:-}" ]]; then
      log_error "K8S_MANIFEST_PATH not set"
      exit 1
    fi
    bash "$DEPLOY_OPS/deploy-k8s.sh" "$K8S_MANIFEST_PATH"
    ;;
  smoke)
    log_step "Running Smoke Tests"
    bash "$DEPLOY_OPS/smoke.sh"
    ;;
  all)
    log_step "Full Deployment Pipeline"
    bash "$SCRIPT_DIR/check-dependencies.sh" || exit 1
    bash "$SCRIPT_DIR/init-environment.sh" || exit 1
    log_info "Bootstrapping complete, ready to deploy"
    ;;
  *)
    echo "Usage: $0 {check|init|bootstrap|build|deploy|smoke|all}"
    exit 1
    ;;
esac

log_info "Done"
