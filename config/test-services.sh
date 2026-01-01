#!/bin/bash
# Ceres Services Test Suite
# Verifies all 10 services are running and responding correctly
# Usage: bash test-services.sh

set -e

NAMESPACE="ceres"
TIMEOUT=30
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
PASSED=0
FAILED=0

function test_service() {
    local name=$1
    local endpoint=$2
    local port=$3
    local path=${4:="/"}
    
    echo -n "Testing $name... "
    
    # Check if pod is running
    if ! kubectl get pod -n $NAMESPACE -l app=$name 2>/dev/null | grep -q Running; then
        echo -e "${RED}FAIL (pod not running)${NC}"
        ((FAILED++))
        return 1
    fi
    
    # Get pod IP
    pod_ip=$(kubectl get pod -n $NAMESPACE -l app=$name -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
    if [ -z "$pod_ip" ]; then
        echo -e "${RED}FAIL (no pod IP)${NC}"
        ((FAILED++))
        return 1
    fi
    
    # Test HTTP endpoint
    if curl -s -m $TIMEOUT "http://$pod_ip:$port$path" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL (no response)${NC}"
        ((FAILED++))
        return 1
    fi
}

function test_port() {
    local name=$1
    local port=$2
    
    echo -n "Testing $name on port $port... "
    
    # Get first pod
    pod_name=$(kubectl get pod -n $NAMESPACE -l app=$name -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -z "$pod_name" ]; then
        echo -e "${RED}FAIL (no pod)${NC}"
        ((FAILED++))
        return 1
    fi
    
    # Check port is listening
    if kubectl exec -it $pod_name -n $NAMESPACE -- netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL (port not listening)${NC}"
        ((FAILED++))
        return 1
    fi
}

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║   Ceres Services Test Suite                ║"
echo "║   Testing all 10 services                  ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# SECTION 1: Check cluster is operational
echo -e "${YELLOW}SECTION 1: Cluster Status${NC}"
echo "─" * 44

# Check nodes
nodes=$(kubectl get nodes 2>/dev/null | grep -c "Ready " || echo "0")
echo "Nodes ready: $nodes / 3"

# Check pods
pods=$(kubectl get pods -n $NAMESPACE 2>/dev/null | grep -c "Running " || echo "0")
echo "Pods running: $pods / 10"
echo ""

# SECTION 2: Check Kubernetes core services
echo -e "${YELLOW}SECTION 2: Kubernetes Core Services${NC}"
echo "─" * 44

# Check API server
echo -n "Testing API server... "
if kubectl cluster-info 2>/dev/null | grep -q "running"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

# Check DNS
echo -n "Testing DNS (coredns)... "
if kubectl get pods -n kube-system | grep -q "coredns.*Running"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

echo ""

# SECTION 3: Test core services
echo -e "${YELLOW}SECTION 3: Database Services${NC}"
echo "─" * 44

test_port "postgresql" "5432"
test_port "redis" "6379"

echo ""

# SECTION 4: Test authentication
echo -e "${YELLOW}SECTION 4: Authentication Service${NC}"
echo "─" * 44

test_service "keycloak" "localhost" "8080" "/health"

echo ""

# SECTION 5: Test document management
echo -e "${YELLOW}SECTION 5: Document Management Service${NC}"
echo "─" * 44

test_service "nextcloud" "localhost" "80" "/status.php"

echo ""

# SECTION 6: Test version control
echo -e "${YELLOW}SECTION 6: Version Control Service${NC}"
echo "─" * 44

test_service "gitea" "localhost" "3000" "/api/v1/version"

echo ""

# SECTION 7: Test messaging
echo -e "${YELLOW}SECTION 7: Messaging Service${NC}"
echo "─" * 44

test_service "mattermost" "localhost" "8065" "/api/v4/system/ping"

echo ""

# SECTION 8: Test monitoring
echo -e "${YELLOW}SECTION 8: Monitoring Services${NC}"
echo "─" * 44

test_service "prometheus" "localhost" "9090" "/-/healthy"
test_service "grafana" "localhost" "3000" "/api/health"

echo ""

# SECTION 9: Test management
echo -e "${YELLOW}SECTION 9: Management Services${NC}"
echo "─" * 44

test_service "portainer" "localhost" "9000" "/api/system"

echo ""

# SECTION 10: Test ingress
echo -e "${YELLOW}SECTION 10: Ingress Controller${NC}"
echo "─" * 44

echo -n "Testing Nginx Ingress... "
if kubectl get pod -n ingress-nginx 2>/dev/null | grep -q "Running"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

echo ""

# SECTION 11: Advanced tests
echo -e "${YELLOW}SECTION 11: Advanced Service Tests${NC}"
echo "─" * 44

# PostgreSQL connectivity test
echo -n "PostgreSQL connectivity... "
if kubectl exec -it postgresql-0 -n $NAMESPACE -- \
    psql -U postgres -d ceres -c "SELECT 1" 2>/dev/null | grep -q "1 row"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

# Redis connectivity test
echo -n "Redis connectivity... "
if kubectl exec -it redis-0 -n $NAMESPACE -- \
    redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

# Check persistent volumes
echo -n "Persistent volumes... "
pvc_count=$(kubectl get pvc -n $NAMESPACE 2>/dev/null | grep -c "Bound " || echo "0")
if [ $pvc_count -ge 5 ]; then
    echo -e "${GREEN}PASS ($pvc_count bound)${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL (only $pvc_count bound)${NC}"
    ((FAILED++))
fi

# Check resource usage
echo -n "Resource allocation... "
resources=$(kubectl describe nodes 2>/dev/null | grep -c "cpu" || echo "0")
if [ $resources -gt 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAILED++))
fi

echo ""

# FINAL SUMMARY
echo "╔════════════════════════════════════════════╗"
echo "║   Test Summary                             ║"
echo "╚════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
total=$((PASSED + FAILED))
echo "Total:  $total"
echo ""

success_rate=$((PASSED * 100 / total))
echo "Success rate: $success_rate%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests PASSED!${NC}"
    echo ""
    echo "Cluster is healthy and ready for use."
    exit 0
else
    echo -e "${RED}Some tests FAILED.${NC}"
    echo ""
    echo "Debugging steps:"
    echo "1. Check pod logs: kubectl logs pod-name -n ceres"
    echo "2. Describe pod: kubectl describe pod pod-name -n ceres"
    echo "3. Check events: kubectl get events -n ceres"
    echo "4. Check resources: kubectl top pods -n ceres"
    exit 1
fi
