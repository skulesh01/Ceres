#!/bin/bash
# CERES Health Check Script
# Validates all services are running correctly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🏥 CERES Platform Health Check"
echo "==============================="
echo ""

TOTAL=0
HEALTHY=0
UNHEALTHY=0

# Get Traefik LoadBalancer IP
TRAEFIK_IP=$(kubectl get svc traefik -n kube-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [ -z "$TRAEFIK_IP" ]; then
    echo -e "${RED}❌ Cannot get Traefik LoadBalancer IP${NC}"
    exit 1
fi

echo -e "${BLUE}📍 Traefik IP: ${TRAEFIK_IP}${NC}"
echo ""

# Function to check HTTP endpoint
check_http() {
    local name=$1
    local host=$2
    local expected_code=${3:-200}
    
    TOTAL=$((TOTAL + 1))
    
    if [ "$host" == "*" ]; then
        # Direct IP access
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "http://${TRAEFIK_IP}/" 2>/dev/null || echo "000")
    else
        # Domain-based access
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -H "Host: ${host}" "http://${TRAEFIK_IP}/" 2>/dev/null || echo "000")
    fi
    
    if [ "$HTTP_CODE" == "$expected_code" ] || [ "$HTTP_CODE" == "301" ] || [ "$HTTP_CODE" == "302" ]; then
        echo -e "${GREEN}✅ ${name}: OK (${HTTP_CODE})${NC}"
        HEALTHY=$((HEALTHY + 1))
    elif [ "$HTTP_CODE" == "000" ]; then
        echo -e "${RED}❌ ${name}: TIMEOUT${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
    else
        echo -e "${YELLOW}⚠️  ${name}: ${HTTP_CODE}${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
    fi
}

# Function to check pod status
check_pod() {
    local namespace=$1
    local label=$2
    local name=$3
    
    TOTAL=$((TOTAL + 1))
    
    POD_STATUS=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$POD_STATUS" == "Running" ]; then
        READY=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
        if [ "$READY" == "true" ]; then
            echo -e "${GREEN}✅ ${name} pod: Running${NC}"
            HEALTHY=$((HEALTHY + 1))
        else
            echo -e "${YELLOW}⚠️  ${name} pod: Running but not ready${NC}"
            UNHEALTHY=$((UNHEALTHY + 1))
        fi
    elif [ "$POD_STATUS" == "NotFound" ]; then
        echo -e "${RED}❌ ${name} pod: Not found${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
    else
        echo -e "${RED}❌ ${name} pod: ${POD_STATUS}${NC}"
        UNHEALTHY=$((UNHEALTHY + 1))
    fi
}

echo "🔍 Checking Pods..."
echo "-------------------"
check_pod "ceres" "app=keycloak" "Keycloak"
check_pod "gitlab" "app=gitlab" "GitLab"
check_pod "monitoring" "app.kubernetes.io/name=grafana" "Grafana"
check_pod "monitoring" "app.kubernetes.io/name=prometheus" "Prometheus"
check_pod "mattermost" "app=mattermost" "Mattermost"
check_pod "nextcloud" "app=nextcloud" "Nextcloud"
check_pod "wiki" "app=wikijs" "Wiki.js"
check_pod "portainer" "app.kubernetes.io/name=portainer" "Portainer"
check_pod "minio" "app=minio" "MinIO"
check_pod "vault" "app.kubernetes.io/name=vault" "Vault"

echo ""
echo "🌐 Checking HTTP Endpoints..."
echo "------------------------------"
check_http "Keycloak (IP)" "*" 200
check_http "Keycloak" "keycloak.ceres.local" 200
check_http "GitLab" "gitlab.ceres.local" 200
check_http "Grafana" "grafana.ceres.local" 200
check_http "Prometheus" "prometheus.ceres.local" 200
check_http "Mattermost" "chat.ceres.local" 200
check_http "Nextcloud" "files.ceres.local" 200
check_http "Wiki.js" "wiki.ceres.local" 200
check_http "Portainer" "portainer.ceres.local" 200
check_http "MinIO" "minio.ceres.local" 200
check_http "Vault" "vault.ceres.local" 200

echo ""
echo "🔧 Checking Infrastructure..."
echo "------------------------------"

# Check Traefik
TRAEFIK_STATUS=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$TRAEFIK_STATUS" == "Running" ]; then
    echo -e "${GREEN}✅ Traefik Ingress: Running${NC}"
else
    echo -e "${RED}❌ Traefik Ingress: ${TRAEFIK_STATUS}${NC}"
fi

# Check CoreDNS
COREDNS_STATUS=$(kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$COREDNS_STATUS" == "Running" ]; then
    echo -e "${GREEN}✅ CoreDNS: Running${NC}"
else
    echo -e "${YELLOW}⚠️  CoreDNS: ${COREDNS_STATUS}${NC}"
fi

# Check Metrics Server
METRICS_STATUS=$(kubectl get pods -n kube-system -l k8s-app=metrics-server -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [ "$METRICS_STATUS" == "Running" ]; then
    echo -e "${GREEN}✅ Metrics Server: Running${NC}"
elif [ "$METRICS_STATUS" == "NotFound" ]; then
    echo -e "${YELLOW}⚠️  Metrics Server: Not installed${NC}"
else
    echo -e "${YELLOW}⚠️  Metrics Server: ${METRICS_STATUS}${NC}"
fi

echo ""
echo "📊 Summary"
echo "=========="
echo -e "Total checks: ${TOTAL}"
echo -e "${GREEN}Healthy: ${HEALTHY}${NC}"
echo -e "${RED}Unhealthy: ${UNHEALTHY}${NC}"

HEALTH_PERCENTAGE=$((HEALTHY * 100 / TOTAL))
echo -e "Health: ${HEALTH_PERCENTAGE}%"

echo ""
if [ $HEALTH_PERCENTAGE -ge 90 ]; then
    echo -e "${GREEN}✅ System is HEALTHY${NC}"
    exit 0
elif [ $HEALTH_PERCENTAGE -ge 70 ]; then
    echo -e "${YELLOW}⚠️  System has some issues${NC}"
    exit 1
else
    echo -e "${RED}❌ System is UNHEALTHY${NC}"
    exit 2
fi
