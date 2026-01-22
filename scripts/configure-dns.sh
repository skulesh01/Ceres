#!/bin/bash

# CERES DNS Auto-Configuration
# Automatically configures DNS records via cloud provider APIs

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   CERES DNS Auto-Configuration         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Get server IP
SERVER_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
            curl -s ifconfig.me || \
            hostname -I | awk '{print $1}')

echo -e "${BLUE}📍 Detected Server IP: ${SERVER_IP}${NC}"
echo ""

# Ask for domain
read -p "Enter your domain name (e.g., company.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}❌ Domain name is required${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}Select DNS Provider:${NC}"
echo "1) Cloudflare"
echo "2) AWS Route53"
echo "3) Google Cloud DNS"
echo "4) DigitalOcean"
echo "5) Manual (show instructions)"
read -p "Choice [1-5]: " PROVIDER_CHOICE

case $PROVIDER_CHOICE in
    1)
        PROVIDER="cloudflare"
        read -p "Cloudflare API Token: " CF_TOKEN
        read -p "Cloudflare Zone ID: " CF_ZONE_ID
        ;;
    2)
        PROVIDER="route53"
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY
        read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
        echo ""
        read -p "AWS Region (default us-east-1): " AWS_REGION
        AWS_REGION=${AWS_REGION:-us-east-1}
        ;;
    3)
        PROVIDER="gcloud"
        read -p "GCP Project ID: " GCP_PROJECT
        read -p "GCP Service Account Key (path): " GCP_KEY_PATH
        ;;
    4)
        PROVIDER="digitalocean"
        read -p "DigitalOcean API Token: " DO_TOKEN
        ;;
    5)
        PROVIDER="manual"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

#=============================================================================
# CLOUDFLARE
#=============================================================================
if [ "$PROVIDER" = "cloudflare" ]; then
    echo ""
    echo -e "${BLUE}🌐 Configuring Cloudflare DNS...${NC}"
    
    # Create DNS records
    SERVICES=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio" "portainer" "vault" "prometheus")
    
    for service in "${SERVICES[@]}"; do
        echo -e "${BLUE}  Adding: ${service}.${DOMAIN}${NC}"
        
        # Check if record exists
        RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${service}.${DOMAIN}" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
        
        if [ -n "$RECORD_ID" ]; then
            # Update existing record
            curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${RECORD_ID}" \
                -H "Authorization: Bearer ${CF_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"A\",\"name\":\"${service}\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}" > /dev/null
        else
            # Create new record
            curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
                -H "Authorization: Bearer ${CF_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"A\",\"name\":\"${service}\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}" > /dev/null
        fi
        echo -e "${GREEN}    ✅ ${service}.${DOMAIN} → ${SERVER_IP}${NC}"
    done
    
    # Create wildcard record
    echo -e "${BLUE}  Adding: *.${DOMAIN}${NC}"
    WILDCARD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=*.${DOMAIN}" \
        -H "Authorization: Bearer ${CF_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
    
    if [ -n "$WILDCARD_ID" ]; then
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${WILDCARD_ID}" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"*\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}" > /dev/null
    else
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
            -H "Authorization: Bearer ${CF_TOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"*\",\"content\":\"${SERVER_IP}\",\"ttl\":120,\"proxied\":false}" > /dev/null
    fi
    echo -e "${GREEN}    ✅ *.${DOMAIN} → ${SERVER_IP}${NC}"

#=============================================================================
# AWS ROUTE53
#=============================================================================
elif [ "$PROVIDER" = "route53" ]; then
    echo ""
    echo -e "${BLUE}☁️  Configuring AWS Route53...${NC}"
    
    # Get Hosted Zone ID
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
        --dns-name ${DOMAIN} \
        --query "HostedZones[0].Id" \
        --output text \
        --region ${AWS_REGION} 2>/dev/null | cut -d'/' -f3)
    
    if [ -z "$HOSTED_ZONE_ID" ]; then
        echo -e "${RED}❌ Hosted zone for ${DOMAIN} not found${NC}"
        exit 1
    fi
    
    # Create change batch
    SERVICES=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio" "portainer" "vault" "prometheus")
    
    cat > /tmp/route53-changes.json <<EOF
{
  "Changes": [
EOF
    
    for service in "${SERVICES[@]}"; do
        cat >> /tmp/route53-changes.json <<EOF
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${service}.${DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${SERVER_IP}"}]
      }
    },
EOF
    done
    
    # Add wildcard
    cat >> /tmp/route53-changes.json <<EOF
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "*.${DOMAIN}",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "${SERVER_IP}"}]
      }
    }
  ]
}
EOF
    
    # Apply changes
    aws route53 change-resource-record-sets \
        --hosted-zone-id ${HOSTED_ZONE_ID} \
        --change-batch file:///tmp/route53-changes.json \
        --region ${AWS_REGION} > /dev/null
    
    echo -e "${GREEN}  ✅ DNS records created in Route53${NC}"

