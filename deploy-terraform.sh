#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     CERES TERRAFORM + KUBERNETES FULL DEPLOYMENT              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# STEP 1: Check prerequisites
echo "[1/5] Checking prerequisites..."
which terraform > /dev/null || { echo "ERROR: terraform not found"; exit 1; }
which ansible > /dev/null || { echo "ERROR: ansible not found"; exit 1; }

if [ ! -f terraform/terraform.tfvars ]; then
    echo "ERROR: terraform/terraform.tfvars not found"
    echo "Copy from terraform/terraform.tfvars.example and configure"
    exit 1
fi

# STEP 2: Terraform plan & apply
echo "[2/5] Provisioning infrastructure with Terraform..."
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
cd ..

# Get outputs
CORE_VM_IP=$(terraform output -raw core_vm_ip 2>/dev/null || echo "192.168.1.10")
APPS_VM_IP=$(terraform output -raw apps_vm_ip 2>/dev/null || echo "192.168.1.11")
EDGE_VM_IP=$(terraform output -raw edge_vm_ip 2>/dev/null || echo "192.168.1.12")

echo "✓ Infrastructure ready"
echo "  Core VM: $CORE_VM_IP"
echo "  Apps VM: $APPS_VM_IP"
echo "  Edge VM: $EDGE_VM_IP"
echo ""

# STEP 3: Ansible base setup
echo "[3/5] Setting up base infrastructure with Ansible..."
ansible-playbook \
    -i <(echo "[all]
core_vm ansible_host=$CORE_VM_IP
apps_vm ansible_host=$APPS_VM_IP
edge_vm ansible_host=$EDGE_VM_IP") \
    ansible/playbooks/base-setup.yml

echo "✓ Base infrastructure ready (k3s installed)"
echo ""

# STEP 4: Ansible deploy (Docker stack on provisioned VMs)
echo "[4/5] Deploying CERES services with Ansible..."
INVENTORY=$(mktemp)
cat > "$INVENTORY" <<EOF
[ceres_servers]
core_vm ansible_host=$CORE_VM_IP ansible_user=root
apps_vm ansible_host=$APPS_VM_IP ansible_user=root
edge_vm ansible_host=$EDGE_VM_IP ansible_user=root
EOF

ansible-playbook -i "$INVENTORY" ansible/playbooks/deploy-ceres.yml
rm -f "$INVENTORY"

echo "✓ Services deployed (Docker/Compose)."
echo ""

# STEP 5: Next steps (FluxCD/K8s optional)
echo "[5/5] Next steps (manual):"
echo "- (Optional) Bootstrap FluxCD: see flux/README.md"
echo "- (Optional) Run scripts/keycloak-bootstrap-full.ps1 for OIDC clients"
echo "- Validate services: docker ps, curl https://auth.$DOMAIN"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT COMPLETE!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
