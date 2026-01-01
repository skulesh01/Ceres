#!/bin/bash
#
# CERES Operators - Complete Deployment & Management Script
# v2.9.0 - Installs and configures all Kubernetes Operators
# Supports: Tenant Operator, Backup Operator, Database Operator, Webhooks
#

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="${NAMESPACE:-ceres}"
RELEASE_NAME="${RELEASE_NAME:-ceres-operators}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-ghcr.io/ceres-platform}"
OPERATOR_VERSION="${OPERATOR_VERSION:-2.9.0}"
KEYCLOAK_URL="${KEYCLOAK_URL:-http://keycloak:8080}"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"

# =====================================================
# Helper Functions
# =====================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed"
        exit 1
    fi
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    check_command kubectl
    check_command helm
    check_command python3
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

create_namespace() {
    log_info "Creating namespace '$NAMESPACE'..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace '$NAMESPACE' already exists"
    else
        kubectl create namespace "$NAMESPACE"
        kubectl label namespace "$NAMESPACE" \
            app.kubernetes.io/name="ceres" \
            app.kubernetes.io/version="$OPERATOR_VERSION"
        log_success "Namespace created"
    fi
}

install_crds() {
    log_info "Installing Custom Resource Definitions (CRDs)..."
    
    # CeresPlatform CRD
    kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: ceresplatforms.ceres.io
spec:
  group: ceres.io
  names:
    kind: CeresPlatform
    plural: ceresplatforms
  scope: Namespaced
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
EOF
    
    log_success "CRDs installed"
}

create_secrets() {
    log_info "Creating required secrets..."
    
    # Keycloak credentials
    if ! kubectl get secret keycloak-credentials -n "$NAMESPACE" &> /dev/null; then
        log_info "Creating keycloak-credentials secret..."
        kubectl create secret generic keycloak-credentials \
            --from-literal=username=admin \
            --from-literal=password="${KEYCLOAK_ADMIN_PASSWORD:-admin}" \
            -n "$NAMESPACE"
        log_success "Keycloak secret created"
    else
        log_warning "Keycloak secret already exists"
    fi
    
    # Database credentials
    if ! kubectl get secret db-credentials -n "$NAMESPACE" &> /dev/null; then
        log_info "Creating db-credentials secret..."
        kubectl create secret generic db-credentials \
            --from-literal=username=postgres \
            --from-literal=password="${DB_ADMIN_PASSWORD:-postgres}" \
            --from-literal=host="$DB_HOST" \
            --from-literal=port="$DB_PORT" \
            -n "$NAMESPACE"
        log_success "Database secret created"
    else
        log_warning "Database secret already exists"
    fi
    
    # AWS/S3 credentials for backups
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
        if ! kubectl get secret backup-credentials -n "$NAMESPACE" &> /dev/null; then
            log_info "Creating backup-credentials secret..."
            kubectl create secret generic backup-credentials \
                --from-literal=aws-access-key="$AWS_ACCESS_KEY_ID" \
                --from-literal=aws-secret-key="$AWS_SECRET_ACCESS_KEY" \
                -n "$NAMESPACE"
            log_success "Backup credentials secret created"
        fi
    fi
}

build_operator_images() {
    log_info "Building operator container images..."
    
    OPERATORS=("tenant-operator" "backup-operator" "database-operator")
    
    for operator in "${OPERATORS[@]}"; do
        log_info "Building $operator image..."
        
        # Build from Dockerfile (assuming it exists)
        if [[ -f "docker/$operator/Dockerfile" ]]; then
            docker build \
                -t "${DOCKER_REGISTRY}/${operator}:${OPERATOR_VERSION}" \
                -f "docker/$operator/Dockerfile" \
                .
            log_success "$operator image built"
        else
            log_warning "Dockerfile not found for $operator, skipping build"
        fi
    done
}

deploy_operators() {
    log_info "Deploying operators to Kubernetes..."
    
    # Tenant Operator
    log_info "Deploying Tenant Operator..."
    kubectl apply -f config/operators/tenant-operator-deployment.yml -n "$NAMESPACE"
    
    # Backup Operator
    log_info "Deploying Backup Operator..."
    kubectl apply -f config/operators/backup-operator.yml -n "$NAMESPACE"
    
    # Database Operator
    log_info "Deploying Database Operator..."
    kubectl apply -f config/operators/database-operator.yml -n "$NAMESPACE"
    
    log_success "Operators deployed"
}

