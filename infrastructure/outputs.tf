# ============================================================================
# CERES Terraform Outputs
# ============================================================================

# AWS Outputs
output "aws_cluster_name" {
  description = "Имя AWS EKS кластера"
  value       = try(module.aws_eks[0].cluster_id, "")
}

output "aws_cluster_endpoint" {
  description = "Endpoint AWS EKS кластера"
  value       = try(module.aws_eks[0].cluster_endpoint, "")
  sensitive   = true
}

output "aws_vpc_id" {
  description = "ID AWS VPC"
  value       = try(module.aws_vpc[0].vpc_id, "")
}

output "aws_db_endpoint" {
  description = "RDS Database endpoint"
  value       = try(aws_db_instance.postgres[0].endpoint, "")
  sensitive   = true
}

# Azure Outputs
output "azure_cluster_name" {
  description = "Имя Azure AKS кластера"
  value       = try(azurerm_kubernetes_cluster.aks[0].name, "")
}

output "azure_cluster_endpoint" {
  description = "Endpoint Azure AKS кластера"
  value       = try(azurerm_kubernetes_cluster.aks[0].kube_config[0].host, "")
  sensitive   = true
}

# GCP Outputs
output "gcp_cluster_name" {
  description = "Имя GCP GKE кластера"
  value       = try(google_container_cluster.gke[0].name, "")
}

output "gcp_cluster_endpoint" {
  description = "Endpoint GCP GKE кластера"
  value       = try(google_container_cluster.gke[0].endpoint, "")
  sensitive   = true
}

# Proxmox Outputs
output "proxmox_cluster_nodes" {
  description = "IP адреса Proxmox узлов"
  value       = try(proxmox_vm_qemu.k3s_nodes[*].default_ipv4_address, [])
}

# All Clusters Summary
output "deployed_clusters" {
  description = "Список развернутых кластеров"
  value = {
    aws     = var.aws_enabled ? "✓ AWS EKS" : "✗ disabled"
    azure   = var.azure_enabled ? "✓ Azure AKS" : "✗ disabled"
    gcp     = var.gcp_enabled ? "✓ GCP GKE" : "✗ disabled"
    proxmox = var.proxmox_enabled ? "✓ Proxmox k3s" : "✗ disabled"
  }
}

output "services_deployed" {
  description = "Список развернутых сервисов"
  value = {
    core        = ["PostgreSQL", "Redis", "Keycloak"]
    applications = ["GitLab", "Nextcloud", "Mattermost", "Redmine", "Wiki.js"]
    monitoring  = var.enable_monitoring ? ["Prometheus", "Grafana", "Alertmanager"] : []
    logging     = var.enable_logging ? ["Loki", "Promtail"] : []
    tracing     = var.enable_tracing ? ["Jaeger", "Tempo"] : []
    networking  = ["Caddy", "WireGuard"]
    additional  = ["Mayan EDMS", "OnlyOffice", "Zulip"]
  }
}

output "access_urls" {
  description = "URLs для доступа к сервисам"
  value = {
    keycloak = "https://keycloak.${var.domain_name}"
    gitlab   = "https://gitlab.${var.domain_name}"
    nextcloud = "https://nextcloud.${var.domain_name}"
    mattermost = "https://mattermost.${var.domain_name}"
    redmine  = "https://redmine.${var.domain_name}"
    wiki     = "https://wiki.${var.domain_name}"
    prometheus = "https://prometheus.${var.domain_name}"
    grafana  = "https://grafana.${var.domain_name}"
    mayan    = "https://mayan.${var.domain_name}"
    onlyoffice = "https://office.${var.domain_name}"
    zulip    = "https://zulip.${var.domain_name}"
  }
}

output "kubeconfig_aws" {
  description = "AWS kubeconfig"
  value       = try(base64decode(module.aws_eks[0].kubeconfig), "")
  sensitive   = true
}

output "kubeconfig_azure" {
  description = "Azure kubeconfig"
  value       = try(azurerm_kubernetes_cluster.aks[0].kube_config_raw, "")
  sensitive   = true
}

output "kubeconfig_gcp" {
  description = "GCP kubeconfig"
  value       = try(google_container_cluster.gke[0].master_auth[0].client_certificate, "")
  sensitive   = true
}
