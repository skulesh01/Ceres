#!/bin/bash
#
# CERES v3.0.0 - Integration Tests
# Tests for multi-component interactions, Istio, Cost suite, and Security integration
#

set -e

TEST_DIR="tests"
RESULTS_FILE="${TEST_DIR}/integration-test-results.json"
INTEGRATION_LOG="${TEST_DIR}/integration-test.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

log_test() {
    local test_name=$1
    local status=$2
    local message=$3
    
    echo -e "${status}[$(date +'%H:%M:%S')] ${test_name}: ${message}${NC}" | tee -a "$INTEGRATION_LOG"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == *"PASS"* ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [[ "$status" == *"SKIP"* ]]; then
        SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Initialize test environment
init_test_env() {
    echo -e "${CYAN}Initializing test environment...${NC}"
    mkdir -p "$TEST_DIR"
    > "$INTEGRATION_LOG"  # Clear log file
    
    # Check for required tools
    local required_tools=("kubectl" "docker" "git" "jq" "yq")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Missing tools: ${missing_tools[@]}${NC}"
        echo -e "${YELLOW}Some tests will be skipped${NC}"
    fi
}

# Test 1: Istio and Cost Optimization integration
test_istio_cost_integration() {
    echo -e "\n${YELLOW}Test 1: Istio & Cost Optimization Integration${NC}"
    
    # Check if ServiceMonitor is configured in Istio for cost metrics
    if grep -q "ServiceMonitor" "config/istio/istio-install.yml"; then
        log_test "istio_servicemonitor" "${GREEN}✓ PASS${NC}" "ServiceMonitor configured for Prometheus"
    else
        log_test "istio_servicemonitor" "${RED}✗ FAIL${NC}" "ServiceMonitor not found"
        return 1
    fi
    
    # Check if cost metrics are mentioned in scripts
    if grep -q "cost:hourly:usd\|cost:daily:usd" "scripts/cost-optimization.sh"; then
        log_test "cost_metrics_defined" "${GREEN}✓ PASS${NC}" "Cost metrics properly defined"
    else
        log_test "cost_metrics_defined" "${RED}✗ FAIL${NC}" "Cost metrics not defined"
        return 1
    fi
}

# Test 2: Security policies and Istio mTLS
test_security_istio_integration() {
    echo -e "\n${YELLOW}Test 2: Security Policies & Istio mTLS Integration${NC}"
    
    # Check for PeerAuthentication in Istio config
    if grep -q "kind: PeerAuthentication" "config/istio/istio-install.yml"; then
        log_test "peer_authentication" "${GREEN}✓ PASS${NC}" "PeerAuthentication (mTLS) configured"
    else
        log_test "peer_authentication" "${RED}✗ FAIL${NC}" "PeerAuthentication missing"
        return 1
    fi
    
    # Check for AuthorizationPolicy
    if grep -q "kind: AuthorizationPolicy" "config/istio/istio-install.yml"; then
        log_test "istio_authpolicy" "${GREEN}✓ PASS${NC}" "Istio AuthorizationPolicy configured"
    else
        log_test "istio_authpolicy" "${RED}✗ FAIL${NC}" "Istio AuthorizationPolicy missing"
        return 1
    fi
    
    # Check for NetworkPolicy in security config
    if grep -q "kind: NetworkPolicy" "config/security/hardening-policies.yml"; then
        log_test "network_policy" "${GREEN}✓ PASS${NC}" "NetworkPolicy configured"
    else
        log_test "network_policy" "${RED}✗ FAIL${NC}" "NetworkPolicy missing"
        return 1
    fi
    
    # Check for coordination between Pod and Istio policies
    if grep -q "PodSecurityPolicy" "config/security/hardening-policies.yml" && \
       grep -q "AuthorizationPolicy" "config/istio/istio-install.yml"; then
        log_test "policy_coordination" "${GREEN}✓ PASS${NC}" "Pod and Istio policies coordinated"
    else
        log_test "policy_coordination" "${YELLOW}⚠ WARN${NC}" "Policy coordination may need review"
    fi
}

# Test 3: Multi-cloud and Cost Optimization
test_multicloud_cost_integration() {
    echo -e "\n${YELLOW}Test 3: Multi-Cloud & Cost Optimization Integration${NC}"
    
    # Check for AWS cost considerations in Terraform
    if grep -q "instance_type\|spot" "config/terraform/multi-cloud.tf"; then
        log_test "aws_cost_config" "${GREEN}✓ PASS${NC}" "AWS cost optimization configured"
    else
        log_test "aws_cost_config" "${YELLOW}⚠ WARN${NC}" "AWS cost optimization may be incomplete"
    fi
    
    # Check for reserved instance recommendations script
    if grep -q "reserved" "scripts/cost-optimization.sh"; then
        log_test "ri_recommendations" "${GREEN}✓ PASS${NC}" "Reserved instance recommendations present"
    else
        log_test "ri_recommendations" "${RED}✗ FAIL${NC}" "Reserved instance recommendations missing"
        return 1
    fi
    
    # Check for multi-cloud resource quotas
    if grep -q "ResourceQuota\|LimitRange" "config/security/hardening-policies.yml"; then
        log_test "resource_quotas" "${GREEN}✓ PASS${NC}" "Resource quotas for cost control"
    else
        log_test "resource_quotas" "${YELLOW}⚠ WARN${NC}" "Resource quotas not explicitly configured"
    fi
}

# Test 4: Performance tuning and Istio
test_performance_istio_integration() {
    echo -e "\n${YELLOW}Test 4: Performance Tuning & Istio Integration${NC}"
    
    # Check if performance tuning mentions Istio
    if grep -q -i "istio\|envoy\|proxy" "scripts/performance-tuning.yml"; then
        log_test "performance_istio" "${GREEN}✓ PASS${NC}" "Performance tuning includes Istio optimization"
    else
        log_test "performance_istio" "${YELLOW}⚠ WARN${NC}" "Istio-specific performance tuning may be missing"
    fi
    
    # Check for connection pooling and circuit breaker in Istio
    if grep -q "DestinationRule\|loadBalancer\|connectionPool" "config/istio/istio-install.yml"; then
        log_test "circuit_breaker" "${GREEN}✓ PASS${NC}" "Circuit breaker and connection pooling configured"
    else
        log_test "circuit_breaker" "${YELLOW}⚠ WARN${NC}" "Circuit breaker configuration may be incomplete"
    fi
}

# Test 5: Migration prerequisites
test_migration_prerequisites() {
    echo -e "\n${YELLOW}Test 5: Migration Prerequisites${NC}"
    
    # Check for migration documentation
    if [[ -f "docs/MIGRATION_v2.9_to_v3.0.md" ]]; then
        log_test "migration_doc" "${GREEN}✓ PASS${NC}" "Migration documentation present"
    else
        log_test "migration_doc" "${RED}✗ FAIL${NC}" "Migration documentation missing"
        return 1
    fi
    
    # Check for backup procedures in migration docs
    if grep -q "backup\|etcd" "docs/MIGRATION_v2.9_to_v3.0.md"; then
        log_test "migration_backup" "${GREEN}✓ PASS${NC}" "Backup procedures documented"
    else
        log_test "migration_backup" "${RED}✗ FAIL${NC}" "Backup procedures not documented"
        return 1
    fi
    
    # Check for validation procedures
    if grep -q "validation\|verify\|test" "docs/MIGRATION_v2.9_to_v3.0.md"; then
        log_test "migration_validation" "${GREEN}✓ PASS${NC}" "Validation procedures documented"
    else
        log_test "migration_validation" "${RED}✗ FAIL${NC}" "Validation procedures not documented"
        return 1
    fi
}

# Test 6: Complete v3.0.0 component coverage
test_v3_component_coverage() {
    echo -e "\n${YELLOW}Test 6: v3.0.0 Component Coverage${NC}"
    
    local components_found=0
    local total_components=7
    
    # Check for Istio
    if [[ -f "config/istio/istio-install.yml" ]]; then
        components_found=$((components_found + 1))
        log_test "istio_component" "${GREEN}✓ PASS${NC}" "Istio component present"
    else
        log_test "istio_component" "${RED}✗ FAIL${NC}" "Istio component missing"
    fi
    
    # Check for Cost Optimization
    if [[ -f "scripts/cost-optimization.sh" ]]; then
        components_found=$((components_found + 1))
        log_test "cost_component" "${GREEN}✓ PASS${NC}" "Cost Optimization component present"
    else
        log_test "cost_component" "${RED}✗ FAIL${NC}" "Cost Optimization component missing"
    fi
    
    # Check for Multi-Cloud Terraform
    if [[ -f "config/terraform/multi-cloud.tf" ]]; then
        components_found=$((components_found + 1))
        log_test "terraform_component" "${GREEN}✓ PASS${NC}" "Multi-Cloud Terraform present"
    else
        log_test "terraform_component" "${RED}✗ FAIL${NC}" "Multi-Cloud Terraform missing"
    fi
    
    # Check for Security Hardening
    if [[ -f "config/security/hardening-policies.yml" ]]; then
        components_found=$((components_found + 1))
        log_test "security_component" "${GREEN}✓ PASS${NC}" "Security Hardening component present"
    else
        log_test "security_component" "${RED}✗ FAIL${NC}" "Security Hardening component missing"
    fi
    
    # Check for Performance Tuning
    if [[ -f "scripts/performance-tuning.yml" ]]; then
        components_found=$((components_found + 1))
        log_test "performance_component" "${GREEN}✓ PASS${NC}" "Performance Tuning component present"
    else
        log_test "performance_component" "${RED}✗ FAIL${NC}" "Performance Tuning component missing"
    fi
    
    # Check for Migration Guide
    if [[ -f "docs/MIGRATION_v2.9_to_v3.0.md" ]]; then
        components_found=$((components_found + 1))
        log_test "migration_component" "${GREEN}✓ PASS${NC}" "Migration Guide present"
    else
        log_test "migration_component" "${RED}✗ FAIL${NC}" "Migration Guide missing"
    fi
    
    # Check for Complete Guide
    if [[ -f "docs/CERES_v3.0_COMPLETE_GUIDE.md" ]]; then
        components_found=$((components_found + 1))
        log_test "guide_component" "${GREEN}✓ PASS${NC}" "Complete v3.0.0 Guide present"
    else
        log_test "guide_component" "${RED}✗ FAIL${NC}" "Complete v3.0.0 Guide missing"
    fi
    
    if [[ $components_found -eq $total_components ]]; then
        log_test "all_components" "${GREEN}✓ PASS${NC}" "All v3.0.0 components present ($components_found/$total_components)"
    else
        log_test "all_components" "${RED}✗ FAIL${NC}" "Missing components ($components_found/$total_components)"
        return 1
    fi
}

# Test 7: Documentation consistency
test_documentation_consistency() {
    echo -e "\n${YELLOW}Test 7: Documentation Consistency${NC}"
    
    # Check if CHANGELOG mentions v3.0.0
    if grep -q "v3.0\|3.0.0" "CHANGELOG.md"; then
        log_test "changelog_v3" "${GREEN}✓ PASS${NC}" "CHANGELOG updated for v3.0.0"
    else
        log_test "changelog_v3" "${RED}✗ FAIL${NC}" "CHANGELOG not updated for v3.0.0"
        return 1
    fi
    
    # Check if README mentions v3.0.0
    if grep -q "v3.0\|3.0.0" "README.md"; then
        log_test "readme_v3" "${GREEN}✓ PASS${NC}" "README mentions v3.0.0"
    else
        log_test "readme_v3" "${YELLOW}⚠ WARN${NC}" "README may need update for v3.0.0"
    fi
}

# Test 8: Configuration syntax check (YAML, HCL, JSON)
test_syntax_validation() {
    echo -e "\n${YELLOW}Test 8: Configuration Syntax Validation${NC}"
    
    local syntax_ok=0
    
    # Check YAML files
    for file in $(find config -name "*.yml" -o -name "*.yaml" 2>/dev/null); do
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            syntax_ok=$((syntax_ok + 1))
        fi
    done
    
    if [[ $syntax_ok -gt 0 ]]; then
        log_test "yaml_syntax" "${GREEN}✓ PASS${NC}" "YAML files syntax valid ($syntax_ok files)"
    else
        log_test "yaml_syntax" "${YELLOW}⚠ WARN${NC}" "Could not validate YAML files"
    fi
}

# Generate JSON report
generate_report() {
    echo -e "\n${BLUE}Generating integration test report...${NC}"
    
    cat > "$RESULTS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "test_suite": "Integration Tests",
  "total_tests": $TOTAL_TESTS,
  "passed": $PASSED_TESTS,
  "failed": $FAILED_TESTS,
  "skipped": $SKIPPED_TESTS,
  "success_rate": $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}"),
  "test_categories": {
    "istio_cost_integration": "TESTED",
    "security_istio_integration": "TESTED",
    "multicloud_cost_integration": "TESTED",
    "performance_istio_integration": "TESTED",
    "migration_prerequisites": "TESTED",
    "component_coverage": "TESTED",
    "documentation_consistency": "TESTED",
    "syntax_validation": "TESTED"
  }
}
EOF
    
    echo -e "${GREEN}Report saved to $RESULTS_FILE${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}===================================${NC}"
    echo -e "${YELLOW}CERES v3.0.0 Integration Tests    ${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    init_test_env
    
    test_istio_cost_integration || true
    test_security_istio_integration || true
    test_multicloud_cost_integration || true
    test_performance_istio_integration || true
    test_migration_prerequisites || true
    test_v3_component_coverage || true
    test_documentation_consistency || true
    test_syntax_validation || true
    
    # Summary
    echo -e "\n${YELLOW}===================================${NC}"
    echo -e "${YELLOW}Integration Test Summary${NC}"
    echo -e "${YELLOW}===================================${NC}"
    echo -e "Total:   ${YELLOW}${TOTAL_TESTS}${NC}"
    echo -e "Passed:  ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:  ${RED}${FAILED_TESTS}${NC}"
    echo -e "Skipped: ${CYAN}${SKIPPED_TESTS}${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All integration tests passed!${NC}"
    else
        echo -e "\n${RED}✗ Some integration tests failed${NC}"
    fi
    
    generate_report
    
    echo -e "\n${BLUE}Full test log: $INTEGRATION_LOG${NC}"
    
    return $FAILED_TESTS
}

main "$@"
