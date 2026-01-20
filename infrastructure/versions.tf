# ============================================================================
# Terraform Version and Required Providers
# ============================================================================

terraform {
  required_version = ">= 1.5"

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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }

  # Uncomment для использования Remote State
  # backend "s3" {
  #   bucket         = "ceres-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "eu-west-1"
  #   encrypt        = true
  #   dynamodb_table = "ceres-terraform-locks"
  # }
}
