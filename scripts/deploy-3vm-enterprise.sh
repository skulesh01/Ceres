#!/bin/bash
################################################################################
# CERES PROXMOX 3-VM ENTERPRISE DEPLOYMENT
#
# PURPOSE:
#   Automated deployment of CERES platform on Proxmox hypervisor
#   Creates 3 VMs with distributed service architecture
#
# ARCHITECTURE:
#   VM1 (Core):       PostgreSQL, Redis, Keycloak SSO
#   VM2 (Apps):       Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
#   VM3 (Edge/Obs):   Caddy, Prometheus, Grafana, Portainer, Uptime Kuma
#
# REQUIREMENTS:
#   - Proxmox VE 7.0+
#   - Ubuntu 22.04 cloud image
#   - 12+ CPU cores, 20GB+ RAM, 200GB+ disk
#   - Utilities: qm, wget, ssh, scp, unzip, openssl
#
# USAGE:
#   bash deploy-3vm-enterprise.sh
#
# SOLID PRINCIPLES APPLIED:
#   - Single Responsibility: Functions have one clear purpose
#   - Open/Closed: Extensible via configuration, not code modification
#   - Liskov Substitution: Consistent function contracts
#   - Interface Segregation: Small, focused functions
#   - Dependency Inversion: Depends on tool abstractions, not implementations
#
# Version: 2.1
# Date: 2026-01-01
# License: MIT
################################################################################

# Strict error handling
set -euo pipefail

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Ensures required command-line tool is available
# Args:
#   $1 - Tool name (e.g., 'docker', 'ssh')
# Returns:
#   0 on success, exits with 1 if tool not found
ensure_tool() {
    local BIN=$1
    command -v "$BIN" >/dev/null 2>&1 || {
        echo -e "${RED}❌ Required tool '$BIN' not found. Install and retry.${NC}"
        exit 1
    }
}

for bin in qm wget ssh scp unzip openssl; do
    ensure_tool "$bin"
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "================================================================"
echo "   CERES PROXMOX 3-VM ENTERPRISE DEPLOYMENT"
echo "   11 ключевых сервисов (ядро) + опции"
echo "================================================================"
echo -e "${NC}"

# ============================================================================
# CONFIGURATION
# ============================================================================
VM1_IP="192.168.1.10"
VM1_CORES=4
VM1_MEM=8192
VM1_DISK=50
VM1_ID=110
VM1_NAME="ceres-core"

VM2_ID=111
VM2_NAME="ceres-apps"
VM2_IP="192.168.1.11"
VM2_CORES=4
VM2_MEM=8192
VM2_DISK=80

VM3_ID=112
VM3_NAME="ceres-monitoring"
VM3_IP="192.168.1.12"
VM3_CORES=2
VM3_MEM=4096
VM3_DISK=40

GATEWAY="192.168.1.1"
NETMASK="24"
NAMESERVER="8.8.8.8"
ROOT_PASSWORD="!r0oT3dc"

# Service distribution logic:
# VM1 (Core): PostgreSQL, Redis, Keycloak
# VM2 (Apps): Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
# VM3 (Edge/Obs): Caddy, Prometheus, Grafana, exporters, Portainer, Uptime Kuma (опционально Loki/Promtail/VPN/Tunnel)

# =========================================================================
# PHASE 1: DOWNLOAD UBUNTU CLOUD IMAGE
# =========================================================================

echo -e "${YELLOW}[Phase 1/6] Downloading Ubuntu Cloud Image...${NC}"

CLOUD_IMAGE_PATH="/var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img"

if [ ! -f "$CLOUD_IMAGE_PATH" ]; then
    echo "  Downloading Ubuntu 22.04 Cloud Image..."
    wget -q --show-progress -O /tmp/ubuntu-22.04.img \
        https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img
    mv /tmp/ubuntu-22.04.img "$CLOUD_IMAGE_PATH"
    echo -e "${GREEN}✅ Cloud image downloaded${NC}"
else
    echo -e "${GREEN}✅ Cloud image already exists${NC}"
fi

