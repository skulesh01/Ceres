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

# STEP 4: Deploy services with Helm
echo "[4/5] Deploying all CERES services..."
export KUBECONFIG=~/.kube/config

# Deploy core services
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install postgresql bitnami/postgresql \
    -n ceres --create-namespace \
    -f config/helm/postgresql-values.yml

helm install redis bitnami/redis \
    -n ceres \
    -f config/helm/redis-values.yml

# Deploy applications
helm install keycloak bitnami/keycloak \
    -n ceres \
    -f config/helm/keycloak-values.yml

helm install gitlab bitnami/gitlab \
    -n ceres \
    -f config/helm/gitlab-values.yml

# Deploy monitoring
helm install prometheus bitnami/prometheus \
    -n ceres \
    -f config/helm/prometheus-values.yml

helm install grafana bitnami/grafana \
    -n ceres \
    -f config/helm/grafana-values.yml

echo "✓ All services deployed"
echo ""

# STEP 5: Bootstrap integrations
echo "[5/5] Setting up integrations..."
pwsh -File ./scripts/keycloak-bootstrap-full.ps1
pwsh -File ./scripts/setup-webhooks.ps1

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT COMPLETE!                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Services:"
echo "  Keycloak:  https://auth.$DOMAIN"
echo "  GitLab:    https://gitlab.$DOMAIN"
echo "  Zulip:     https://zulip.$DOMAIN"
echo "  Grafana:   https://grafana.$DOMAIN"
echo ""
echo "Getting kubeconfig:"
echo "  export KUBECONFIG=~/.kube/config"
echo "  kubectl get all -n ceres"
echo ""
