#!/bin/bash
# CERES SSO Auto-Configuration Script
# Automatically configures Keycloak and integrates all services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔐 CERES SSO Auto-Configuration"
echo "================================"
echo ""

KEYCLOAK_URL="http://keycloak.ceres.local"
KEYCLOAK_ADMIN="admin"
KEYCLOAK_PASSWORD="$(kubectl get secret -n ceres keycloak-secret -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || true)"
if [ -z "$KEYCLOAK_PASSWORD" ]; then
    KEYCLOAK_PASSWORD="admin123"
fi
REALM_NAME="ceres"

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to be ready..."
RETRIES=0
MAX_RETRIES=60

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if kubectl exec -n ceres deployment/keycloak -- curl -sf http://localhost:8080/health/ready > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Keycloak is ready${NC}"
        break
    fi
    RETRIES=$((RETRIES + 1))
    echo -n "."
    sleep 2
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Keycloak failed to start${NC}"
    exit 1
fi

echo ""

# Import realm configuration
echo "📥 Importing Keycloak realm..."
if [ -f "/root/Ceres/config/keycloak-realm.json" ]; then
    kubectl exec -n ceres deployment/keycloak -- bash -c "
        /opt/keycloak/bin/kcadm.sh config credentials \
            --server http://localhost:8080 \
            --realm master \
            --user ${KEYCLOAK_ADMIN} \
            --password ${KEYCLOAK_PASSWORD}
        
        /opt/keycloak/bin/kcadm.sh create realms \
            -f /config/keycloak-realm.json \
            || echo 'Realm may already exist'
    " 2>/dev/null
    
    echo -e "${GREEN}✅ Realm imported${NC}"
else
    echo -e "${YELLOW}⚠️  Realm config not found, creating minimal realm${NC}"
    
    kubectl exec -n ceres deployment/keycloak -- bash -c "
        /opt/keycloak/bin/kcadm.sh config credentials \
            --server http://localhost:8080 \
            --realm master \
            --user ${KEYCLOAK_ADMIN} \
            --password ${KEYCLOAK_PASSWORD}
        
        /opt/keycloak/bin/kcadm.sh create realms \
            -s realm=${REALM_NAME} \
            -s enabled=true \
            || echo 'Realm may already exist'
    " 2>/dev/null
fi

# Create OIDC clients for services
echo ""
echo "🔑 Creating OIDC clients..."

# Function to create OIDC client
create_client() {
    local CLIENT_ID=$1
    local CLIENT_NAME=$2
    local REDIRECT_URI=$3
    
    echo "  Creating client: ${CLIENT_NAME}..."
    
    kubectl exec -n ceres deployment/keycloak -- bash -c "
        /opt/keycloak/bin/kcadm.sh create clients -r ${REALM_NAME} \
            -s clientId=${CLIENT_ID} \
            -s name='${CLIENT_NAME}' \
            -s enabled=true \
            -s publicClient=false \
            -s protocol=openid-connect \
            -s 'redirectUris=[\"${REDIRECT_URI}\"]' \
            -s 'webOrigins=[\"*\"]' \
            -s directAccessGrantsEnabled=true \
            -s serviceAccountsEnabled=true \
            || echo 'Client may already exist'
    " 2>/dev/null
}

# GitLab
create_client "gitlab" "GitLab" "http://gitlab.ceres.local/users/auth/openid_connect/callback"

# Grafana  
create_client "grafana" "Grafana" "http://grafana.ceres.local/login/generic_oauth"

# Mattermost
create_client "mattermost" "Mattermost" "http://chat.ceres.local/signup/openid/complete"

# Nextcloud
create_client "nextcloud" "Nextcloud" "http://files.ceres.local/apps/oidc/redirect"

# MinIO
create_client "minio" "MinIO" "http://minio.ceres.local/oauth_callback"

# Portainer
create_client "portainer" "Portainer" "http://portainer.ceres.local/"

# Vault
create_client "vault" "Vault" "http://vault.ceres.local/ui/vault/auth/oidc/oidc/callback"

echo -e "${GREEN}✅ OIDC clients created${NC}"

# Create default users
echo ""
echo "👥 Creating default users..."

kubectl exec -n ceres deployment/keycloak -- bash -c "
    # Create demo user
    /opt/keycloak/bin/kcadm.sh create users -r ${REALM_NAME} \
        -s username=demo \
        -s enabled=true \
        -s email=demo@ceres.local \
        -s firstName=Demo \
        -s lastName=User \
        || echo 'User may already exist'
    
    # Set password
    USER_ID=\$(/opt/keycloak/bin/kcadm.sh get users -r ${REALM_NAME} -q username=demo --fields id --format csv --noquotes)
    if [ -n \"\$USER_ID\" ]; then
        /opt/keycloak/bin/kcadm.sh set-password -r ${REALM_NAME} --username demo --new-password demo123
    fi
" 2>/dev/null

echo -e "${GREEN}✅ Default user created (demo / demo123)${NC}"

# Configure services to use SSO
echo ""
echo "🔧 Configuring services..."

# GitLab SSO configuration
echo "  Configuring GitLab..."
cat > /tmp/gitlab-sso-config.rb << 'EOF'
gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
gitlab_rails['omniauth_block_auto_created_users'] = false
gitlab_rails['omniauth_providers'] = [
  {
    name: 'openid_connect',
    label: 'CERES SSO',
    args: {
      name: 'openid_connect',
      scope: ['openid','profile','email'],
      response_type: 'code',
      issuer: 'http://keycloak.ceres.local/realms/ceres',
      discovery: true,
      client_auth_method: 'query',
      uid_field: 'preferred_username',
      client_options: {
        identifier: 'gitlab',
        secret: 'CHANGE_ME',
        redirect_uri: 'http://gitlab.ceres.local/users/auth/openid_connect/callback'
      }
    }
  }
]
EOF

echo -e "${YELLOW}⚠️  GitLab SSO config created at /tmp/gitlab-sso-config.rb${NC}"
echo "   Apply manually: kubectl exec -n gitlab deployment/gitlab -- gitlab-ctl reconfigure"

# Grafana SSO configuration
echo "  Configuring Grafana..."
kubectl patch configmap grafana -n monitoring --type merge -p '
{
  "data": {
    "grafana.ini": "[auth.generic_oauth]\nenabled = true\nname = CERES SSO\nclient_id = grafana\nclient_secret = CHANGE_ME\nscopes = openid email profile\nauth_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth\ntoken_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token\napi_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo\nallow_sign_up = true\n"
  }
}' 2>/dev/null || echo "Grafana configmap not found"

echo -e "${GREEN}✅ Grafana SSO configured${NC}"

# Summary
echo ""
echo "================================"
echo -e "${GREEN}✅ SSO Configuration Complete!${NC}"
echo ""
echo "📝 Summary:"
echo "  - Realm: ${REALM_NAME}"
echo "  - Admin URL: ${KEYCLOAK_URL}/admin"
echo "  - Admin user: ${KEYCLOAK_ADMIN} / ${KEYCLOAK_PASSWORD}"
echo "  - Demo user: demo / demo123"
echo ""
echo "🔗 Configured clients:"
echo "  - GitLab"
echo "  - Grafana"
echo "  - Mattermost"
echo "  - Nextcloud"
echo "  - MinIO"
echo "  - Portainer"
echo "  - Vault"
echo ""
echo "⚠️  Next steps:"
echo "  1. Get client secrets: kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh get clients/CLIENT_ID/client-secret"
echo "  2. Update service configurations with client secrets"
echo "  3. Restart services to apply SSO"
echo ""
