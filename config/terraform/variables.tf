# ============================================================================
# CERES Terraform Variables - Universal Configuration
# ============================================================================

# Global Variables
variable "environment" {
  description = "Окружение (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Допустимые значения: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Имя проекта"
  type        = string
  default     = "ceres"
}

variable "project_version" {
  description = "Версия проекта"
  type        = string
  default     = "3.0.0"
}

variable "domain_name" {
  description = "Домен для всех сервисов"
  type        = string
  default     = "ceres.local"
}

variable "enable_monitoring" {
  description = "Включить Prometheus/Grafana"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Включить Loki/Promtail"
  type        = bool
  default     = true
}

variable "enable_tracing" {
  description = "Включить Jaeger"
  type        = bool
  default     = true
}

# AWS Configuration
variable "aws_enabled" {
  description = "Развертывать на AWS"
  type        = bool
  default     = true
}

variable "aws_region" {
  description = "AWS регион"
  type        = string
  default     = "eu-west-1"
}

variable "aws_availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "aws_instance_type" {
  description = "Тип EC2 инстанса для master"
  type        = string
  default     = "t3.xlarge"
}

variable "aws_node_count" {
  description = "Количество worker nodes"
  type        = number
  default     = 3
  
  validation {
    condition     = var.aws_node_count >= 1 && var.aws_node_count <= 10
    error_message = "Количество nodes должно быть от 1 до 10"
  }
}

# Azure Configuration
variable "azure_enabled" {
  description = "Развертывать на Azure"
  type        = bool
  default     = false
}

variable "azure_location" {
  description = "Azure регион"
  type        = string
  default     = "westeurope"
}

variable "azure_vm_size" {
  description = "Размер Azure VM"
  type        = string
  default     = "Standard_D4s_v3"
}

# GCP Configuration
variable "gcp_enabled" {
  description = "Развертывать на GCP"
  type        = bool
  default     = false
}

variable "gcp_region" {
  description = "GCP регион"
  type        = string
  default     = "europe-west1"
}

variable "gcp_zone" {
  description = "GCP зона"
  type        = string
  default     = "europe-west1-b"
}

variable "gcp_machine_type" {
  description = "Тип машины GCP"
  type        = string
  default     = "n2-standard-4"
}

# Proxmox Configuration
variable "proxmox_enabled" {
  description = "Развертывать на Proxmox"
  type        = bool
  default     = false
}

variable "proxmox_host" {
  description = "IP адрес Proxmox хоста"
  type        = string
  default     = ""
}

variable "proxmox_username" {
  description = "Proxmox пользователь"
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox пароль"
  type        = string
  default     = ""
  sensitive   = true
}

# Database Configuration
variable "postgres_version" {
  description = "Версия PostgreSQL"
  type        = string
  default     = "16"
}

variable "postgres_instance_size" {
  description = "Размер PostgreSQL инстанса"
  type        = string
  default     = "db.t3.medium"
}

variable "postgres_storage_size" {
  description = "Размер хранилища PostgreSQL (Gi)"
  type        = number
  default     = 100
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Версия Kubernetes"
  type        = string
  default     = "1.28"
}

variable "cluster_name" {
  description = "Имя Kubernetes кластера"
  type        = string
  default     = "ceres-prod"
}

# Tags
variable "tags" {
  description = "Общие теги для всех ресурсов"
  type        = map(string)
  default = {
    Project     = "ceres"
    ManagedBy   = "terraform"
    Environment = "production"
    Version     = "3.0.0"
  }
}
