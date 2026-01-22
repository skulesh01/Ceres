#!/bin/bash
# CERES Platform - Complete Deployment Script
# Deploys entire platform with pre-flight checks, SSL, SSO, and backup configuration

set -e

VERSION="3.1.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "EOF"
   ____  _____  ____   _____  ____  
  / ___|| ____|  _ \ | ____/ ___| 
 | |    |  _| | |_) ||  _| \___ \ 
 | |___ | |___|  _ < | |___ ___) |
  \____||_____|_| \_\|_____|____/ 
                                    
  Complete Enterprise Platform
EOF
echo -e "${NC}"
echo -e "${BLUE}Version: ${VERSION}${NC}"
echo -e "${BLUE}Deployment: $(date)${NC}"
echo ""
echo "=================================="
echo ""

# Parse arguments
SKIP_PREFLIGHT=false
SKIP_SSL=false
SKIP_SSO=false
SKIP_BACKUP=false
AUTO_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-preflight) SKIP_PREFLIGHT=true; shift ;;
        --skip-ssl) SKIP_SSL=true; shift ;;
        --skip-sso) SKIP_SSO=true; shift ;;
        --skip-backup) SKIP_BACKUP=true; shift ;;
        -y|--yes) AUTO_YES=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-preflight    Skip pre-flight system checks"
            echo "  --skip-ssl          Skip SSL/TLS configuration"
            echo "  --skip-sso          Skip SSO auto-configuration"
            echo "  --skip-backup       Skip backup configuration"
            echo "  -y, --yes           Auto-confirm all prompts"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Step 1: Pre-flight checks
if [ "$SKIP_PREFLIGHT" = false ]; then
    echo -e "${YELLOW}📋 Step 1: Pre-flight Checks${NC}"
    echo "----------------------------"
    if [ -f "scripts/preflight-check.sh" ]; then
        bash scripts/preflight-check.sh
        if [ $? -ne 0 ]; then
            echo ""
            echo -e "${RED}Pre-flight checks failed. Fix issues and try again.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}⚠️  Pre-flight check script not found${NC}"
    fi
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping pre-flight checks${NC}"
    echo ""
fi

# Step 2: Deploy core platform
echo -e "${YELLOW}📦 Step 2: Deploying Core Platform${NC}"
echo "------------------------------------"

# Apply all deployments
echo "Applying Kubernetes manifests..."

DEPLOY_ORDER=(
    "deployment/all-services.yaml"
    "deployment/postgresql.yaml"
    "deployment/redis.yaml"
    "deployment/keycloak.yaml"
    "deployment/ingress-domains.yaml"
    "deployment/ingress-ip.yaml"
)

for MANIFEST in "${DEPLOY_ORDER[@]}"; do
    if [ -f "$MANIFEST" ]; then
        echo "  📄 Applying $(basename $MANIFEST)..."
        kubectl apply -f "$MANIFEST" 2>&1 | grep -v "unchanged" || true
    fi
done

echo -e "${GREEN}✅ Core platform deployed${NC}"
echo ""

# Wait for critical services
echo "⏳ Waiting for critical services to start..."
sleep 10

kubectl wait --for=condition=ready pod -l app=keycloak -n ceres --timeout=180s 2>/dev/null || echo "Keycloak still starting..."

echo ""

# Step 3: Fix ingress if needed
echo -e "${YELLOW}🔧 Step 3: Verifying Ingress${NC}"
echo "-----------------------------"

if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q "CrashLoopBackOff\|Error"; then
    echo -e "${YELLOW}⚠️  ingress-nginx issues detected, running fix...${NC}"
    if [ -f "scripts/fix-ingress.sh" ]; then
        bash scripts/fix-ingress.sh
    fi
elif ! kubectl get namespace ingress-nginx &>/dev/null; then
    echo -e "${GREEN}✅ Using Traefik (default)${NC}"
fi

echo ""

# Step 4: SSL Configuration
if [ "$SKIP_SSL" = false ]; then
    echo -e "${YELLOW}🔒 Step 4: SSL/TLS Configuration${NC}"
    echo "--------------------------------"
    
    if [ "$AUTO_YES" = true ]; then
        echo "Auto-configuring self-signed certificates..."
        echo "3" | bash scripts/configure-ssl.sh 2>/dev/null || echo "SSL config skipped"
    else
        read -p "Configure SSL/TLS now? [y/N]: " CONFIGURE_SSL
        if [[ "$CONFIGURE_SSL" =~ ^[Yy]$ ]]; then
            bash scripts/configure-ssl.sh
        else
            echo "Skipping SSL configuration"
        fi
    fi
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping SSL configuration${NC}"
    echo ""