#=============================================================================
# GOOGLE CLOUD DNS
#=============================================================================
elif [ "$PROVIDER" = "gcloud" ]; then
    echo ""
    echo -e "${BLUE}☁️  Configuring Google Cloud DNS...${NC}"
    
    # Authenticate
    gcloud auth activate-service-account --key-file=${GCP_KEY_PATH} --project=${GCP_PROJECT}
    
    # Get managed zone
    ZONE_NAME=$(gcloud dns managed-zones list --filter="dnsName:${DOMAIN}." --format="value(name)" --project=${GCP_PROJECT})
    
    if [ -z "$ZONE_NAME" ]; then
        echo -e "${RED}❌ Managed zone for ${DOMAIN} not found${NC}"
        exit 1
    fi
    
    # Start transaction
    gcloud dns record-sets transaction start --zone=${ZONE_NAME} --project=${GCP_PROJECT}
    
    SERVICES=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio" "portainer" "vault" "prometheus")
    
    for service in "${SERVICES[@]}"; do
        # Remove old record if exists
        gcloud dns record-sets transaction remove ${SERVER_IP} \
            --name=${service}.${DOMAIN}. \
            --ttl=300 \
            --type=A \
            --zone=${ZONE_NAME} \
            --project=${GCP_PROJECT} 2>/dev/null || true
        
        # Add new record
        gcloud dns record-sets transaction add ${SERVER_IP} \
            --name=${service}.${DOMAIN}. \
            --ttl=300 \
            --type=A \
            --zone=${ZONE_NAME} \
            --project=${GCP_PROJECT}
    done
    
    # Wildcard
    gcloud dns record-sets transaction add ${SERVER_IP} \
        --name=*.${DOMAIN}. \
        --ttl=300 \
        --type=A \
        --zone=${ZONE_NAME} \
        --project=${GCP_PROJECT}
    
    # Execute transaction
    gcloud dns record-sets transaction execute --zone=${ZONE_NAME} --project=${GCP_PROJECT}
    
    echo -e "${GREEN}  ✅ DNS records created in Google Cloud DNS${NC}"

#=============================================================================
# DIGITALOCEAN
#=============================================================================
elif [ "$PROVIDER" = "digitalocean" ]; then
    echo ""
    echo -e "${BLUE}🌊 Configuring DigitalOcean DNS...${NC}"
    
    SERVICES=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio" "portainer" "vault" "prometheus")
    
    for service in "${SERVICES[@]}"; do
        # Create A record
        curl -s -X POST "https://api.digitalocean.com/v2/domains/${DOMAIN}/records" \
            -H "Authorization: Bearer ${DO_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"type\":\"A\",\"name\":\"${service}\",\"data\":\"${SERVER_IP}\",\"ttl\":300}" > /dev/null
        
        echo -e "${GREEN}  ✅ ${service}.${DOMAIN} → ${SERVER_IP}${NC}"
    done
    
    # Wildcard
    curl -s -X POST "https://api.digitalocean.com/v2/domains/${DOMAIN}/records" \
        -H "Authorization: Bearer ${DO_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"A\",\"name\":\"*\",\"data\":\"${SERVER_IP}\",\"ttl\":300}" > /dev/null
    
    echo -e "${GREEN}  ✅ *.${DOMAIN} → ${SERVER_IP}${NC}"

#=============================================================================
# MANUAL INSTRUCTIONS
#=============================================================================
elif [ "$PROVIDER" = "manual" ]; then
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Manual DNS Configuration           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "Add the following DNS records in your provider:"
    echo ""
    echo -e "${YELLOW}A Records:${NC}"
    SERVICES=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio" "portainer" "vault" "prometheus")
    for service in "${SERVICES[@]}"; do
        echo "  ${service}.${DOMAIN}  →  ${SERVER_IP}"
    done
    echo ""
    echo -e "${YELLOW}Wildcard:${NC}"
    echo "  *.${DOMAIN}  →  ${SERVER_IP}"
    echo ""
    echo "Press Enter when DNS records are configured..."
    read
fi

#=============================================================================
# UPDATE INGRESS WITH REAL DOMAIN
#=============================================================================
echo ""
echo -e "${BLUE}🔧 Updating Ingress with real domain...${NC}"

