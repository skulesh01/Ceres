# CERES v3.0.0 - Multi-Cloud Terraform Modules
# AWS, Azure, GCP, Hybrid, Edge deployments
# Infrastructure-as-Code для всех облачных платформ

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# AWS Provider Configuration
# ============================================================================

variable "aws_region" {
  description = "AWS регион"
  type        = string
  default     = "eu-west-1"
}

variable "aws_availability_zones" {
  description = "Availability zones для HA"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "ceres"
      ManagedBy   = "terraform"
      Version     = "v3.0.0"
    }
  }
}

# VPC для AWS
module "aws_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "ceres-vpc"
  cidr = "10.0.0.0/16"

  azs             = var.aws_availability_zones
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]

  # NAT Gateway для private subnets
  enable_nat_gateway   = true
  single_nat_gateway   = false  # HA - по одному per AZ
  enable_vpn_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Name = "ceres-vpc"
  }
}

# EKS Cluster на AWS
module "aws_eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "ceres-prod"
  cluster_version = "1.28"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id     = module.aws_vpc.vpc_id
  subnet_ids = concat(module.aws_vpc.private_subnets, module.aws_vpc.public_subnets)

  # IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Managed Node Groups
  eks_managed_node_groups = {
    # System nodes
    system = {
      name            = "system-nodes"
      use_name_prefix = true
      capacity_type   = "on_demand"

      instance_types = ["t3.large"]
      desired_size   = 3
      min_size       = 3
      max_size       = 6

      disk_size = 50

      labels = {
        Environment = "production"
        NodeType    = "system"
      }

      taints = [
        {
          key    = "system"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      tags = {
        "karpenter.sh/discovery" = "ceres-prod"
      }
    }

    # General purpose nodes
    general = {
      name            = "general-nodes"
      use_name_prefix = true
      capacity_type   = "spot"  # Cost optimization

      instance_types = ["c5.xlarge", "c5.2xlarge", "m5.xlarge"]
      desired_size   = 5
      min_size       = 3
      max_size       = 20

      disk_size = 100

      labels = {
        Environment = "production"
        NodeType    = "general"
      }

      tags = {
        "karpenter.sh/discovery" = "ceres-prod"
      }
    }

    # High-memory nodes для databases
    memory = {
      name            = "memory-nodes"
      use_name_prefix = true
      capacity_type   = "on_demand"

      instance_types = ["r5.2xlarge", "r5.4xlarge"]
      desired_size   = 2
      min_size       = 2
      max_size       = 8

      disk_size = 200

      labels = {
        Environment = "production"
        NodeType    = "memory"
      }
    }
  }

  manage_aws_auth_configmap = true
}

# RDS PostgreSQL с Multi-AZ
resource "aws_db_instance" "postgres" {
  identifier            = "ceres-postgres"
  engine                = "postgres"
  engine_version        = "15.3"
  instance_class        = "db.r5.2xlarge"  # Production grade
  allocated_storage     = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.rds.arn

  # Multi-AZ for HA
  multi_az = true

  # Backups
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  copy_tags_to_snapshot  = true
  skip_final_snapshot    = false
  final_snapshot_identifier = "ceres-postgres-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Network
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.postgres.id]

  # Database config
  db_name  = "ceres"
  username = "ceresadmin"
  password = random_password.postgres_password.result

  # Monitoring
  monitoring_interval          = 60
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn
  enable_cloudwatch_logs_exports = ["postgresql"]

  # Performance Insights
  performance_insights_enabled    = true
  performance_insights_retention_period = 7

  parameter_group_name = aws_db_parameter_group.postgres.name

  tags = {
    Name = "ceres-postgres"
  }
}