# Проверим, что архив проекта загружен до длительных операций
if [ ! -f /tmp/Ceres-deploy.zip ]; then
    echo -e "${RED}❌ Архив /tmp/Ceres-deploy.zip не найден. Загрузите его в Proxmox и перезапустите скрипт.${NC}"
    exit 1
fi

# =========================================================================
# PHASE 2: CREATE VMS
# =========================================================================

echo ""
echo -e "${YELLOW}[Phase 2/6] Creating Virtual Machines...${NC}"

create_vm() {
    local VMID=$1
    local NAME=$2
    local IP=$3
    local CORES=$4
    local MEM=$5
    local DISK=$6
    
    echo "  Creating VM $VMID: $NAME ($IP)..."
    
    # Check if VM exists and delete it
    if qm status $VMID &>/dev/null; then
        echo "    VM $VMID exists, destroying..."
        qm stop $VMID 2>/dev/null || true
        sleep 2
        qm destroy $VMID
    fi
    
    # Create VM
    qm create $VMID \
        --name $NAME \
        --memory $MEM \
        --cores $CORES \
        --net0 virtio,bridge=vmbr0 \
        --scsihw virtio-scsi-pci \
        --ostype l26
    
    # Import disk
    qm importdisk $VMID "$CLOUD_IMAGE_PATH" local-lvm > /dev/null
    
    # Attach disk
    qm set $VMID --scsi0 local-lvm:vm-$VMID-disk-0
    
    # Set boot disk
    qm set $VMID --boot c --bootdisk scsi0
    
    # Add cloud-init drive
    qm set $VMID --ide2 local-lvm:cloudinit
    
    # Serial console
    qm set $VMID --serial0 socket --vga serial0
    
    # QEMU Guest Agent
    qm set $VMID --agent enabled=1
    
    # Cloud-init configuration
    qm set $VMID --ciuser root
    qm set $VMID --cipassword "$ROOT_PASSWORD"
    qm set $VMID --ipconfig0 "ip=${IP}/${NETMASK},gw=${GATEWAY}"
    qm set $VMID --nameserver "$NAMESERVER"
    qm set $VMID --searchdomain "local"
    
    # Resize disk
    qm resize $VMID scsi0 ${DISK}G > /dev/null
    
    # Start VM
    qm start $VMID
    
    echo -e "${GREEN}✅ VM $NAME created and started${NC}"
}

# Create all VMs
create_vm $VM1_ID "$VM1_NAME" "$VM1_IP" $VM1_CORES $VM1_MEM $VM1_DISK
create_vm $VM2_ID "$VM2_NAME" "$VM2_IP" $VM2_CORES $VM2_MEM $VM2_DISK
create_vm $VM3_ID "$VM3_NAME" "$VM3_IP" $VM3_CORES $VM3_MEM $VM3_DISK

wait_for_ssh() {
    local VM_IP=$1
    local VM_NAME=$2
    local ATTEMPTS=30
    local SLEEP_SEC=10
    local COUNT=1
    echo "  Ожидание готовности SSH на ${VM_NAME} (${VM_IP})..."
    until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 root@${VM_IP} "echo ok" >/dev/null 2>&1; do
        if [ $COUNT -ge $ATTEMPTS ]; then
            echo -e "${RED}❌ ${VM_NAME} недоступен по SSH после $((ATTEMPTS*SLEEP_SEC)) секунд${NC}"
            exit 1
        fi
        COUNT=$((COUNT+1))
        sleep $SLEEP_SEC
    done
    echo -e "${GREEN}✅ ${VM_NAME} доступен по SSH${NC}"
}

echo ""
echo -e "${YELLOW}Waiting for VMs to be reachable via SSH...${NC}"
wait_for_ssh "$VM1_IP" "$VM1_NAME"
wait_for_ssh "$VM2_IP" "$VM2_NAME"
wait_for_ssh "$VM3_IP" "$VM3_NAME"
# ============================================================================
# PHASE 3: INSTALL DOCKER ON ALL VMS
# ============================================================================

echo ""
echo -e "${YELLOW}[Phase 3/6] Installing Docker on all VMs...${NC}"

