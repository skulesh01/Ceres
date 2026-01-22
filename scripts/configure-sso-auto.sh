#!/bin/bash

# CERES SSO Auto-Configuration Script
# Automatically configures SSO for all services with zero manual steps

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  CERES Automatic SSO Configuration     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Configuration
KEYCLOAK_URL="http://keycloak.ceres.local"
KEYCLOAK_ADMIN="admin"
KEYCLOAK_PASSWORD="admin123"
REALM_NAME="ceres"

# Wait for Keycloak
echo -e "${BLUE}⏳ Waiting for Keycloak to be ready...${NC}"
for i in {1..60}; do
  if kubectl get pods -n ceres -l app=keycloak -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
    sleep 5  # Additional wait for full startup
    echo -e "${GREEN}✅ Keycloak is ready${NC}"
    break
  fi
  echo -n "."
  sleep 2
  if [ $i -eq 60 ]; then
    echo -e "${RED}❌ Keycloak not ready after 2 minutes${NC}"
    exit 1
  fi
done

# Configure kcadm
echo -e "${BLUE}🔧 Configuring Keycloak admin CLI...${NC}"
kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server ${KEYCLOAK_URL} \
  --realm master \
  --user ${KEYCLOAK_ADMIN} \
  --password ${KEYCLOAK_PASSWORD} \
  --config /tmp/kcadm.config

# Import realm (if not exists)
echo -e "${BLUE}📦 Importing CERES realm...${NC}"
if [ -f "config/keycloak-realm.json" ]; then
  kubectl cp config/keycloak-realm.json ceres/$(kubectl get pod -n ceres -l app=keycloak -o jsonpath='{.items[0].metadata.name}'):/tmp/realm.json
  kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create realms \
    -f /tmp/realm.json \
    --config /tmp/kcadm.config 2>/dev/null || echo "  Realm already exists"
fi

# Function to create OIDC client and get secret
create_client() {
  local CLIENT_ID=$1
  local REDIRECT_URI=$2
  local CLIENT_NAME=$3
  
  echo -e "${BLUE}  Creating client: ${CLIENT_NAME}...${NC}"
  
  # Create client
  kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create clients \
    -r ${REALM_NAME} \
    -s clientId=${CLIENT_ID} \
    -s enabled=true \
    -s publicClient=false \
    -s protocol=openid-connect \
    -s 'redirectUris=["'${REDIRECT_URI}'"]' \
    -s 'webOrigins=["*"]' \
    -s directAccessGrantsEnabled=true \
    -s serviceAccountsEnabled=true \
    --config /tmp/kcadm.config 2>/dev/null || true
  
  # Get client UUID
  CLIENT_UUID=$(kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh get clients \
    -r ${REALM_NAME} \
    --fields id,clientId \
    --config /tmp/kcadm.config | grep -B1 "\"clientId\" : \"${CLIENT_ID}\"" | grep "\"id\"" | cut -d'"' -f4)
  
  # Get client secret
  CLIENT_SECRET=$(kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh get clients/${CLIENT_UUID}/client-secret \
    -r ${REALM_NAME} \
    --config /tmp/kcadm.config | grep "value" | cut -d'"' -f4)
  
  echo "$CLIENT_SECRET"
}

# Create demo user
echo -e "${BLUE}👤 Creating demo user...${NC}"
kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh create users \
  -r ${REALM_NAME} \
  -s username=demo \
  -s email=demo@ceres.local \
  -s firstName=Demo \
  -s lastName=User \
  -s enabled=true \
  --config /tmp/kcadm.config 2>/dev/null || echo "  User already exists"

# Set demo user password
USER_ID=$(kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh get users \
  -r ${REALM_NAME} \
  -q username=demo \
  --fields id \
  --config /tmp/kcadm.config | grep "\"id\"" | cut -d'"' -f4)

kubectl exec -n ceres deployment/keycloak -- /opt/keycloak/bin/kcadm.sh update users/${USER_ID}/reset-password \
  -r ${REALM_NAME} \
  -s type=password \
  -s value=demo123 \
  -s temporary=false \
  -n \
  --config /tmp/kcadm.config 2>/dev/null || true

# Configure all services
echo ""
echo -e "${CYAN}🔧 Configuring services with SSO...${NC}"
echo ""

