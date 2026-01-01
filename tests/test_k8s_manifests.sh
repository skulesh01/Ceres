#!/bin/bash
#
# CERES v3.0.0 - Kubernetes Manifest Validation Tests
# Tests for Istio, security policies, and configuration manifests
#

set -e

MANIFEST_DIR="config"
TEST_DIR="tests"
RESULTS_FILE="${TEST_DIR}/k8s-manifest-test-results.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize test results
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_test() {
    local test_name=$1
    local status=$2
    local message=$3
    
    echo -e "${status}[$(date +'%H:%M:%S')] ${test_name}: ${message}${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == *"PASS"* ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS["$test_name"]="PASS"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS["$test_name"]="FAIL: $message"
    fi
}

# Test 1: Istio manifests exist
test_istio_manifests() {
    echo -e "\n${YELLOW}Test 1: Istio Configuration Manifests${NC}"
    
    if [[ -f "$MANIFEST_DIR/istio/istio-install.yml" ]]; then
        log_test "istio_manifest_exists" "${GREEN}✓ PASS${NC}" "Istio manifest found"
    else
        log_test "istio_manifest_exists" "${RED}✗ FAIL${NC}" "Istio manifest missing"
        return 1
    fi
}

# Test 2: Validate YAML syntax
test_yaml_syntax() {
    echo -e "\n${YELLOW}Test 2: YAML Syntax Validation${NC}"
    
    local yaml_files=$(find "$MANIFEST_DIR" -name "*.yml" -o -name "*.yaml")
    
    for file in $yaml_files; do
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            log_test "yaml_syntax_${file##*/}" "${GREEN}✓ PASS${NC}" "$file valid"
        else
            log_test "yaml_syntax_${file##*/}" "${RED}✗ FAIL${NC}" "$file invalid YAML"
            return 1
        fi
    done
}

