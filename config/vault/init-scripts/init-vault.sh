#!/bin/bash
# Initialize and configure HashiCorp Vault for CERES

set -e

VAULT_ADDR="http://vault:8200"
KEYS_FILE="/vault/keys/vault-keys.json"

echo "🔐 Initializing HashiCorp Vault..."

# Wait for Vault to be ready
until vault status > /dev/null 2>&1; do
  echo "Waiting for Vault to be ready..."
  sleep 2
done

# Check if already initialized
if vault status | grep -q "Initialized.*true"; then
  echo "✓ Vault already initialized"
  exit 0
fi

echo "✓ Initializing Vault with 5 key shares and threshold of 3..."
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > "$KEYS_FILE"

echo "✓ Vault initialized successfully!"
echo ""
echo "⚠️  IMPORTANT: Save these keys securely!"
cat "$KEYS_FILE"
echo ""

# Extract unseal keys and root token
UNSEAL_KEY_1=$(cat "$KEYS_FILE" | jq -r '.unseal_keys_b64[0]')
UNSEAL_KEY_2=$(cat "$KEYS_FILE" | jq -r '.unseal_keys_b64[1]')
UNSEAL_KEY_3=$(cat "$KEYS_FILE" | jq -r '.unseal_keys_b64[2]')
ROOT_TOKEN=$(cat "$KEYS_FILE" | jq -r '.root_token')

# Unseal Vault
echo "🔓 Unsealing Vault..."
vault operator unseal "$UNSEAL_KEY_1"
vault operator unseal "$UNSEAL_KEY_2"
vault operator unseal "$UNSEAL_KEY_3"

# Login with root token
echo "✓ Logging in with root token..."
vault login "$ROOT_TOKEN"

# Enable secrets engines
echo "✓ Enabling secrets engines..."
vault secrets enable -path=ceres kv-v2
vault secrets enable -path=database database
vault secrets enable -path=pki pki
vault secrets enable transit

# Configure PKI for mTLS
echo "✓ Configuring PKI for mTLS..."
vault secrets tune -max-lease-ttl=87600h pki
vault write pki/root/generate/internal \
  common_name="CERES Root CA" \
  ttl=87600h

vault write pki/config/urls \
  issuing_certificates="http://vault:8200/v1/pki/ca" \
  crl_distribution_points="http://vault:8200/v1/pki/crl"

# Create PKI role for services
vault write pki/roles/ceres-services \
  allowed_domains="ceres.local,*.ceres.local" \
  allow_subdomains=true \
  max_ttl=8760h

# Configure PostgreSQL secrets engine
echo "✓ Configuring PostgreSQL secrets engine..."
vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="ceres-apps" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/ceres_db?sslmode=disable" \
  username="postgres" \
  password="${POSTGRES_PASSWORD}"

vault write database/roles/ceres-apps \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Store initial secrets
echo "✓ Storing initial secrets..."
vault kv put ceres/postgres \
  password="${POSTGRES_PASSWORD}" \
  username="postgres" \
  database="ceres_db"

vault kv put ceres/redis \
  password="${REDIS_PASSWORD}"

vault kv put ceres/keycloak \
  admin_password="${KEYCLOAK_ADMIN_PASSWORD}" \
  admin_user="admin"

# Enable audit logging
echo "✓ Enabling audit logging..."
vault audit enable file file_path=/vault/logs/audit.log

# Create policies
echo "✓ Creating policies..."

# Apps policy - read-only access to app secrets
vault policy write ceres-apps - <<EOF
path "ceres/data/*" {
  capabilities = ["read", "list"]
}

path "database/creds/ceres-apps" {
  capabilities = ["read"]
}

path "pki/issue/ceres-services" {
  capabilities = ["create", "update"]
}

path "transit/encrypt/ceres" {
  capabilities = ["update"]
}

path "transit/decrypt/ceres" {
  capabilities = ["update"]
}
EOF

# Monitoring policy - metrics access
vault policy write ceres-monitoring - <<EOF
path "sys/metrics" {
  capabilities = ["read"]
}
EOF

# Create app token
echo "✓ Creating application token..."
APP_TOKEN=$(vault token create \
  -policy=ceres-apps \
  -ttl=720h \
  -format=json | jq -r '.auth.client_token')

echo "$APP_TOKEN" > /vault/keys/app-token.txt

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║        VAULT INITIALIZATION COMPLETE!                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Keys saved to: $KEYS_FILE"
echo "🔑 App token saved to: /vault/keys/app-token.txt"
echo ""
echo "⚠️  CRITICAL: Store unseal keys and root token securely!"
echo ""
echo "Access Vault UI: http://localhost:8200"
echo "Root Token: $ROOT_TOKEN"
echo ""
echo "Next steps:"
echo "  1. Backup $KEYS_FILE to secure location"
echo "  2. Configure apps to use Vault token"
echo "  3. Enable TLS in production"
