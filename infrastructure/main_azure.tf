# ============================================================================
# CERES Azure Infrastructure Module
# ============================================================================

provider "azurerm" {
  features {}

  skip_provider_registration = false

  subscription_id = var.azure_subscription_id
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "ceres" {
  count    = var.azure_enabled ? 1 : 0
  name     = "${var.project_name}-rg"
  location = var.azure_location

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ============================================================================
# Virtual Network
# ============================================================================

resource "azurerm_virtual_network" "ceres" {
  count               = var.azure_enabled ? 1 : 0
  name                = "${var.project_name}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.ceres[0].location
  resource_group_name = azurerm_resource_group.ceres[0].name

  tags = {
    Name = "${var.project_name}-vnet"
  }
}

resource "azurerm_subnet" "aks" {
  count                = var.azure_enabled ? 1 : 0
  name                 = "${var.project_name}-aks-subnet"
  resource_group_name  = azurerm_resource_group.ceres[0].name
  virtual_network_name = azurerm_virtual_network.ceres[0].name
  address_prefixes     = ["10.1.0.0/22"]
}

resource "azurerm_subnet" "database" {
  count                = var.azure_enabled ? 1 : 0
  name                 = "${var.project_name}-db-subnet"
  resource_group_name  = azurerm_resource_group.ceres[0].name
  virtual_network_name = azurerm_virtual_network.ceres[0].name
  address_prefixes     = ["10.1.10.0/24"]

  delegation {
    name = "dlg-Microsoft.DBforPostgreSQL-flexibleServers"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ============================================================================
# Network Security Groups
# ============================================================================

resource "azurerm_network_security_group" "aks" {
  count               = var.azure_enabled ? 1 : 0
  name                = "${var.project_name}-aks-nsg"
  location            = azurerm_resource_group.ceres[0].location
  resource_group_name = azurerm_resource_group.ceres[0].name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowKubelet"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "10.1.0.0/16"
    destination_address_prefix = "*"
  }

  tags = {
    Name = "${var.project_name}-aks-nsg"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  count                     = var.azure_enabled ? 1 : 0
  subnet_id                 = azurerm_subnet.aks[0].id
  network_security_group_id = azurerm_network_security_group.aks[0].id
}

# ============================================================================
# AKS Kubernetes Cluster
# ============================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.azure_enabled ? 1 : 0
  name                = var.cluster_name
  location            = azurerm_resource_group.ceres[0].location
  resource_group_name = azurerm_resource_group.ceres[0].name
  dns_prefix          = "${var.project_name}-aks"
  kubernetes_version  = var.kubernetes_version

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "10.10.0.0/16"
    dns_service_ip     = "10.10.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  default_node_pool {
    name                 = "default"
    node_count           = var.azure_node_count
    vm_size              = var.azure_vm_size
    os_disk_size_gb      = 128
    vnet_subnet_id       = azurerm_subnet.aks[0].id
    enable_auto_scaling  = true
    min_count            = var.azure_node_count
    max_count            = var.azure_node_count * 2
    enable_node_public_ip = false
  }

  identity {
    type = "SystemAssigned"
  }

  addon_profile {
    http_application_routing {
      enabled = false
    }

    kube_dashboard {
      enabled = false
    }

    azure_monitor {
      enabled = var.enable_monitoring
    }

    azure_policy {
      enabled = true
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [azurerm_subnet_network_security_group_association.aks]
}

# ============================================================================
# Azure Database for PostgreSQL
# ============================================================================

resource "azurerm_postgresql_flexible_server" "postgres" {
  count               = var.azure_enabled ? 1 : 0
  name                = "${var.project_name}-postgres"
  location            = azurerm_resource_group.ceres[0].location
  resource_group_name = azurerm_resource_group.ceres[0].name

  administrator_login    = "ceres"
  administrator_password = random_password.azure_postgres[0].result

  sku_name   = "B_Standard_B2s"
  storage_mb = var.postgres_storage_size * 1024
  version    = var.postgres_version

  backup_retention_days        = 30
  geo_redundant_backup_enabled = true
  create_mode                  = "Default"

  delegated_subnet_id = azurerm_subnet.database[0].id

  tags = {
    Name = "${var.project_name}-postgres"
  }

  depends_on = [azurerm_subnet.database]
}

resource "random_password" "azure_postgres" {
  count            = var.azure_enabled ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# Azure Cache for Redis
# ============================================================================

resource "azurerm_redis_cache" "redis" {
  count               = var.azure_enabled ? 1 : 0
  name                = "${var.project_name}-redis"
  location            = azurerm_resource_group.ceres[0].location
  resource_group_name = azurerm_resource_group.ceres[0].name

  capacity            = 2
  family              = "C"
  sku_name            = "Premium"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  tags = {
    Name = "${var.project_name}-redis"
  }
}

# ============================================================================
# Variables for Azure
# ============================================================================

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "azure_node_count" {
  description = "Количество worker nodes"
  type        = number
  default     = 3
}