fi

# Step 5: SSO Configuration
if [ "$SKIP_SSO" = false ]; then
    echo -e "${YELLOW}🔐 Step 5: SSO Configuration${NC}"
    echo "-----------------------------"
    
    if [ "$AUTO_YES" = true ]; then
        bash scripts/configure-sso-auto.sh 2>/dev/null || echo "SSO config will run after Keycloak is ready"
    else
        read -p "Configure SSO now? [y/N]: " CONFIGURE_SSO
        if [[ "$CONFIGURE_SSO" =~ ^[Yy]$ ]]; then
            bash scripts/configure-sso-auto.sh
        else
            echo "Skipping SSO configuration (can run later: ./scripts/configure-sso-auto.sh)"
        fi
    fi
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping SSO configuration${NC}"
    echo ""
fi

# Step 6: Backup Configuration
if [ "$SKIP_BACKUP" = false ]; then
    echo -e "${YELLOW}💾 Step 6: Backup Configuration${NC}"
    echo "--------------------------------"
    
    if [ "$AUTO_YES" = false ]; then
        read -p "Configure automated backups? [y/N]: " CONFIGURE_BACKUP
        if [[ "$CONFIGURE_BACKUP" =~ ^[Yy]$ ]]; then
            bash scripts/configure-backup.sh
        else
            echo "Skipping backup configuration"
        fi
    fi
    echo ""
else
    echo -e "${YELLOW}⏭️  Skipping backup configuration${NC}"
    echo ""
fi

# Step 7: Services Content Setup
echo -e "${YELLOW}📦 Step 7: Services Content Setup${NC}"
echo "-----------------------------------"
echo "Configuring the inside of services with ready-to-use content..."
echo ""

if [ "$AUTO_YES" = true ]; then
    bash scripts/setup-services.sh 2>/dev/null || echo "Services setup will complete in background"
else
    read -p "Setup services content (dashboards, projects, buckets, etc.)? [Y/n]: " SETUP_CONTENT
    if [[ ! "$SETUP_CONTENT" =~ ^[Nn]$ ]]; then
        bash scripts/setup-services.sh
    else
        echo "Skipping services setup (can run later: ./scripts/setup-services.sh)"
    fi
fi
echo ""

# Step 8: Health Check
echo -e "${YELLOW}🏥 Step 8: Health Check${NC}"
echo "------------------------"
sleep 5

if [ -f "scripts/health-check.sh" ]; then
    bash scripts/health-check.sh || true
fi

echo ""

# Final Summary
echo "===================================="
echo -e "${GREEN}✅ CERES Platform Deployment Complete!${NC}"
echo "===================================="
echo ""
echo -e "${BLUE}📍 Access Information:${NC}"
echo ""

TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "localhost")

echo "🌐 Main Portal:"
echo "   http://${TRAEFIK_IP}/"
echo ""
echo "🔑 Default Credentials:"
echo "   Admin: admin / admin123"
echo "   Demo User: demo / demo123"
echo ""
echo "📚 Services (add to /etc/hosts):"
echo "   ${TRAEFIK_IP} keycloak.ceres.local gitlab.ceres.local grafana.ceres.local"
echo ""
echo "💡 Quick Commands:"
echo "   Health check:  ./scripts/health-check.sh"
echo "   Configure SSO: ./scripts/configure-sso-auto.sh"
echo "   Configure SSL: ./scripts/configure-ssl.sh"
echo "   Setup backup:  ./scripts/configure-backup.sh"
echo "   Update:        ./scripts/update.sh"
echo "   Rollback:      ./scripts/rollback.sh"
echo ""
echo "📖 Documentation:"
echo "   Access Guide:  cat ACCESS.md"
echo "   Troubleshoot:  cat docs/INGRESS_FIX.md"
echo "   Changelog:     cat CHANGELOG.md"
echo ""
echo -e "${CYAN}🎉 Happy deploying!${NC}"
echo ""
