# Proxmox connection
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.3:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "proxmox_storage" {
  description = "Proxmox storage name"
  type        = string
  default     = "local-lvm"
}

variable "proxmox_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

# Template
variable "template_name" {
  description = "VM template name"
  type        = string
  default     = "debian-12-cloud"
}

# Environment
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# VM IDs
variable "vmid_core" {
  description = "VMID for Core VM"
  type        = number
  default     = 100
}

variable "vmid_apps" {
  description = "VMID for Apps VM"
  type        = number
  default     = 101
}

variable "vmid_edge" {
  description = "VMID for Edge VM"
  type        = number
  default     = 102
}

# Core VM resources
variable "core_vm_cores" {
  description = "CPU cores for Core VM"
  type        = number
  default     = 4
}

variable "core_vm_memory" {
  description = "Memory for Core VM (MB)"
  type        = number
  default     = 8192
}

variable "core_vm_disk" {
  description = "Disk size for Core VM (GB)"
  type        = number
  default     = 50
}

variable "core_vm_ip" {
  description = "IP address for Core VM"
  type        = string
  default     = "192.168.1.10"
}

# Apps VM resources
variable "apps_vm_cores" {
  description = "CPU cores for Apps VM"
  type        = number
  default     = 4
}

variable "apps_vm_memory" {
  description = "Memory for Apps VM (MB)"
  type        = number
  default     = 8192
}

variable "apps_vm_disk" {
  description = "Disk size for Apps VM (GB)"
  type        = number
  default     = 80
}

variable "apps_vm_ip" {
  description = "IP address for Apps VM"
  type        = string
  default     = "192.168.1.11"
}

# Edge VM resources
variable "edge_vm_cores" {
  description = "CPU cores for Edge VM"
  type        = number
  default     = 2
}

variable "edge_vm_memory" {
  description = "Memory for Edge VM (MB)"
  type        = number
  default     = 4096
}

variable "edge_vm_disk" {
  description = "Disk size for Edge VM (GB)"
  type        = number
  default     = 40
}

variable "edge_vm_ip" {
  description = "IP address for Edge VM"
  type        = string
  default     = "192.168.1.12"
}

# Network
variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

# SSH
variable "ssh_user" {
  description = "SSH user for VMs"
  type        = string
  default     = "ceres"
}

variable "ssh_password" {
  description = "SSH password for VMs"
  type        = string
  sensitive   = true
  default     = ""
}

variable "ssh_public_key" {
  description = "SSH public key for VMs"
  type        = string
}