install_docker() {
    local VM_IP=$1
    local VM_NAME=$2
    
    echo "  Installing Docker on $VM_NAME ($VM_IP)..."
    
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$VM_IP bash << 'DOCKEREOF'
    # Без интерактивных промптов
    export DEBIAN_FRONTEND=noninteractive

# Update system
apt-get update -qq
apt-get install -y ca-certificates curl gnupg lsb-release unzip

# Install Docker
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
systemctl start docker

# Verify
docker --version
docker compose version
DOCKEREOF
    
    echo -e "${GREEN}✅ Docker installed on $VM_NAME${NC}"
}

install_docker "$VM1_IP" "$VM1_NAME"
install_docker "$VM2_IP" "$VM2_NAME"
install_docker "$VM3_IP" "$VM3_NAME"

# ============================================================================
# PHASE 4: DEPLOY PROJECT FILES
# ============================================================================

echo ""
echo -e "${YELLOW}[Phase 4/6] Deploying project files...${NC}"

ENV_FILE="/tmp/ceres.env.generated"
rm -f "$ENV_FILE"

# Сгенерируем единый .env на хосте и распространим на все VM
generate_env() {
    # Извлечем .env.example из архива (поддержка архива с корневой папкой Ceres/ и без неё)
    if unzip -p /tmp/Ceres-deploy.zip Ceres/config/.env.example > "$ENV_FILE" 2>/dev/null; then
        :
    elif unzip -p /tmp/Ceres-deploy.zip config/.env.example > "$ENV_FILE" 2>/dev/null; then
        :
    else
        echo -e "${RED}❌ Не удалось извлечь config/.env.example из архива${NC}"
        exit 1
    fi

    gen_secret() {
        local len=$1
        # убираем символы, которые могут ломать парсинг .env
        openssl rand -base64 $((len*2)) | tr -dc 'A-Za-z0-9' | head -c ${len}
    }

    set_secret_if_missing() {
        local var=$1
        local len=$2
        if grep -q "^${var}=" "$ENV_FILE"; then
            local cur
            cur=$(grep "^${var}=" "$ENV_FILE" | head -n1 | cut -d'=' -f2-)
            if [ -z "$cur" ] || [ "$cur" = "CHANGE_ME" ]; then
                local val
                val=$(gen_secret $len)
                sed -i "s/^${var}=.*/${var}=${val}/" "$ENV_FILE"
            fi
        fi
    }

    # Генерируем основные секреты
    set_secret_if_missing "POSTGRES_PASSWORD" 24
    set_secret_if_missing "KEYCLOAK_ADMIN_PASSWORD" 24
    set_secret_if_missing "GRAFANA_ADMIN_PASSWORD" 20
    set_secret_if_missing "REDMINE_SECRET_KEY" 32
    set_secret_if_missing "REDMINE_DB_PASSWORD" 24
}
generate_env

# Check if project archive exists
if [ -f /tmp/Ceres-deploy.zip ]; then
    echo "  Extracting project archive..."
    
    # Deploy to each VM
    for VM_IP in $VM1_IP $VM2_IP $VM3_IP; do
        echo "  Deploying to $VM_IP..."
        scp -o StrictHostKeyChecking=no /tmp/Ceres-deploy.zip root@$VM_IP:/tmp/
        scp -o StrictHostKeyChecking=no "$ENV_FILE" root@$VM_IP:/tmp/.env.generated
        
        ssh root@$VM_IP bash << 'DEPLOYEOF'
