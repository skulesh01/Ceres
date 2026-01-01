terraform {
  required_version = ">= 1.5"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }

  # For team collaboration, use remote backend:
  # backend "s3" {
  #   bucket = "ceres-terraform-state"
  #   key    = "proxmox/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url
  pm_user         = var.proxmox_user
  pm_password     = var.proxmox_password
  pm_tls_insecure = var.proxmox_tls_insecure
  pm_timeout      = 600
  pm_parallel     = 2
}

# Data source for existing template
data "proxmox_virtual_environment_vms" "debian_template" {
  node_name = var.proxmox_node
  
  filter {
    name   = "name"
    values = [var.template_name]
  }
}

# Core VM - PostgreSQL, Redis, Keycloak
resource "proxmox_vm_qemu" "core" {
  name        = "ceres-core-${var.environment}"
  target_node = var.proxmox_node
  clone       = var.template_name
  vmid        = var.vmid_core
  
  cores   = var.core_vm_cores
  sockets = 1
  memory  = var.core_vm_memory
  
  disk {
    size    = "${var.core_vm_disk}G"
    type    = "scsi"
    storage = var.proxmox_storage
    ssd     = 1
    discard = "on"
  }
  
  network {
    model  = "virtio"
    bridge = var.proxmox_bridge
  }
  
  ipconfig0 = "ip=${var.core_vm_ip}/24,gw=${var.network_gateway}"
  
  os_type   = "cloud-init"
  ciuser    = var.ssh_user
  cipassword = var.ssh_password
  sshkeys   = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [
      network,
      disk,
    ]
  }
  
  tags = "ceres,core,${var.environment}"
}

# Apps VM - Nextcloud, Gitea, Mattermost, Redmine, Wiki.js
resource "proxmox_vm_qemu" "apps" {
  name        = "ceres-apps-${var.environment}"
  target_node = var.proxmox_node
  clone       = var.template_name
  vmid        = var.vmid_apps
  
  cores   = var.apps_vm_cores
  sockets = 1
  memory  = var.apps_vm_memory
  
  disk {
    size    = "${var.apps_vm_disk}G"
    type    = "scsi"
    storage = var.proxmox_storage
    ssd     = 1
    discard = "on"
  }
  
  network {
    model  = "virtio"
    bridge = var.proxmox_bridge
  }
  
  ipconfig0 = "ip=${var.apps_vm_ip}/24,gw=${var.network_gateway}"
  
  os_type   = "cloud-init"
  ciuser    = var.ssh_user
  cipassword = var.ssh_password
  sshkeys   = var.ssh_public_key
  
  depends_on = [proxmox_vm_qemu.core]
  
  tags = "ceres,apps,${var.environment}"
}

# Edge VM - Caddy, Prometheus, Grafana, Monitoring
resource "proxmox_vm_qemu" "edge" {
  name        = "ceres-edge-${var.environment}"
  target_node = var.proxmox_node
  clone       = var.template_name
  vmid        = var.vmid_edge
  
  cores   = var.edge_vm_cores
  sockets = 1
  memory  = var.edge_vm_memory
  
  disk {
    size    = "${var.edge_vm_disk}G"
    type    = "scsi"
    storage = var.proxmox_storage
    ssd     = 1
    discard = "on"
  }
  
  network {
    model  = "virtio"
    bridge = var.proxmox_bridge
  }
  
  ipconfig0 = "ip=${var.edge_vm_ip}/24,gw=${var.network_gateway}"
  
  os_type   = "cloud-init"
  ciuser    = var.ssh_user
  cipassword = var.ssh_password
  sshkeys   = var.ssh_public_key
  
  depends_on = [proxmox_vm_qemu.core, proxmox_vm_qemu.apps]
  
  tags = "ceres,edge,monitoring,${var.environment}"
}

# Outputs
output "core_vm_ip" {
  value       = var.core_vm_ip
  description = "IP address of Core VM"
}

output "apps_vm_ip" {
  value       = var.apps_vm_ip
  description = "IP address of Apps VM"
}

output "edge_vm_ip" {
  value       = var.edge_vm_ip
  description = "IP address of Edge VM"
}

output "ssh_connection_core" {
  value       = "ssh ${var.ssh_user}@${var.core_vm_ip}"
  description = "SSH connection command for Core VM"
}

output "ssh_connection_apps" {
  value       = "ssh ${var.ssh_user}@${var.apps_vm_ip}"
  description = "SSH connection command for Apps VM"
}

output "ssh_connection_edge" {
  value       = "ssh ${var.ssh_user}@${var.edge_vm_ip}"
  description = "SSH connection command for Edge VM"
}