# ElastiCache Redis для кэширования
resource "aws_elasticache_replication_group" "redis" {
  replication_group_description = "CERES Redis cluster"
  engine                        = "redis"
  engine_version                = "7.0"
  node_type                      = "cache.r6g.xlarge"
  num_cache_clusters             = 3  # HA - primary + 2 replicas
  automatic_failover_enabled      = true

  port = 6379

  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  # Encryption at rest and in transit
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                = random_password.redis_auth_token.result
  auth_token_update_strategy = "ROTATE"

  # Backup
  snapshot_retention_limit = 30
  snapshot_window         = "03:00-05:00"

  # Maintenance
  maintenance_window = "sun:05:00-sun:07:00"
  notification_topic_arn = aws_sns_topic.redis_alerts.arn

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = {
    Name = "ceres-redis"
  }
}

# ============================================================================
# Azure Provider Configuration
# ============================================================================

variable "azure_region" {
  description = "Azure регион"
  type        = string
  default     = "westeurope"
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

# Azure Resource Group
resource "azurerm_resource_group" "ceres" {
  name     = "rg-ceres-prod"
  location = var.azure_region
}

# Azure Virtual Network
resource "azurerm_virtual_network" "ceres" {
  name                = "vnet-ceres"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.ceres.location
  resource_group_name = azurerm_resource_group.ceres.name
}

# Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "ceres" {
  name                = "ceres-aks"
  location            = azurerm_resource_group.ceres.location
  resource_group_name = azurerm_resource_group.ceres.name
  dns_prefix          = "ceres"
  kubernetes_version  = "1.28"

  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v5"
    vnet_subnet_id      = azurerm_subnet.ceres.id
    max_surge           = 1
    availability_zones  = ["1", "2", "3"]
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 10
    type                = "VirtualMachineScaleSets"
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    managed                = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
    admin_group_object_ids = [azurerm_ad_group.kubernetes_admins.object_id]
  }

  # Network policy
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.2.0.0/16"
    dns_service_ip    = "10.2.0.10"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # Key Vault integration
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "production"
  }
}

# Azure Database for PostgreSQL
resource "azurerm_postgresql_flexible_server" "ceres" {
  name                   = "ceres-postgres"
  resource_group_name    = azurerm_resource_group.ceres.name
  location               = azurerm_resource_group.ceres.location
  administrator_login    = "ceresadmin"
  administrator_password = random_password.azure_postgres_password.result
  version                = "15"

  storage_mb    = 102400  # 100 GB
  sku_name      = "Standard_D4s_v3"
  
  backup_retention_days = 30
  geo_redundant_backup_enabled = true
  high_availability_enabled = true

  ssl_enforcement_enabled = true
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"

  tags = {
    Name = "ceres-postgres"
  }
}

# ============================================================================
# Google Cloud Provider Configuration
# ============================================================================

variable "gcp_project" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP регион"
  type        = string
  default     = "europe-west1"
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# GKE Cluster
resource "google_container_cluster" "ceres" {
  name     = "ceres-gke"
  location = var.gcp_region

  initial_node_count       = 3
  remove_default_node_pool = true

  network    = google_compute_network.ceres.name
  subnetwork = google_compute_subnetwork.ceres.name

  # GKE Autopilot (fully managed)
  enable_autopilot = true

  # Security
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }

  # Monitoring
  monitoring_service = "monitoring.googleapis.com/kubernetes"
  logging_service    = "logging.googleapis.com/kubernetes"

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }
}

# Cloud SQL PostgreSQL
resource "google_sql_database_instance" "ceres" {
  name             = "ceres-postgres"
  database_version = "POSTGRES_15"
  region           = var.gcp_region
  deletion_protection = true

  settings {
    tier      = "db-custom-4-16384"  # 4 vCPU, 16 GB memory
    disk_type = "PD_SSD"
    disk_size = 100

    # HA configuration
    availability_type = "REGIONAL"
    
    # Backup
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    # Database flags for performance
    database_flags {
      name  = "max_connections"
      value = "500"
    }
    database_flags {
      name  = "shared_buffers"
      value = "262144"
    }

    # Maintenance
    maintenance_window {
      kind           = "MAINTENANCE_WINDOW_KIND_AUTOMATIC"
      day            = 0  # Sunday
      hour           = 5
      update_track   = "stable"
    }

    # Insights configuration
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
    }
  }

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# ============================================================================
# Hybrid & Edge Configuration (共通設定)
# ============================================================================