# Test 3: Check required Kubernetes API versions
test_api_versions() {
    echo -e "\n${YELLOW}Test 3: Kubernetes API Versions${NC}"
    
    # Check for v1 API
    if grep -q "apiVersion: v1" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "api_version_v1" "${GREEN}✓ PASS${NC}" "v1 API version found"
    else
        log_test "api_version_v1" "${YELLOW}⚠ WARN${NC}" "v1 API version not used"
    fi
    
    # Check for apps/v1
    if grep -q "apiVersion: apps/v1" "$MANIFEST_DIR"/*/*.yml 2>/dev/null; then
        log_test "api_version_apps_v1" "${GREEN}✓ PASS${NC}" "apps/v1 API version found"
    else
        log_test "api_version_apps_v1" "${YELLOW}⚠ WARN${NC}" "apps/v1 API version not used"
    fi
}

# Test 4: Istio-specific resources
test_istio_resources() {
    echo -e "\n${YELLOW}Test 4: Istio Resources Configuration${NC}"
    
    # Check for IstioOperator
    if grep -q "kind: IstioOperator" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "istio_operator" "${GREEN}✓ PASS${NC}" "IstioOperator defined"
    else
        log_test "istio_operator" "${RED}✗ FAIL${NC}" "IstioOperator missing"
        return 1
    fi
    
    # Check for VirtualService
    if grep -q "kind: VirtualService" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "virtual_service" "${GREEN}✓ PASS${NC}" "VirtualService defined"
    else
        log_test "virtual_service" "${YELLOW}⚠ WARN${NC}" "VirtualService not found"
    fi
    
    # Check for DestinationRule
    if grep -q "kind: DestinationRule" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "destination_rule" "${GREEN}✓ PASS${NC}" "DestinationRule defined"
    else
        log_test "destination_rule" "${YELLOW}⚠ WARN${NC}" "DestinationRule not found"
    fi
    
    # Check for AuthorizationPolicy
    if grep -q "kind: AuthorizationPolicy" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "authorization_policy" "${GREEN}✓ PASS${NC}" "AuthorizationPolicy defined"
    else
        log_test "authorization_policy" "${RED}✗ FAIL${NC}" "AuthorizationPolicy missing"
        return 1
    fi
    
    # Check for RequestAuthentication
    if grep -q "kind: RequestAuthentication" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "request_authentication" "${GREEN}✓ PASS${NC}" "RequestAuthentication defined"
    else
        log_test "request_authentication" "${RED}✗ FAIL${NC}" "RequestAuthentication missing"
        return 1
    fi
}

# Test 5: Security policies
test_security_policies() {
    echo -e "\n${YELLOW}Test 5: Security Policies${NC}"
    
    if [[ ! -f "$MANIFEST_DIR/security/hardening-policies.yml" ]]; then
        log_test "security_manifest" "${RED}✗ FAIL${NC}" "Security manifest missing"
        return 1
    fi
    
    # Check for PodSecurityPolicy
    if grep -q "kind: PodSecurityPolicy" "$MANIFEST_DIR/security/hardening-policies.yml"; then
        log_test "pod_security_policy" "${GREEN}✓ PASS${NC}" "PodSecurityPolicy defined"
    else
        log_test "pod_security_policy" "${RED}✗ FAIL${NC}" "PodSecurityPolicy missing"
        return 1
    fi
    
    # Check for NetworkPolicy
    if grep -q "kind: NetworkPolicy" "$MANIFEST_DIR/security/hardening-policies.yml"; then
        log_test "network_policy" "${GREEN}✓ PASS${NC}" "NetworkPolicy defined"
    else
        log_test "network_policy" "${RED}✗ FAIL${NC}" "NetworkPolicy missing"
        return 1
    fi
    
    # Check for RBAC Role
    if grep -q "kind: Role" "$MANIFEST_DIR/security/hardening-policies.yml"; then
        log_test "rbac_role" "${GREEN}✓ PASS${NC}" "RBAC Role defined"
    else
        log_test "rbac_role" "${RED}✗ FAIL${NC}" "RBAC Role missing"
        return 1
    fi
    
    # Check for RBAC RoleBinding
    if grep -q "kind: RoleBinding" "$MANIFEST_DIR/security/hardening-policies.yml"; then
        log_test "rbac_rolebinding" "${GREEN}✓ PASS${NC}" "RBAC RoleBinding defined"
    else
        log_test "rbac_rolebinding" "${RED}✗ FAIL${NC}" "RBAC RoleBinding missing"
        return 1
    fi
}

# Test 6: Resource limits and requests
test_resource_limits() {
    echo -e "\n${YELLOW}Test 6: Resource Limits and Requests${NC}"
    
    # Check for resource requests in Istio config
    if grep -q "requests:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "resource_requests" "${GREEN}✓ PASS${NC}" "Resource requests defined"
    else
        log_test "resource_requests" "${YELLOW}⚠ WARN${NC}" "Resource requests not found"
    fi
    
    # Check for limits
    if grep -q "limits:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "resource_limits" "${GREEN}✓ PASS${NC}" "Resource limits defined"
    else
        log_test "resource_limits" "${YELLOW}⚠ WARN${NC}" "Resource limits not found"
    fi
}

# Test 7: Namespace configuration
test_namespaces() {
    echo -e "\n${YELLOW}Test 7: Namespace Configuration${NC}"
    
    # Check for istio-system namespace
    if grep -q "namespace: istio-system\|name: istio-system" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "istio_namespace" "${GREEN}✓ PASS${NC}" "istio-system namespace configured"
    else
        log_test "istio_namespace" "${RED}✗ FAIL${NC}" "istio-system namespace missing"
        return 1
    fi
}

# Test 8: Health checks
test_health_checks() {
    echo -e "\n${YELLOW}Test 8: Health Check Configuration${NC}"
    
    # Check for liveness probes
    if grep -q "livenessProbe\|liveness:" "$MANIFEST_DIR"/*/*.yml 2>/dev/null; then
        log_test "liveness_probes" "${GREEN}✓ PASS${NC}" "Liveness probes configured"
    else
        log_test "liveness_probes" "${YELLOW}⚠ WARN${NC}" "Liveness probes not found"
    fi
    
    # Check for readiness probes
    if grep -q "readinessProbe\|readiness:" "$MANIFEST_DIR"/*/*.yml 2>/dev/null; then
        log_test "readiness_probes" "${GREEN}✓ PASS${NC}" "Readiness probes configured"
    else
        log_test "readiness_probes" "${YELLOW}⚠ WARN${NC}" "Readiness probes not found"
    fi
}

# Test 9: Labels and annotations
test_labels_annotations() {
    echo -e "\n${YELLOW}Test 9: Labels and Annotations${NC}"
    
    # Check for labels
    if grep -q "labels:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "labels" "${GREEN}✓ PASS${NC}" "Labels defined"
    else
        log_test "labels" "${YELLOW}⚠ WARN${NC}" "Labels not found"
    fi
    
    # Check for annotations
    if grep -q "annotations:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "annotations" "${GREEN}✓ PASS${NC}" "Annotations defined"
    else
        log_test "annotations" "${YELLOW}⚠ WARN${NC}" "Annotations not found"
    fi
}

# Test 10: Image pull policy
test_image_pull_policy() {
    echo -e "\n${YELLOW}Test 10: Image Pull Policy${NC}"
    
    # Check for imagePullPolicy
    if grep -q "imagePullPolicy:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "image_pull_policy" "${GREEN}✓ PASS${NC}" "Image pull policy configured"
        
        # Verify it's set to Always or IfNotPresent
        if grep -q 'imagePullPolicy: Always\|imagePullPolicy: IfNotPresent' "$MANIFEST_DIR/istio/istio-install.yml"; then
            log_test "image_pull_policy_value" "${GREEN}✓ PASS${NC}" "Image pull policy has valid value"
        else
            log_test "image_pull_policy_value" "${YELLOW}⚠ WARN${NC}" "Image pull policy has unusual value"
        fi
    else
        log_test "image_pull_policy" "${YELLOW}⚠ WARN${NC}" "Image pull policy not explicitly set"
    fi
}

# Test 11: Service accounts
test_service_accounts() {
    echo -e "\n${YELLOW}Test 11: Service Accounts${NC}"
    
    # Check for ServiceAccount
    if grep -q "kind: ServiceAccount" "$MANIFEST_DIR"/*/*.yml 2>/dev/null; then
        log_test "service_accounts" "${GREEN}✓ PASS${NC}" "ServiceAccount defined"
    else
        log_test "service_accounts" "${YELLOW}⚠ WARN${NC}" "ServiceAccount not found"
    fi
}