mkdir -p /opt/Ceres
cd /opt/Ceres
unzip -q /tmp/Ceres-deploy.zip
[ -d "Ceres" ] && mv Ceres/* . && rmdir Ceres
find . -name "*.sh" -exec sed -i 's/\r$//' {} \; -exec chmod +x {} \;
cd config
    # Используем заранее сгенерированный .env
    cp /tmp/.env.generated .env
DEPLOYEOF
        
        echo -e "${GREEN}✅ Project deployed to $VM_IP${NC}"
    done
else
    echo -e "${YELLOW}⚠️  No project archive found at /tmp/Ceres-deploy.zip${NC}"
    echo "  Please upload the project archive first"
fi

# ============================================================================
# PHASE 5: START SERVICES ON EACH VM
# ============================================================================

echo ""
echo -e "${YELLOW}[Phase 5/6] Starting services on each VM...${NC}"

# VM1 (Core): PostgreSQL, Redis, Keycloak
echo "  Starting CORE services on VM1 ($VM1_IP)..."
ssh root@$VM1_IP bash << 'VM1EOF'
cd /opt/Ceres/config
docker compose -f compose/base.yml -f compose/core.yml up -d
# Wait for PostgreSQL to be ready
sleep 30
# Add Keycloak from apps
docker compose -f compose/base.yml -f compose/core.yml -f compose/apps.yml up -d keycloak
VM1EOF
echo -e "${GREEN}✅ CORE services started on VM1${NC}"

# VM2 (Apps): Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
echo "  Starting APPS services on VM2 ($VM2_IP)..."
ssh root@$VM2_IP bash << 'VM2EOF'
cd /opt/Ceres/config
# Update remote PostgreSQL connection
sed -i "s/postgres:5432/192.168.1.10:5432/g" compose/apps.yml
sed -i "s/redis:6379/192.168.1.10:6379/g" compose/apps.yml

docker compose -f compose/base.yml -f compose/apps.yml up -d
VM2EOF
echo -e "${GREEN}✅ APPS services started on VM2${NC}"

# VM3 (Monitoring/Edge): Prometheus, Grafana, exporters, Portainer, Caddy
echo "  Starting MONITORING services on VM3 ($VM3_IP)..."
ssh root@$VM3_IP bash << 'VM3EOF'
cd /opt/Ceres/config
docker compose -f compose/base.yml -f compose/monitoring.yml -f compose/ops.yml -f compose/edge.yml up -d
VM3EOF
echo -e "${GREEN}✅ MONITORING services started on VM3${NC}"

# ============================================================================
# PHASE 6: VERIFICATION
# ============================================================================

echo ""
echo -e "${YELLOW}[Phase 6/6] Verifying deployment...${NC}"

echo ""
echo "VM1 (CORE) services:"
ssh root@$VM1_IP "docker ps --format 'table {{.Names}}\t{{.Status}}'"

echo ""
echo "VM2 (APPS) services:"
ssh root@$VM2_IP "docker ps --format 'table {{.Names}}\t{{.Status}}'"

echo ""
echo "VM3 (MONITORING) services:"
ssh root@$VM3_IP "docker ps --format 'table {{.Names}}\t{{.Status}}'"

# ============================================================================
# DEPLOYMENT COMPLETE
# ============================================================================

echo ""
echo -e "${CYAN}"
echo "================================================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "================================================================"
echo -e "${NC}"
echo ""
echo -e "${GREEN}Virtual Machines:${NC}"
echo "  VM1 (Core):       $VM1_IP - PostgreSQL, Redis, Keycloak"
echo "  VM2 (Apps):       $VM2_IP - Nextcloud, Gitea, Mattermost, Redmine, Wiki.js"
echo "  VM3 (Monitoring): $VM3_IP - Prometheus, Grafana, exporters, Portainer, Caddy"
echo ""
echo -e "${GREEN}Access URLs (через VM3 reverse proxy):${NC}"
echo "  Keycloak:   https://auth.ceres.local (→ $VM1_IP)"
echo "  Nextcloud:  https://nextcloud.ceres.local (→ $VM2_IP)"
echo "  Gitea:      https://gitea.ceres.local (→ $VM2_IP)"
echo "  Mattermost: https://mattermost.ceres.local (→ $VM2_IP)"
echo "  Redmine:    https://redmine.ceres.local (→ $VM2_IP)"
echo "  Wiki.js:    https://wiki.ceres.local (→ $VM2_IP)"
echo "  Grafana:    https://grafana.ceres.local (→ $VM3_IP)"
echo "  Portainer:  https://portainer.ceres.local (→ $VM3_IP)"
echo ""
echo -e "${GREEN}Add to your hosts file:${NC}"
echo "  192.168.1.12  auth.ceres.local nextcloud.ceres.local gitea.ceres.local"
echo "  192.168.1.12  mattermost.ceres.local redmine.ceres.local wiki.ceres.local"
echo "  192.168.1.12  grafana.ceres.local portainer.ceres.local"
echo ""
echo "================================================================"
echo ""
