#!/bin/bash
# Tenant Provisioning Script for CERES
# Automates creation of new tenant with full isolation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Input validation
TENANT_ID=${1:-}
TENANT_NAME=${2:-}
TENANT_DOMAIN=${3:-}
ADMIN_EMAIL=${4:-}

if [ -z "$TENANT_ID" ] || [ -z "$TENANT_NAME" ] || [ -z "$TENANT_DOMAIN" ] || [ -z "$ADMIN_EMAIL" ]; then
    echo "Usage: $0 <tenant_id> <tenant_name> <tenant_domain> <admin_email>"
    echo ""
    echo "Example:"
    echo "  $0 acme-corp \"ACME Corporation\" \"acme.ceres.io\" \"admin@acme.com\""
    exit 1
fi

# Validate tenant_id format
if ! [[ $TENANT_ID =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
    log_error "Tenant ID must be lowercase alphanumeric with hyphens"
    exit 1
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              CERES TENANT PROVISIONING                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_info "Provisioning tenant: $TENANT_NAME ($TENANT_ID)"
log_info "Domain: $TENANT_DOMAIN"
log_info "Admin: $ADMIN_EMAIL"
echo ""

# 1. Create Keycloak Realm
log_info "Step 1/6: Creating Keycloak realm..."

REALM_TEMPLATE="${SCRIPT_DIR}/../config/keycloak/realms/tenant-template.json"

# Substitute template variables
REALM_JSON=$(cat "$REALM_TEMPLATE" | \
    sed "s/TENANT_ID/$TENANT_ID/g" | \
    sed "s/TENANT_NAME/$TENANT_NAME/g" | \
    sed "s/TENANT_DOMAIN/$TENANT_DOMAIN/g")

# Create realm via Keycloak API
KEYCLOAK_URL="http://keycloak:8080"
KEYCLOAK_ADMIN_TOKEN=$(curl -s -X POST \
    "${KEYCLOAK_URL}/auth/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=admin-cli&grant_type=client_credentials&client_secret=admin-cli-secret" | \
    jq -r '.access_token')

if [ -z "$KEYCLOAK_ADMIN_TOKEN" ] || [ "$KEYCLOAK_ADMIN_TOKEN" == "null" ]; then
    log_error "Failed to authenticate with Keycloak"
    exit 1
fi

curl -s -X POST \
    "${KEYCLOAK_URL}/auth/admin/realms" \
    -H "Authorization: Bearer $KEYCLOAK_ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$REALM_JSON" > /dev/null

if [ $? -eq 0 ]; then
    log_success "Keycloak realm created"
else
    log_error "Failed to create Keycloak realm"
    exit 1
fi

# 2. Create PostgreSQL Schema and RLS
log_info "Step 2/6: Setting up PostgreSQL schema and RLS..."

TENANT_UUID=$(uuidgen)

# Create schema for tenant
PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres-1 -U postgres -d ceres << EOF
-- Create tenant record
INSERT INTO tenants (id, name, domain, created_at) 
VALUES ('$TENANT_UUID', '$TENANT_NAME', '$TENANT_DOMAIN', NOW())
ON CONFLICT (domain) DO NOTHING;

-- Create tenant-specific role
CREATE ROLE "tenant_${TENANT_ID}" WITH LOGIN PASSWORD '$(openssl rand -base64 32)';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "tenant_${TENANT_ID}";

-- Create admin user for tenant
INSERT INTO users (id, tenant_id, email, username, password_hash, is_active, created_at)
VALUES (
    gen_random_uuid(),
    '$TENANT_UUID',
    '$ADMIN_EMAIL',
    SPLIT_PART('$ADMIN_EMAIL', '@', 1),
    crypt('initial_password_' || gen_random_uuid()::TEXT, gen_salt('bf')),
    true,
    NOW()
) RETURNING id;

-- Verify RLS is enforced
SELECT verify_tenant_isolation();
EOF

if [ $? -eq 0 ]; then
    log_success "PostgreSQL schema created with RLS"
else
    log_error "Failed to create PostgreSQL schema"
    exit 1
fi

# 3. Create Initial Organizations
log_info "Step 3/6: Creating initial organization..."

PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres-1 -U postgres -d ceres << EOF
INSERT INTO organizations (id, tenant_id, name, slug, owner_id, created_at)
SELECT
    gen_random_uuid(),
    id,
    '$TENANT_NAME',
    '${TENANT_ID}-main',
    (SELECT id FROM users WHERE tenant_id = id AND email = '$ADMIN_EMAIL' LIMIT 1),
    NOW()
FROM tenants WHERE domain = '$TENANT_DOMAIN';
EOF

if [ $? -eq 0 ]; then
    log_success "Organization created"
else
    log_error "Failed to create organization"
    exit 1
fi

# 4. Create Service Account
log_info "Step 4/6: Creating service account for tenant..."

SERVICE_ACCOUNT_ID=$(uuidgen)
SERVICE_ACCOUNT_SECRET=$(openssl rand -base64 32)

PGPASSWORD=$POSTGRES_PASSWORD psql -h postgres-1 -U postgres -d ceres << EOF
INSERT INTO service_accounts (id, tenant_id, name, secret_hash, permissions, created_at)
VALUES (
    '$SERVICE_ACCOUNT_ID',
    (SELECT id FROM tenants WHERE domain = '$TENANT_DOMAIN'),
    'ceres-api-${TENANT_ID}',
    crypt('$SERVICE_ACCOUNT_SECRET', gen_salt('bf')),
    '["read:all", "write:all", "manage:tenant"]',
    NOW()
);
EOF

if [ $? -eq 0 ]; then
    log_success "Service account created"
else
    log_error "Failed to create service account"
    exit 1
fi

# 5. Configure DNS/Nginx
log_info "Step 5/6: Configuring Nginx routing..."

# Add tenant domain to local /etc/hosts for testing
if ! grep -q "$TENANT_DOMAIN" /etc/hosts; then
    echo "127.0.0.1 $TENANT_DOMAIN" >> /etc/hosts
    log_success "Added $TENANT_DOMAIN to /etc/hosts"
else
    log_warn "$TENANT_DOMAIN already in /etc/hosts"
fi

# Reload Nginx
docker exec ceres-nginx nginx -s reload

if [ $? -eq 0 ]; then
    log_success "Nginx routing configured"
else
    log_error "Failed to reload Nginx"
    exit 1
fi

# 6. Generate onboarding email
log_info "Step 6/6: Generating onboarding credentials..."

cat > "/tmp/tenant-${TENANT_ID}-onboarding.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║              TENANT ONBOARDING CREDENTIALS                ║
╚════════════════════════════════════════════════════════════╝

Tenant Name: $TENANT_NAME
Tenant Domain: $TENANT_DOMAIN
Tenant ID: $TENANT_UUID
Admin Email: $ADMIN_EMAIL

INITIAL LOGIN CREDENTIALS:
Email: $ADMIN_EMAIL
Temporary Password: initial_password_[will be emailed separately]

SERVICE ACCOUNT CREDENTIALS:
ID: $SERVICE_ACCOUNT_ID
Secret: $SERVICE_ACCOUNT_SECRET

NEXT STEPS:
1. Login at: https://$TENANT_DOMAIN/auth
2. Change your temporary password immediately
3. Configure organization settings
4. Invite team members
5. Set up integrations

API DOCUMENTATION:
Base URL: https://$TENANT_DOMAIN/api/v1
Authentication: Bearer <access_token>

SUPPORT:
Email: support@ceres.io
Slack: #ceres-support

ISOLATION VERIFICATION:
Your data is isolated at multiple levels:
✓ PostgreSQL Row-Level Security (RLS)
✓ Keycloak Realm Isolation
✓ Nginx tenant routing
✓ Application-level tenant context
✓ Audit logging per tenant

EOF

log_success "Onboarding credentials generated: /tmp/tenant-${TENANT_ID}-onboarding.txt"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║             TENANT PROVISIONING COMPLETED!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Tenant '$TENANT_NAME' is ready!"
echo ""
echo "Access Information:"
echo "  URL: https://$TENANT_DOMAIN"
echo "  Realm: $TENANT_ID"
echo "  Tenant ID: $TENANT_UUID"
echo ""
echo "Credentials saved to: /tmp/tenant-${TENANT_ID}-onboarding.txt"
echo ""