# Test 12: Replicas and scaling
test_replicas() {
    echo -e "\n${YELLOW}Test 12: Replicas Configuration${NC}"
    
    # Check for replicas in StatefulSet or Deployment
    if grep -q "replicas:" "$MANIFEST_DIR/istio/istio-install.yml"; then
        log_test "replicas" "${GREEN}✓ PASS${NC}" "Replicas configured"
    else
        log_test "replicas" "${YELLOW}⚠ WARN${NC}" "Replicas not explicitly set"
    fi
}

# Generate JSON report
generate_report() {
    echo -e "\n${BLUE}Generating test report...${NC}"
    
    cat > "$RESULTS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "total_tests": $TOTAL_TESTS,
  "passed": $PASSED_TESTS,
  "failed": $FAILED_TESTS,
  "success_rate": $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}"),
  "tests": {
EOF
    
    local first=true
    for test_name in "${!TEST_RESULTS[@]}"; do
        if [[ "$first" = false ]]; then
            echo "," >> "$RESULTS_FILE"
        fi
        echo -n "    \"$test_name\": \"${TEST_RESULTS[$test_name]}\"" >> "$RESULTS_FILE"
        first=false
    done
    
    cat >> "$RESULTS_FILE" << EOF

  }
}
EOF
    
    echo -e "${GREEN}Report saved to $RESULTS_FILE${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}===================================${NC}"
    echo -e "${YELLOW}CERES K8s Manifest Validation Tests${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    test_istio_manifests || true
    test_yaml_syntax || true
    test_api_versions || true
    test_istio_resources || true
    test_security_policies || true
    test_resource_limits || true
    test_namespaces || true
    test_health_checks || true
    test_labels_annotations || true
    test_image_pull_policy || true
    test_service_accounts || true
    test_replicas || true
    
    # Summary
    echo -e "\n${YELLOW}===================================${NC}"
    echo -e "${YELLOW}Test Summary${NC}"
    echo -e "${YELLOW}===================================${NC}"
    echo -e "Total:   ${YELLOW}${TOTAL_TESTS}${NC}"
    echo -e "Passed:  ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:  ${RED}${FAILED_TESTS}${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
    else
        echo -e "${RED}✗ Some tests failed${NC}"
    fi
    
    generate_report
    
    return $FAILED_TESTS
}

main "$@"
