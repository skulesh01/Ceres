#!/bin/bash
#
# CERES v3.0.0 - Terraform Validation Tests
# Tests for AWS, Azure, GCP, and Hybrid infrastructure configurations
#

set -e

TERRAFORM_DIR="config/terraform"
TEST_DIR="tests"
RESULTS_FILE="${TEST_DIR}/terraform-test-results.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    
    echo -e "${status}[$(date +'%Y-%m-%d %H:%M:%S')] ${test_name}: ${message}${NC}"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$status" == *"PASS"* ]]; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
        TEST_RESULTS["$test_name"]="PASS"
    else
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS["$test_name"]="FAIL: $message"
    fi
}

# Test 1: Terraform format validation
test_terraform_format() {
    echo -e "\n${YELLOW}Test 1: Terraform Format Validation${NC}"
    
    cd "$TERRAFORM_DIR"
    
    if terraform fmt -check -recursive .; then
        log_test "terraform_format" "${GREEN}✓ PASS${NC}" "All HCL files properly formatted"
    else
        log_test "terraform_format" "${RED}✗ FAIL${NC}" "HCL formatting issues detected"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# Test 2: Terraform validation
test_terraform_validate() {
    echo -e "\n${YELLOW}Test 2: Terraform Syntax Validation${NC}"
    
    cd "$TERRAFORM_DIR"
    
    # Initialize terraform (without applying)
    if terraform init -backend=false > /dev/null 2>&1; then
        if terraform validate; then
            log_test "terraform_validate" "${GREEN}✓ PASS${NC}" "Terraform configuration valid"
        else
            log_test "terraform_validate" "${RED}✗ FAIL${NC}" "Terraform validation failed"
            cd ../..
            return 1
        fi
    else
        log_test "terraform_validate" "${RED}✗ FAIL${NC}" "Terraform initialization failed"
        cd ../..
        return 1
    fi
    
    cd ../..
}

# Test 3: AWS EKS configuration
test_aws_eks_config() {
    echo -e "\n${YELLOW}Test 3: AWS EKS Configuration${NC}"
    
    # Check for required AWS resources
    if grep -q 'resource "aws_eks_cluster"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "aws_eks_cluster" "${GREEN}✓ PASS${NC}" "EKS cluster resource defined"
    else
        log_test "aws_eks_cluster" "${RED}✗ FAIL${NC}" "EKS cluster resource missing"
        return 1
    fi
    
    # Check for RDS configuration
    if grep -q 'resource "aws_db_instance"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "aws_rds_instance" "${GREEN}✓ PASS${NC}" "RDS instance resource defined"
    else
        log_test "aws_rds_instance" "${RED}✗ FAIL${NC}" "RDS instance resource missing"
        return 1
    fi
    
    # Check for ElastiCache configuration
    if grep -q 'resource "aws_elasticache_cluster"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "aws_elasticache" "${GREEN}✓ PASS${NC}" "ElastiCache resource defined"
    else
        log_test "aws_elasticache" "${RED}✗ FAIL${NC}" "ElastiCache resource missing"
        return 1
    fi
}

# Test 4: Azure AKS configuration
test_azure_aks_config() {
    echo -e "\n${YELLOW}Test 4: Azure AKS Configuration${NC}"
    
    # Check for AKS cluster
    if grep -q 'resource "azurerm_kubernetes_cluster"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "azure_aks_cluster" "${GREEN}✓ PASS${NC}" "AKS cluster resource defined"
    else
        log_test "azure_aks_cluster" "${RED}✗ FAIL${NC}" "AKS cluster resource missing"
        return 1
    fi
    
    # Check for Azure Database
    if grep -q 'resource "azurerm_postgresql_flexible_server"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "azure_database" "${GREEN}✓ PASS${NC}" "Azure Database resource defined"
    else
        log_test "azure_database" "${RED}✗ FAIL${NC}" "Azure Database resource missing"
        return 1
    fi
}

# Test 5: GCP GKE configuration
test_gcp_gke_config() {
    echo -e "\n${YELLOW}Test 5: GCP GKE Configuration${NC}"
    
    # Check for GKE cluster
    if grep -q 'resource "google_container_cluster"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "gcp_gke_cluster" "${GREEN}✓ PASS${NC}" "GKE cluster resource defined"
    else
        log_test "gcp_gke_cluster" "${RED}✗ FAIL${NC}" "GKE cluster resource missing"
        return 1
    fi
    
    # Check for Cloud SQL
    if grep -q 'resource "google_sql_database_instance"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "gcp_cloud_sql" "${GREEN}✓ PASS${NC}" "Cloud SQL resource defined"
    else
        log_test "gcp_cloud_sql" "${RED}✗ FAIL${NC}" "Cloud SQL resource missing"
        return 1
    fi
}

# Test 6: Variable definitions
test_variables() {
    echo -e "\n${YELLOW}Test 6: Terraform Variables${NC}"
    
    # Check for AWS region variable
    if grep -q 'variable "aws_region"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "aws_region_var" "${GREEN}✓ PASS${NC}" "AWS region variable defined"
    else
        log_test "aws_region_var" "${RED}✗ FAIL${NC}" "AWS region variable missing"
        return 1
    fi
    
    # Check for cluster name variable
    if grep -q 'variable "cluster_name"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "cluster_name_var" "${GREEN}✓ PASS${NC}" "Cluster name variable defined"
    else
        log_test "cluster_name_var" "${RED}✗ FAIL${NC}" "Cluster name variable missing"
        return 1
    fi
}

# Test 7: Outputs definition
test_outputs() {
    echo -e "\n${YELLOW}Test 7: Terraform Outputs${NC}"
    
    # Check for cluster endpoints output
    if grep -q 'output ".*_endpoint"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "cluster_endpoints" "${GREEN}✓ PASS${NC}" "Cluster endpoints output defined"
    else
        log_test "cluster_endpoints" "${RED}✗ FAIL${NC}" "Cluster endpoints output missing"
        return 1
    fi
}

# Test 8: Provider configuration
test_providers() {
    echo -e "\n${YELLOW}Test 8: Provider Configuration${NC}"
    
    local providers_found=0
    
    # Check for AWS provider
    if grep -q 'provider "aws"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "aws_provider" "${GREEN}✓ PASS${NC}" "AWS provider configured"
        providers_found=$((providers_found + 1))
    else
        log_test "aws_provider" "${RED}✗ FAIL${NC}" "AWS provider missing"
    fi
    
    # Check for Azure provider
    if grep -q 'provider "azurerm"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "azure_provider" "${GREEN}✓ PASS${NC}" "Azure provider configured"
        providers_found=$((providers_found + 1))
    else
        log_test "azure_provider" "${RED}✗ FAIL${NC}" "Azure provider missing"
    fi
    
    # Check for Google provider
    if grep -q 'provider "google"' "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "google_provider" "${GREEN}✓ PASS${NC}" "Google provider configured"
        providers_found=$((providers_found + 1))
    else
        log_test "google_provider" "${RED}✗ FAIL${NC}" "Google provider missing"
    fi
    
    if [[ $providers_found -lt 3 ]]; then
        return 1
    fi
}

# Test 9: Security configuration
test_security() {
    echo -e "\n${YELLOW}Test 9: Security Configuration${NC}"
    
    # Check for encryption
    if grep -q -i "encrypt\|kms\|ssl\|tls" "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "encryption_config" "${GREEN}✓ PASS${NC}" "Encryption/KMS configured"
    else
        log_test "encryption_config" "${RED}✗ FAIL${NC}" "Encryption configuration missing"
        return 1
    fi
    
    # Check for security groups
    if grep -q "aws_security_group\|azurerm_network_security_group" "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "security_groups" "${GREEN}✓ PASS${NC}" "Security groups defined"
    else
        log_test "security_groups" "${RED}✗ FAIL${NC}" "Security groups missing"
        return 1
    fi
}

# Test 10: HA/DR configuration
test_ha_dr() {
    echo -e "\n${YELLOW}Test 10: HA/DR Configuration${NC}"
    
    # Check for multi-AZ/zone configuration
    if grep -q -i "availability\|redundancy\|backup\|replica" "$TERRAFORM_DIR/multi-cloud.tf"; then
        log_test "ha_dr_config" "${GREEN}✓ PASS${NC}" "HA/DR configuration present"
    else
        log_test "ha_dr_config" "${RED}✗ FAIL${NC}" "HA/DR configuration missing"
        return 1
    fi
}

# Generate JSON report
generate_report() {
    echo -e "\n${YELLOW}Generating test report...${NC}"
    
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
    echo -e "${YELLOW}================================${NC}"
    echo -e "${YELLOW}CERES Terraform Validation Tests${NC}"
    echo -e "${YELLOW}================================${NC}"
    
    test_terraform_format || true
    test_terraform_validate || true
    test_aws_eks_config || true
    test_azure_aks_config || true
    test_gcp_gke_config || true
    test_variables || true
    test_outputs || true
    test_providers || true
    test_security || true
    test_ha_dr || true
    
    # Summary
    echo -e "\n${YELLOW}================================${NC}"
    echo -e "${YELLOW}Test Summary${NC}"
    echo -e "${YELLOW}================================${NC}"
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
