#!/bin/bash
# Generate mTLS certificates for all CERES services using Vault PKI

set -e

VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:?Set VAULT_TOKEN environment variable}"
CERTS_DIR="${1:-./certs}"

echo "🔐 Generating mTLS certificates for CERES services"
echo "=================================================="
echo "Vault: $VAULT_ADDR"
echo "Output: $CERTS_DIR"
echo ""

# Create certificates directory
mkdir -p "$CERTS_DIR"

# Login to Vault
export VAULT_ADDR
export VAULT_TOKEN

# Services that need certificates
SERVICES=(
    "postgres.ceres.local"
    "redis.ceres.local"
    "keycloak.ceres.local"
    "nextcloud.ceres.local"
    "gitea.ceres.local"
    "mattermost.ceres.local"
    "redmine.ceres.local"
    "wikijs.ceres.local"
    "grafana.ceres.local"
    "prometheus.ceres.local"
    "loki.ceres.local"
    "caddy.ceres.local"
    "portainer.ceres.local"
)

# Generate certificates for each service
for service in "${SERVICES[@]}"; do
    echo "✓ Generating certificate for $service..."
    
    service_name=$(echo "$service" | cut -d'.' -f1)
    
    # Request certificate from Vault PKI
    vault write -format=json pki/issue/ceres-services \
        common_name="$service" \
        ttl="8760h" \
        alt_names="$service_name,localhost" \
        ip_sans="127.0.0.1" > "$CERTS_DIR/${service_name}.json"
    
    # Extract certificate, key, and CA
    cat "$CERTS_DIR/${service_name}.json" | jq -r '.data.certificate' > "$CERTS_DIR/${service_name}.crt"
    cat "$CERTS_DIR/${service_name}.json" | jq -r '.data.private_key' > "$CERTS_DIR/${service_name}.key"
    cat "$CERTS_DIR/${service_name}.json" | jq -r '.data.issuing_ca' > "$CERTS_DIR/${service_name}-ca.crt"
    
    # Set proper permissions
    chmod 644 "$CERTS_DIR/${service_name}.crt"
    chmod 600 "$CERTS_DIR/${service_name}.key"
    chmod 644 "$CERTS_DIR/${service_name}-ca.crt"
    
    # Create combined cert+ca file for some services
    cat "$CERTS_DIR/${service_name}.crt" "$CERTS_DIR/${service_name}-ca.crt" > "$CERTS_DIR/${service_name}-bundle.crt"
    
    # Clean up JSON
    rm "$CERTS_DIR/${service_name}.json"
    
    echo "  ✓ Certificate: $CERTS_DIR/${service_name}.crt"
    echo "  ✓ Key: $CERTS_DIR/${service_name}.key"
    echo "  ✓ CA: $CERTS_DIR/${service_name}-ca.crt"
done

# Get root CA certificate
echo ""
echo "✓ Fetching Root CA certificate..."
vault read -field=certificate pki/cert/ca > "$CERTS_DIR/root-ca.crt"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     mTLS CERTIFICATES GENERATED SUCCESSFULLY!              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Certificates saved to: $CERTS_DIR"
echo ""
echo "Next steps:"
echo "  1. Update docker-compose files to mount certificates"
echo "  2. Configure services to use mTLS"
echo "  3. Restart services"
echo ""
echo "Example for PostgreSQL:"
echo "  volumes:"
echo "    - $CERTS_DIR/postgres.crt:/var/lib/postgresql/server.crt:ro"
echo "    - $CERTS_DIR/postgres.key:/var/lib/postgresql/server.key:ro"
echo "    - $CERTS_DIR/root-ca.crt:/var/lib/postgresql/root.crt:ro"
