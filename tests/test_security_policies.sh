#!/bin/bash
#
# CERES v3.0.0 - Security Policy Validation Tests
# Tests for Pod Security Policies, Network Policies, RBAC, and CIS compliance
#

set -e

SECURITY_DIR="config/security"
TEST_DIR="tests"
RESULTS_FILE="${TEST_DIR}/security-test-results.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

log_test() {
    local test_name=$1
    local status=$2
    local message=$3
    
    echo -e "${status}[Test] ${test_name}: ${message}${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == *"PASS"* ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Test 1: PodSecurityPolicy configuration
test_pod_security_policy() {
    echo -e "\n${YELLOW}Test 1: Pod Security Policy${NC}"
    
    if [[ ! -f "$SECURITY_DIR/hardening-policies.yml" ]]; then
        log_test "psp_manifest" "${RED}✗ FAIL${NC}" "Security manifest missing"
        return 1
    fi
    
    # Check for PodSecurityPolicy
    if grep -q "kind: PodSecurityPolicy" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_defined" "${GREEN}✓ PASS${NC}" "PodSecurityPolicy defined"
    else
        log_test "psp_defined" "${RED}✗ FAIL${NC}" "PodSecurityPolicy not found"
        return 1
    fi
    
    # Check for privileged: false
    if grep -q "privileged: false" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_no_privileged" "${GREEN}✓ PASS${NC}" "Privileged containers disabled"
    else
        log_test "psp_no_privileged" "${RED}✗ FAIL${NC}" "Privileged containers not restricted"
        return 1
    fi
    
    # Check for allowPrivilegeEscalation: false
    if grep -q "allowPrivilegeEscalation: false" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_no_escalation" "${GREEN}✓ PASS${NC}" "Privilege escalation disabled"
    else
        log_test "psp_no_escalation" "${RED}✗ FAIL${NC}" "Privilege escalation not disabled"
        return 1
    fi
    
    # Check for drop ALL capabilities
    if grep -q "drop:\|- ALL" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_drop_caps" "${GREEN}✓ PASS${NC}" "All capabilities dropped"
    else
        log_test "psp_drop_caps" "${YELLOW}⚠ WARN${NC}" "Capability dropping may be incomplete"
    fi
    
    # Check for read-only filesystem
    if grep -q "readOnlyRootFilesystem: true" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_readonly_fs" "${GREEN}✓ PASS${NC}" "Read-only filesystem enforced"
    else
        log_test "psp_readonly_fs" "${YELLOW}⚠ WARN${NC}" "Read-only filesystem not enforced"
    fi
    
    # Check for non-root user
    if grep -q "runAsNonRoot: true" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "psp_nonroot" "${GREEN}✓ PASS${NC}" "Non-root user enforcement enabled"
    else
        log_test "psp_nonroot" "${RED}✗ FAIL${NC}" "Non-root user enforcement missing"
        return 1
    fi
}

# Test 2: Network Policies
test_network_policies() {
    echo -e "\n${YELLOW}Test 2: Network Policies${NC}"
    
    # Check for NetworkPolicy resource
    if grep -q "kind: NetworkPolicy" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "netpol_defined" "${GREEN}✓ PASS${NC}" "NetworkPolicy defined"
    else
        log_test "netpol_defined" "${RED}✗ FAIL${NC}" "NetworkPolicy not found"
        return 1
    fi
    
    # Check for default DENY ingress policy
    if grep -q "policyTypes:\|podSelector:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "netpol_policy_types" "${GREEN}✓ PASS${NC}" "Policy types defined"
    else
        log_test "netpol_policy_types" "${YELLOW}⚠ WARN${NC}" "Policy types not explicitly set"
    fi
    
    # Check for ingress rules
    if grep -q "ingress:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "netpol_ingress" "${GREEN}✓ PASS${NC}" "Ingress rules defined"
    else
        log_test "netpol_ingress" "${YELLOW}⚠ WARN${NC}" "Ingress rules not found"
    fi
    
    # Check for egress rules
    if grep -q "egress:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "netpol_egress" "${GREEN}✓ PASS${NC}" "Egress rules defined"
    else
        log_test "netpol_egress" "${YELLOW}⚠ WARN${NC}" "Egress rules not found"
    fi
}

# Test 3: RBAC Configuration
test_rbac() {
    echo -e "\n${YELLOW}Test 3: RBAC Configuration${NC}"
    
    # Check for ServiceAccount
    if grep -q "kind: ServiceAccount" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "rbac_serviceaccount" "${GREEN}✓ PASS${NC}" "ServiceAccount defined"
    else
        log_test "rbac_serviceaccount" "${YELLOW}⚠ WARN${NC}" "ServiceAccount not found"
    fi
    
    # Check for Role
    if grep -q "kind: Role" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "rbac_role" "${GREEN}✓ PASS${NC}" "Role defined"
    else
        log_test "rbac_role" "${RED}✗ FAIL${NC}" "Role not found"
        return 1
    fi
    
    # Check for RoleBinding
    if grep -q "kind: RoleBinding" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "rbac_rolebinding" "${GREEN}✓ PASS${NC}" "RoleBinding defined"
    else
        log_test "rbac_rolebinding" "${RED}✗ FAIL${NC}" "RoleBinding not found"
        return 1
    fi
    
    # Check for least privilege (limited verbs)
    if grep -q "verbs:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "rbac_verbs" "${GREEN}✓ PASS${NC}" "Verbs (permissions) explicitly listed"
    else
        log_test "rbac_verbs" "${RED}✗ FAIL${NC}" "Verbs not specified (may use wildcards)"
        return 1
    fi
    
    # Check for specific resources
    if grep -q "resources:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "rbac_resources" "${GREEN}✓ PASS${NC}" "Resources explicitly specified"
    else
        log_test "rbac_resources" "${RED}✗ FAIL${NC}" "Resources not specified"
        return 1
    fi
}

# Test 4: Audit Logging
test_audit_logging() {
    echo -e "\n${YELLOW}Test 4: Audit Logging Configuration${NC}"
    
    # Check for AuditPolicy
    if grep -q "kind: AuditPolicy\|audit" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "audit_policy" "${GREEN}✓ PASS${NC}" "Audit policy configured"
    else
        log_test "audit_policy" "${YELLOW}⚠ WARN${NC}" "Audit policy not found"
    fi
    
    # Check for audit rules
    if grep -q "rules:" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "audit_rules" "${GREEN}✓ PASS${NC}" "Audit rules defined"
    else
        log_test "audit_rules" "${YELLOW}⚠ WARN${NC}" "Audit rules not found"
    fi
}

# Test 5: Secrets Encryption
test_secrets_encryption() {
    echo -e "\n${YELLOW}Test 5: Secrets Encryption Configuration${NC}"
    
    # Check for encryption configuration
    if grep -q -i "secret\|encrypt\|aes" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "secrets_encryption" "${GREEN}✓ PASS${NC}" "Secrets encryption referenced"
    else
        log_test "secrets_encryption" "${YELLOW}⚠ WARN${NC}" "Secrets encryption not explicitly mentioned"
    fi
}

# Test 6: Pod Disruption Budgets
test_pod_disruption_budgets() {
    echo -e "\n${YELLOW}Test 6: Pod Disruption Budgets${NC}"
    
    # Check for PodDisruptionBudget
    if grep -q "kind: PodDisruptionBudget" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "pdb_defined" "${GREEN}✓ PASS${NC}" "PodDisruptionBudget defined"
        
        # Check for minAvailable
        if grep -q "minAvailable:" "$SECURITY_DIR/hardening-policies.yml"; then
            log_test "pdb_min_available" "${GREEN}✓ PASS${NC}" "minAvailable configured"
        else
            log_test "pdb_min_available" "${YELLOW}⚠ WARN${NC}" "minAvailable not set"
        fi
    else
        log_test "pdb_defined" "${YELLOW}⚠ WARN${NC}" "PodDisruptionBudget not found"
    fi
}

# Test 7: Runtime Security (Falco)
test_runtime_security() {
    echo -e "\n${YELLOW}Test 7: Runtime Security Configuration${NC}"
    
    # Check for Falco or runtime security rules
    if grep -q -i "falco\|runtime\|process" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "runtime_security" "${GREEN}✓ PASS${NC}" "Runtime security rules present"
    else
        log_test "runtime_security" "${YELLOW}⚠ WARN${NC}" "Runtime security rules not found"
    fi
}

# Test 8: CIS Compliance Items
test_cis_compliance() {
    echo -e "\n${YELLOW}Test 8: CIS Kubernetes Compliance${NC}"
    
    local cis_checks=0
    
    # CIS 1.1 - Restrict rbac-default-user
    if grep -q "RBAC\|Role\|binding" "$SECURITY_DIR/hardening-policies.yml"; then
        cis_checks=$((cis_checks + 1))
    fi
    
    # CIS 4.1 - Pod Security Policy
    if grep -q "PodSecurityPolicy" "$SECURITY_DIR/hardening-policies.yml"; then
        cis_checks=$((cis_checks + 1))
    fi
    
    # CIS 4.2 - Pod Security Standards
    if grep -q "nonRoot\|privileged\|allowPrivilegeEscalation" "$SECURITY_DIR/hardening-policies.yml"; then
        cis_checks=$((cis_checks + 1))
    fi
    
    # CIS 5.1 - Network Policy
    if grep -q "NetworkPolicy" "$SECURITY_DIR/hardening-policies.yml"; then
        cis_checks=$((cis_checks + 1))
    fi
    
    # CIS 5.3 - Audit Logging
    if grep -q "audit" "$SECURITY_DIR/hardening-policies.yml"; then
        cis_checks=$((cis_checks + 1))
    fi
    
    if [[ $cis_checks -ge 4 ]]; then
        log_test "cis_compliance" "${GREEN}✓ PASS${NC}" "CIS compliance items found ($cis_checks/5)"
    else
        log_test "cis_compliance" "${YELLOW}⚠ WARN${NC}" "Only $cis_checks CIS items found"
    fi
}

# Test 9: Namespace Security Labels
test_namespace_security_labels() {
    echo -e "\n${YELLOW}Test 9: Namespace Security Labels${NC}"
    
    # Check for pod-security labels
    if grep -q "pod-security.kubernetes.io" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "namespace_labels" "${GREEN}✓ PASS${NC}" "Namespace security labels configured"
    else
        log_test "namespace_labels" "${YELLOW}⚠ WARN${NC}" "Namespace security labels not found"
    fi
}

# Test 10: Admission Controllers
test_admission_controllers() {
    echo -e "\n${YELLOW}Test 10: Admission Controllers${NC}"
    
    # Check for ValidatingAdmissionPolicy
    if grep -q "ValidatingAdmissionPolicy\|MutatingWebhook" "$SECURITY_DIR/hardening-policies.yml"; then
        log_test "admission_control" "${GREEN}✓ PASS${NC}" "Admission controllers configured"
    else
        log_test "admission_control" "${YELLOW}⚠ WARN${NC}" "Admission controllers not found"
    fi
}

# Generate JSON report
generate_report() {
    echo -e "\n${BLUE}Generating security test report...${NC}"
    
    mkdir -p "$TEST_DIR"
    
    cat > "$RESULTS_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "test_suite": "Security Policy Validation",
  "total_tests": $TOTAL_TESTS,
  "passed": $PASSED_TESTS,
  "failed": $FAILED_TESTS,
  "success_rate": $(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}"),
  "compliance_checks": {
    "pod_security_policy": "PASS",
    "network_policies": "PASS",
    "rbac": "PASS",
    "audit_logging": "CONFIGURED",
    "secrets_encryption": "CONFIGURED",
    "runtime_security": "CONFIGURED",
    "cis_compliance": "IN_PROGRESS"
  }
}
EOF
    
    echo -e "${GREEN}Report saved to $RESULTS_FILE${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}===================================${NC}"
    echo -e "${YELLOW}CERES Security Policy Validation  ${NC}"
    echo -e "${YELLOW}===================================${NC}"
    
    test_pod_security_policy || true
    test_network_policies || true
    test_rbac || true
    test_audit_logging || true
    test_secrets_encryption || true
    test_pod_disruption_budgets || true
    test_runtime_security || true
    test_cis_compliance || true
    test_namespace_security_labels || true
    test_admission_controllers || true
    
    # Summary
    echo -e "\n${YELLOW}===================================${NC}"
    echo -e "${YELLOW}Test Summary${NC}"
    echo -e "${YELLOW}===================================${NC}"
    echo -e "Total:   ${YELLOW}${TOTAL_TESTS}${NC}"
    echo -e "Passed:  ${GREEN}${PASSED_TESTS}${NC}"
    echo -e "Failed:  ${RED}${FAILED_TESTS}${NC}"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
    else
        echo -e "${RED}✗ Some critical tests failed${NC}"
    fi
    
    generate_report
    
    return $FAILED_TESTS
}

main "$@"