# Terraform variables for hybrid/edge deployments
variable "enable_hybrid_deployment" {
  description = "Enable hybrid cloud deployment"
  type        = bool
  default     = false
}

variable "edge_locations" {
  description = "Edge computing locations"
  type = list(object({
    name     = string
    provider = string  # aws, azure, gcp, on-prem
    region   = string
  }))
  default = []
}

# Edge cluster configuration
resource "local_file" "edge_cluster_config" {
  count    = var.enable_hybrid_deployment ? length(var.edge_locations) : 0
  filename = "${path.module}/edge-clusters/${var.edge_locations[count.index].name}-kubeconfig.yaml"
  
  content = templatefile("${path.module}/templates/edge-kubeconfig.tpl", {
    cluster_name = var.edge_locations[count.index].name
    api_endpoint = "https://${var.edge_locations[count.index].name}.edge.ceres.io:6443"
  })
}

# ============================================================================
# Outputs
# ============================================================================

output "aws_eks_cluster_endpoint" {
  description = "AWS EKS cluster endpoint"
  value       = module.aws_eks.cluster_endpoint
}

output "aws_eks_cluster_name" {
  description = "AWS EKS cluster name"
  value       = module.aws_eks.cluster_name
}

output "azure_aks_kubeconfig" {
  description = "Azure AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.ceres.kube_config[0].raw_config
  sensitive   = true
}

output "gcp_gke_cluster_name" {
  description = "GCP GKE cluster name"
  value       = google_container_cluster.ceres.name
}

output "gcp_gke_endpoint" {
  description = "GCP GKE endpoint"
  value       = google_container_cluster.ceres.endpoint
}

# Data source для текущего AWS account
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source для Azure
data "azurerm_client_config" "current" {}

# RDS subnet group
resource "aws_db_subnet_group" "postgres" {
  name       = "ceres-postgres-subnet"
  subnet_ids = module.aws_vpc.database_subnets
}

# RDS parameter group
resource "aws_db_parameter_group" "postgres" {
  name   = "ceres-postgres-params"
  family = "postgres15"

  parameter {
    name  = "log_statement"
    value = "all"
  }
  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }
}

# Security Group для RDS
resource "aws_security_group" "postgres" {
  name_prefix = "ceres-postgres-"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group для Redis
resource "aws_security_group" "redis" {
  name_prefix = "ceres-redis-"
  vpc_id      = module.aws_vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ElastiCache subnet group
resource "aws_elasticache_subnet_group" "redis" {
  name       = "ceres-redis-subnet"
  subnet_ids = module.aws_vpc.database_subnets
}

# ElastiCache parameter group
resource "aws_elasticache_parameter_group" "redis" {
  name   = "ceres-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/ceres-redis/slow-log"
  retention_in_days = 30
}

# SNS Topic для Redis alerts
resource "aws_sns_topic" "redis_alerts" {
  name = "ceres-redis-alerts"
}

# Random passwords
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

resource "random_password" "azure_postgres_password" {
  length  = 32
  special = true
}

# KMS Keys для encryption
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# Azure Subnet
resource "azurerm_subnet" "ceres" {
  name                 = "subnet-ceres"
  resource_group_name  = azurerm_resource_group.ceres.name
  virtual_network_name = azurerm_virtual_network.ceres.name
  address_prefixes     = ["10.1.0.0/24"]
}

# Azure AD Group for Kubernetes admins
resource "azurerm_ad_group" "kubernetes_admins" {
  display_name     = "Kubernetes Admins"
  mail_nickname    = "k8s-admins"
  security_enabled = true
}

# GCP Network
resource "google_compute_network" "ceres" {
  name                    = "ceres-network"
  auto_create_subnetworks = false
}

# GCP Subnetwork
resource "google_compute_subnetwork" "ceres" {
  name          = "ceres-subnetwork"
  ip_cidr_range = "10.3.0.0/20"
  region        = var.gcp_region
  network       = google_compute_network.ceres.id
}

# GCP Private VPC Connection (для Cloud SQL)
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.ceres.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.ceres.id
}

# RDS Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
