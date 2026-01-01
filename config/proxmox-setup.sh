#!/bin/bash
# 🚀 CERES Infrastructure - Proxmox + Kubernetes Deployment
# This script sets up a complete Kubernetes cluster on Proxmox
# Usage: Run on Proxmox host to create VMs and K8s cluster

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   CERES Kubernetes Cluster Setup for Proxmox              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuration
CLUSTER_NAME="ceres-k8s"
MASTER_NODE="ceres-k8s-master"
WORKER_COUNT=2
WORKER_PREFIX="ceres-k8s-worker"
VMID_START=100
STORAGE="local-lvm"
NETWORK="vmbr0"
GATEWAY="192.168.1.1"
NETMASK="24"
DNS="8.8.8.8"

# Ubuntu cloud image
CLOUD_IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
CLOUD_IMAGE_LOCAL="/var/lib/vz/images/jammy-server-cloudimg-amd64.img"

echo "[1/5] Downloading Ubuntu Cloud Image..."
if [ ! -f "$CLOUD_IMAGE_LOCAL" ]; then
    wget -q -O "$CLOUD_IMAGE_LOCAL" "$CLOUD_IMAGE_URL"
fi

echo "[2/5] Creating master node VM..."
# Create master node
VMID=$VMID_START
qm create $VMID \
    --name "$MASTER_NODE" \
    --memory 4096 \
    --cores 4 \
    --sockets 1 \
    --net0 virtio,bridge=$NETWORK \
    --ipconfig0 "ip=192.168.1.100/24,gw=$GATEWAY" \
    --nameserver "$DNS" \
    --searchdomain "ceres.local"

# Add cloud image
qm importdisk $VMID "$CLOUD_IMAGE_LOCAL" $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VMID-disk-0
qm set $VMID --boot c --bootdisk scsi0
qm set $VMID --ide2 $STORAGE:cloudinit

echo "[3/5] Creating worker node VMs..."
for i in $(seq 1 $WORKER_COUNT); do
    VMID=$((VMID_START + i))
    WORKER_IP=$((100 + i))
    echo "  Creating worker-$i (192.168.1.$WORKER_IP)..."
    
    qm create $VMID \
        --name "$WORKER_PREFIX-$i" \
        --memory 4096 \
        --cores 4 \
        --sockets 1 \
        --net0 virtio,bridge=$NETWORK \
        --ipconfig0 "ip=192.168.1.$WORKER_IP/24,gw=$GATEWAY" \
        --nameserver "$DNS" \
        --searchdomain "ceres.local"
    
    qm importdisk $VMID "$CLOUD_IMAGE_LOCAL" $STORAGE
    qm set $VMID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VMID-disk-0
    qm set $VMID --boot c --bootdisk scsi0
    qm set $VMID --ide2 $STORAGE:cloudinit
done

echo "[4/5] Starting VMs..."
for VMID in $(seq $VMID_START $((VMID_START + WORKER_COUNT))); do
    qm start $VMID
    echo "  VM $VMID started"
done

echo "[5/5] Waiting for VMs to boot..."
sleep 30

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              VMs Created Successfully!                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "1. Wait for VMs to fully boot (2-3 minutes)"
echo "2. SSH into master node:"
echo "   ssh ubuntu@192.168.1.100"
echo ""
echo "3. Run kubernetes setup script on master:"
echo "   curl -fsSL https://raw.githubusercontent.com/your-repo/ceres/main/k8s-setup-master.sh | bash"
echo ""
echo "4. Join workers to cluster:"
echo "   (follow kubeadm join command from master setup)"
echo ""
