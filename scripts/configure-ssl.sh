#!/bin/bash
# CERES SSL/TLS Auto-Configuration
# Automatically configures cert-manager and issues certificates

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔒 CERES SSL/TLS Auto-Configuration"
echo "===================================="
echo ""

# Check if cert-manager is installed
echo "📦 Checking cert-manager..."
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo "Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-webhook -n cert-manager
    kubectl wait --for=condition=available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
    
    echo -e "${GREEN}✅ cert-manager installed${NC}"
else
    echo -e "${GREEN}✅ cert-manager already installed${NC}"
fi

echo ""

# Ask user for certificate type
echo "Select certificate type:"
echo "1) Let's Encrypt (production) - requires public domain"
echo "2) Let's Encrypt (staging) - for testing"
echo "3) Self-signed certificates (local/development)"
echo ""
read -p "Choice [3]: " CERT_TYPE
CERT_TYPE=${CERT_TYPE:-3}

case $CERT_TYPE in
    1)
        echo ""
        read -p "Enter your email for Let's Encrypt: " LE_EMAIL
        read -p "Enter your domain (e.g., ceres.example.com): " DOMAIN
        
        cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${LE_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
        
        ISSUER_NAME="letsencrypt-prod"
        echo -e "${GREEN}✅ Let's Encrypt production issuer created${NC}"
        ;;
        
    2)
        echo ""
        read -p "Enter your email for Let's Encrypt: " LE_EMAIL
        read -p "Enter your domain (e.g., ceres.example.com): " DOMAIN
        
        cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: ${LE_EMAIL}
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
        
        ISSUER_NAME="letsencrypt-staging"
        echo -e "${GREEN}✅ Let's Encrypt staging issuer created${NC}"
        ;;
        
    3|*)
        cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF
        
        ISSUER_NAME="selfsigned-issuer"
        DOMAIN="ceres.local"
        echo -e "${GREEN}✅ Self-signed issuer created${NC}"
        ;;
esac

echo ""
echo "🔐 Creating wildcard certificate..."

# Create wildcard certificate
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ceres-wildcard-cert
  namespace: ceres
spec:
  secretName: ceres-wildcard-tls
  issuerRef:
    name: ${ISSUER_NAME}
    kind: ClusterIssuer
  dnsNames:
  - "*.${DOMAIN}"
  - "${DOMAIN}"
EOF

echo "Waiting for certificate to be issued..."
sleep 5

# Check certificate status
for i in {1..30}; do
    CERT_STATUS=$(kubectl get certificate ceres-wildcard-cert -n ceres -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "Unknown")
    if [ "$CERT_STATUS" == "True" ]; then
        echo -e "${GREEN}✅ Certificate issued successfully${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

echo ""
echo "🔧 Updating Ingress resources with TLS..."

# Update all ingress to use TLS
NAMESPACES=$(kubectl get ingress -A -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u)

for NS in $NAMESPACES; do
    INGRESSES=$(kubectl get ingress -n "$NS" -o jsonpath='{.items[*].metadata.name}')
    for ING in $INGRESSES; do
        echo "  Updating $NS/$ING..."
        
        # Get host from ingress
        HOST=$(kubectl get ingress "$ING" -n "$NS" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
        
        if [ -n "$HOST" ] && [ "$HOST" != "null" ]; then
            kubectl patch ingress "$ING" -n "$NS" --type=merge -p "{
              \"metadata\": {
                \"annotations\": {
                  \"cert-manager.io/cluster-issuer\": \"${ISSUER_NAME}\",
                  \"traefik.ingress.kubernetes.io/router.tls\": \"true\"
                }
              },
              \"spec\": {
                \"tls\": [{
                  \"hosts\": [\"${HOST}\"],
                  \"secretName\": \"${ING}-tls\"
                }]
              }
            }" 2>/dev/null || echo "    Failed to update $ING"
        fi
    done
done

echo -e "${GREEN}✅ Ingress resources updated${NC}"

# Configure Traefik to redirect HTTP to HTTPS
echo ""
echo "🔀 Configuring HTTP to HTTPS redirect..."

cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: default
spec:
  redirectScheme:
    scheme: https
    permanent: true
EOF

echo -e "${GREEN}✅ HTTPS redirect configured${NC}"

# Summary
echo ""
echo "===================================="
echo -e "${GREEN}✅ SSL/TLS Configuration Complete!${NC}"
echo ""
echo "📝 Summary:"
echo "  - Issuer: ${ISSUER_NAME}"
echo "  - Domain: ${DOMAIN}"
echo "  - Certificate: ceres-wildcard-cert"
echo ""
echo "🔗 Access your services via HTTPS:"
if [ "$CERT_TYPE" == "3" ]; then
    echo "  - https://keycloak.${DOMAIN}/ (accept self-signed certificate)"
else
    echo "  - https://keycloak.${DOMAIN}/"
fi
echo ""
echo "⚠️  Note: If using self-signed certificates, browsers will show a warning."
echo "   This is normal for development. For production, use Let's Encrypt."
echo ""