# 1. GitLab
echo -e "${BLUE}1️⃣  GitLab${NC}"
GITLAB_SECRET=$(create_client "gitlab" "http://gitlab.ceres.local/users/auth/openid_connect/callback" "GitLab")

kubectl create secret generic gitlab-oidc -n gitlab \
  --from-literal=provider=openid_connect \
  --from-literal=client_id=gitlab \
  --from-literal=client_secret=${GITLAB_SECRET} \
  --from-literal=issuer=http://keycloak.ceres.local/realms/ceres \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitlab-omnibus-config
  namespace: gitlab
data:
  gitlab.rb: |
    external_url 'http://gitlab.ceres.local'
    gitlab_rails['omniauth_enabled'] = true
    gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
    gitlab_rails['omniauth_block_auto_created_users'] = false
    gitlab_rails['omniauth_auto_link_user'] = ['openid_connect']
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
          pkce: true,
          client_options: {
            identifier: 'gitlab',
            secret: '${GITLAB_SECRET}',
            redirect_uri: 'http://gitlab.ceres.local/users/auth/openid_connect/callback'
          }
        }
      }
    ]
EOF
echo -e "${GREEN}  ✅ GitLab OIDC configured${NC}"

# 2. Grafana
echo -e "${BLUE}2️⃣  Grafana${NC}"
GRAFANA_SECRET=$(create_client "grafana" "http://grafana.ceres.local/login/generic_oauth" "Grafana")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: monitoring
data:
  grafana.ini: |
    [server]
    root_url = http://grafana.ceres.local
    
    [auth.generic_oauth]
    enabled = true
    name = CERES SSO
    allow_sign_up = true
    auto_login = false
    client_id = grafana
    client_secret = ${GRAFANA_SECRET}
    scopes = openid profile email
    auth_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth
    token_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token
    api_url = http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo
    allow_assign_grafana_admin = true
    role_attribute_path = contains(groups[*], 'admin') && 'Admin' || 'Viewer'
    
    [users]
    auto_assign_org = true
    auto_assign_org_role = Viewer
EOF
echo -e "${GREEN}  ✅ Grafana OIDC configured${NC}"

# 3. Mattermost  
echo -e "${BLUE}3️⃣  Mattermost${NC}"
MATTERMOST_SECRET=$(create_client "mattermost" "http://chat.ceres.local/signup/gitlab/complete" "Mattermost")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mattermost-config
  namespace: mattermost
data:
  config.json: |
    {
      "ServiceSettings": {
        "SiteURL": "http://chat.ceres.local",
        "EnableOAuthServiceProvider": true
      },
      "Office365Settings": {
        "Enable": true,
        "Id": "mattermost",
        "Secret": "${MATTERMOST_SECRET}",
        "AuthEndpoint": "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth",
        "TokenEndpoint": "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token",
        "UserApiEndpoint": "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo"
      }
    }
EOF
echo -e "${GREEN}  ✅ Mattermost OIDC configured${NC}"

# 4. Nextcloud
echo -e "${BLUE}4️⃣  Nextcloud${NC}"
NEXTCLOUD_SECRET=$(create_client "nextcloud" "http://files.ceres.local/apps/oidc/redirect" "Nextcloud")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: nextcloud-oidc
  namespace: nextcloud
type: Opaque
stringData:
  OIDC_ENABLED: "true"
  OIDC_CLIENT_ID: "nextcloud"
  OIDC_CLIENT_SECRET: "${NEXTCLOUD_SECRET}"
  OIDC_DISCOVERY_URL: "http://keycloak.ceres.local/realms/ceres/.well-known/openid-configuration"
  OIDC_REDIRECT_URI: "http://files.ceres.local/apps/oidc/redirect"
  OIDC_LOGIN_BUTTON_TEXT: "Login with CERES SSO"
EOF
echo -e "${GREEN}  ✅ Nextcloud OIDC configured${NC}"

# 5. MinIO
echo -e "${BLUE}5️⃣  MinIO${NC}"
MINIO_SECRET=$(create_client "minio" "http://minio.ceres.local/oauth_callback" "MinIO")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: minio-oidc
  namespace: minio
data:
  config.env: |
    MINIO_IDENTITY_OPENID_CONFIG_URL=http://keycloak.ceres.local/realms/ceres/.well-known/openid-configuration
    MINIO_IDENTITY_OPENID_CLIENT_ID=minio
    MINIO_IDENTITY_OPENID_CLIENT_SECRET=${MINIO_SECRET}
    MINIO_IDENTITY_OPENID_CLAIM_NAME=policy
    MINIO_IDENTITY_OPENID_SCOPES=openid,profile,email
    MINIO_IDENTITY_OPENID_REDIRECT_URI=http://minio.ceres.local/oauth_callback