install_webhooks() {
    log_info "Installing webhook server..."
    
    # Generate TLS certificates
    log_info "Generating webhook TLS certificates..."
    openssl req -x509 -newkey rsa:2048 \
        -keyout /tmp/webhook-key.pem \
        -out /tmp/webhook-cert.pem \
        -days 365 -nodes \
        -subj "/CN=webhook.$NAMESPACE.svc"
    
    # Create webhook secret
    kubectl create secret tls webhook-tls \
        --cert=/tmp/webhook-cert.pem \
        --key=/tmp/webhook-key.pem \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Webhook certificates created"
}

wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-300}
    
    log_info "Waiting for deployment '$deployment' to be ready (timeout: ${timeout}s)..."
    
    if kubectl rollout status deployment/"$deployment" \
        -n "$NAMESPACE" \
        --timeout="${timeout}s"; then
        log_success "Deployment '$deployment' is ready"
        return 0
    else
        log_error "Deployment '$deployment' failed to become ready"
        return 1
    fi
}

verify_deployment() {
    log_info "Verifying operators deployment..."
    
    # Check operator pods
    echo -e "\n${BLUE}Operator Pods:${NC}"
    kubectl get pods -n "$NAMESPACE" -l app in (tenant-operator,backup-operator,database-operator)
    
    # Check CRDs
    echo -e "\n${BLUE}Custom Resource Definitions:${NC}"
    kubectl get crd | grep ceres.io
    
    # Check services
    echo -e "\n${BLUE}Services:${NC}"
    kubectl get svc -n "$NAMESPACE"
    
    log_success "Deployment verification complete"
}

create_example_resources() {
    log_info "Creating example CeresTenant resource..."
    
    kubectl apply -f - <<EOF
apiVersion: ceres.io/v1alpha1
kind: CeresTenant
metadata:
  name: acme-corp
  namespace: $NAMESPACE
spec:
  tenantId: acme
  name: "ACME Corporation"
  displayName: "ACME Corp"
  plan: professional
  admin:
    username: admin
    email: admin@acme.example.com
    firstName: Admin
    lastName: User
  keycloak:
    createRealm: true
EOF
    
    log_success "Example tenant created"
}

uninstall() {
    log_info "Uninstalling CERES Operators..."
    
    # Remove operators
    kubectl delete deployment -n "$NAMESPACE" \
        tenant-operator backup-operator database-operator \
        --ignore-not-found=true
    
    # Remove CRDs (careful!)
    kubectl delete crd \
        ceresplatforms.ceres.io \
        cerestenants.ceres.io \
        ceresbackups.ceres.io \
        ceresdatabases.ceres.io \
        --ignore-not-found=true
    
    # Remove namespace
    kubectl delete namespace "$NAMESPACE" --ignore-not-found=true
    
    log_success "Operators uninstalled"
}

print_summary() {
    cat <<EOF

${BLUE}═══════════════════════════════════════════════════════════════${NC}
${GREEN}✓ CERES Operators v${OPERATOR_VERSION} Installation Complete!${NC}
${BLUE}═══════════════════════════════════════════════════════════════${NC}

${YELLOW}Namespace:${NC}
  kubectl config set-context --current --namespace=$NAMESPACE

${YELLOW}Check Operator Status:${NC}
  kubectl get pods -n $NAMESPACE
  kubectl get crd | grep ceres.io
  kubectl logs -n $NAMESPACE -l app=tenant-operator -f

${YELLOW}Create New Tenant:${NC}
  kubectl apply -f config/examples/tenant-example.yml

${YELLOW}Monitor Backups:${NC}
  kubectl get ceresbackups -n $NAMESPACE -w

${YELLOW}View Database Status:${NC}
  kubectl get ceresdatabases -n $NAMESPACE

${YELLOW}Uninstall:${NC}
  ./scripts/deploy-operators.sh uninstall

${BLUE}═══════════════════════════════════════════════════════════════${NC}

EOF
}

# =====================================================
# Main
# =====================================================

main() {
    case "${1:-}" in
        uninstall)
            uninstall
            ;;
        *)
            log_info "CERES Operators Deployment Script v$OPERATOR_VERSION"
            
            check_prerequisites
            create_namespace
            install_crds
            create_secrets
            deploy_operators
            install_webhooks
            
            # Wait for deployments
            wait_for_deployment "tenant-operator" 300
            wait_for_deployment "backup-operator" 300
            wait_for_deployment "database-operator" 300
            
            # Verify and show summary
            verify_deployment
            create_example_resources
            print_summary
            ;;
    esac
}

main "$@"
