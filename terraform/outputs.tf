# ==========================================
# VM Outputs
# ==========================================
output "vm_details" {
  description = "Details of all created VMs"
  value = {
    for key, vm in proxmox_vm_qemu.ceres_vms : key => {
      name       = vm.name
      vmid       = vm.vmid
      ip_address = vm.default_ipv4_address
      cores      = vm.cores
      memory     = vm.memory
      status     = "running"
    }
  }
}

# ==========================================
# IP Addresses
# ==========================================
## Outputs for VM IPs are defined in main.tf via variables
## to avoid duplicate definitions. Removing duplicates here.

# ==========================================
# Connection Information
# ==========================================
output "ssh_commands" {
  description = "SSH commands to connect to VMs"
  value = {
    core = "ssh ${var.ssh_user}@${proxmox_vm_qemu.ceres_vms["core"].default_ipv4_address}"
    apps = "ssh ${var.ssh_user}@${proxmox_vm_qemu.ceres_vms["apps"].default_ipv4_address}"
    edge = "ssh ${var.ssh_user}@${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
  }
}

# ==========================================
# DNS Configuration
# ==========================================
output "dns_records" {
  description = "DNS A records to create"
  value = {
    wildcard = "*.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
    auth     = "auth.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
    gitlab   = "gitlab.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
    zulip    = "zulip.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
    nextcloud = "nextcloud.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
    grafana  = "grafana.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}"
  }
}

# ==========================================
# Ansible Inventory Path
# ==========================================
output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = local_file.ansible_inventory.filename
}

# ==========================================
# Next Steps
# ==========================================
output "next_steps" {
  description = "Commands to run after Terraform apply"
  value = <<-EOT
  
  ✅ CERES Infrastructure Created!
  
  📡 IP Addresses:
     Core: ${proxmox_vm_qemu.ceres_vms["core"].default_ipv4_address}
     Apps: ${proxmox_vm_qemu.ceres_vms["apps"].default_ipv4_address}
     Edge: ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}
  
  🔑 SSH Access:
     ssh ${var.ssh_user}@${proxmox_vm_qemu.ceres_vms["core"].default_ipv4_address}
  
  📋 Next Steps:
     1. Configure DNS:
        Add A record: *.${var.domain} -> ${proxmox_vm_qemu.ceres_vms["edge"].default_ipv4_address}
     
     2. Run Ansible:
        cd ../ansible
        ansible-playbook -i inventory/production.yml playbooks/deploy-ceres.yml
     
     3. Access services:
        https://auth.${var.domain}
        https://gitlab.${var.domain}
        https://grafana.${var.domain}
  EOT
}