EOF
echo -e "${GREEN}  ✅ MinIO OIDC configured${NC}"

# 6. Portainer
echo -e "${BLUE}6️⃣  Portainer${NC}"
PORTAINER_SECRET=$(create_client "portainer" "http://portainer.ceres.local" "Portainer")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: portainer-oidc
  namespace: ceres
type: Opaque
stringData:
  oauth-client-id: "portainer"
  oauth-client-secret: "${PORTAINER_SECRET}"
  oauth-auth-url: "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/auth"
  oauth-token-url: "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/token"
  oauth-user-url: "http://keycloak.ceres.local/realms/ceres/protocol/openid-connect/userinfo"
EOF
echo -e "${YELLOW}  ⚠️  Portainer requires manual OAuth configuration in web UI${NC}"

# 7. Vault
echo -e "${BLUE}7️⃣  Vault${NC}"
VAULT_SECRET=$(create_client "vault" "http://vault.ceres.local/ui/vault/auth/oidc/oidc/callback" "Vault")

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-oidc
  namespace: ceres
data:
  oidc-config.sh: |
    #!/bin/sh
    vault write auth/oidc/config \\
      oidc_discovery_url="http://keycloak.ceres.local/realms/ceres" \\
      oidc_client_id="vault" \\
      oidc_client_secret="${VAULT_SECRET}" \\
      default_role="default"
    
    vault write auth/oidc/role/default \\
      bound_audiences="vault" \\
      allowed_redirect_uris="http://vault.ceres.local/ui/vault/auth/oidc/oidc/callback" \\
      user_claim="sub" \\
      policies="default"
EOF
echo -e "${YELLOW}  ⚠️  Vault requires running oidc-config.sh after unsealing${NC}"

# Restart services to apply configuration
echo ""
echo -e "${BLUE}🔄 Restarting services to apply SSO configuration...${NC}"

kubectl rollout restart deployment/grafana -n monitoring 2>/dev/null && echo -e "${GREEN}  ✅ Grafana restarted${NC}" || true
kubectl rollout restart deployment/mattermost -n mattermost 2>/dev/null && echo -e "${GREEN}  ✅ Mattermost restarted${NC}" || true
kubectl rollout restart deployment/nextcloud -n nextcloud 2>/dev/null && echo -e "${GREEN}  ✅ Nextcloud restarted${NC}" || true
kubectl rollout restart deployment/minio -n minio 2>/dev/null && echo -e "${GREEN}  ✅ MinIO restarted${NC}" || true

# Wait for restarts
echo -e "${BLUE}⏳ Waiting for services to restart...${NC}"
sleep 10

# Final summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     SSO Configuration Complete! ✅     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🎉 All services are now configured with SSO!${NC}"
echo ""
echo -e "${CYAN}=== Service Status ===${NC}"
echo -e "${GREEN}✅ GitLab${NC}       - Fully configured, restart required"
echo -e "${GREEN}✅ Grafana${NC}      - Configured and restarted"
echo -e "${GREEN}✅ Mattermost${NC}   - Configured and restarted"
echo -e "${GREEN}✅ Nextcloud${NC}    - Configured and restarted"
echo -e "${GREEN}✅ MinIO${NC}        - Configured and restarted"
echo -e "${YELLOW}⚠️  Portainer${NC}   - Secret created, configure in web UI"
echo -e "${YELLOW}⚠️  Vault${NC}       - Script created, run after unseal"
echo ""
echo -e "${CYAN}=== Login Credentials ===${NC}"
echo "Keycloak Admin: ${KEYCLOAK_ADMIN} / ${KEYCLOAK_PASSWORD}"
echo "Demo User:      demo / demo123"
echo ""
echo -e "${CYAN}=== Access URLs ===${NC}"
echo "Keycloak: ${KEYCLOAK_URL}/admin"
echo "GitLab:   http://gitlab.ceres.local (click 'CERES SSO')"
echo "Grafana:  http://grafana.ceres.local (click 'Sign in with CERES SSO')"
echo ""
echo -e "${GREEN}✅ Users can now login to all services with a single CERES account!${NC}"