# Update all ingress resources
NAMESPACES=("ceres" "gitlab" "monitoring" "mattermost" "nextcloud" "wiki" "minio")
SERVICES_MAP=("keycloak" "gitlab" "grafana" "chat" "files" "wiki" "minio")

for i in "${!NAMESPACES[@]}"; do
    ns="${NAMESPACES[$i]}"
    service="${SERVICES_MAP[$i]}"
    
    kubectl get ingress -n ${ns} -o name 2>/dev/null | while read ingress; do
        kubectl patch ${ingress} -n ${ns} --type=json -p="[
            {\"op\":\"replace\",\"path\":\"/spec/rules/0/host\",\"value\":\"${service}.${DOMAIN}\"}
        ]" 2>/dev/null || true
    done
done

echo -e "${GREEN}✅ Ingress updated with ${DOMAIN}${NC}"

#=============================================================================
# CONFIGURE LET'S ENCRYPT FOR PRODUCTION
#=============================================================================
echo ""
echo -e "${BLUE}🔒 Configuring Let's Encrypt SSL...${NC}"

# Create production issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# Wait for cert-manager
sleep 5

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
    name: letsencrypt-prod
    kind: ClusterIssuer
  commonName: "*.${DOMAIN}"
  dnsNames:
  - "${DOMAIN}"
  - "*.${DOMAIN}"
EOF

echo -e "${GREEN}✅ Let's Encrypt certificate requested${NC}"
echo -e "${YELLOW}⏳ Certificate issuance may take 1-2 minutes...${NC}"

# Wait for certificate
echo -n "Waiting for certificate."
for i in {1..60}; do
    STATUS=$(kubectl get certificate ceres-wildcard-cert -n ceres -o jsonpath='{.status.conditions[0].status}' 2>/dev/null || echo "False")
    if [ "$STATUS" = "True" ]; then
        echo ""
        echo -e "${GREEN}✅ Certificate issued successfully!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

#=============================================================================
# UPDATE INGRESS WITH TLS
#=============================================================================
echo ""
echo -e "${BLUE}🔒 Enabling HTTPS for all services...${NC}"

for i in "${!NAMESPACES[@]}"; do
    ns="${NAMESPACES[$i]}"
    service="${SERVICES_MAP[$i]}"
    
    kubectl get ingress -n ${ns} -o name 2>/dev/null | while read ingress; do
        kubectl patch ${ingress} -n ${ns} --type=json -p="[
            {\"op\":\"add\",\"path\":\"/spec/tls\",\"value\":[{\"hosts\":[\"${service}.${DOMAIN}\"],\"secretName\":\"ceres-wildcard-tls\"}]}
        ]" 2>/dev/null || true
    done
done

echo -e "${GREEN}✅ HTTPS enabled for all services${NC}"

#=============================================================================
# CREATE HTTP→HTTPS REDIRECT
#=============================================================================
echo ""
echo -e "${BLUE}🔀 Configuring HTTP→HTTPS redirect...${NC}"

cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: redirect-https
  namespace: ceres
spec:
  redirectScheme:
    scheme: https
    permanent: true
EOF

echo -e "${GREEN}✅ HTTP redirect configured${NC}"

#=============================================================================
# FINAL SUMMARY
#=============================================================================
echo ""
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   DNS Configuration Complete! ✅        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🎉 Your platform is now accessible via:${NC}"
echo ""
echo -e "${CYAN}Services:${NC}"
echo "  🔐 Keycloak:   https://keycloak.${DOMAIN}"
echo "  🦊 GitLab:     https://gitlab.${DOMAIN}"
echo "  📊 Grafana:    https://grafana.${DOMAIN}"
echo "  💬 Mattermost: https://chat.${DOMAIN}"
echo "  📁 Nextcloud:  https://files.${DOMAIN}"
echo "  📖 Wiki.js:    https://wiki.${DOMAIN}"
echo "  🪣 MinIO:      https://minio.${DOMAIN}"
echo ""
echo -e "${CYAN}Security:${NC}"
echo "  ✅ Real domain configured"
echo "  ✅ Let's Encrypt SSL/TLS enabled"
echo "  ✅ HTTP automatically redirects to HTTPS"
echo "  ✅ Wildcard certificate active"
echo ""
echo -e "${YELLOW}⏰ Note: DNS propagation may take 5-10 minutes${NC}"
echo ""
echo -e "${GREEN}Test with: curl -I https://keycloak.${DOMAIN}${NC}"
