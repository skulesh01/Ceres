# ============================================================================
# CERES GCP Infrastructure Module
# ============================================================================

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ============================================================================
# VPC Network
# ============================================================================

resource "google_compute_network" "ceres" {
  count                   = var.gcp_enabled ? 1 : 0
  name                    = "${var.project_name}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gke" {
  count         = var.gcp_enabled ? 1 : 0
  name          = "${var.project_name}-gke-subnet"
  ip_cidr_range = "10.2.0.0/20"
  region        = var.gcp_region
  network       = google_compute_network.ceres[0].id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }
}

resource "google_compute_subnetwork" "database" {
  count         = var.gcp_enabled ? 1 : 0
  name          = "${var.project_name}-db-subnet"
  ip_cidr_range = "10.3.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.ceres[0].id
}

# ============================================================================
# Firewall Rules
# ============================================================================

resource "google_compute_firewall" "gke_ingress" {
  count   = var.gcp_enabled ? 1 : 0
  name    = "${var.project_name}-gke-ingress"
  network = google_compute_network.ceres[0].name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "internal" {
  count   = var.gcp_enabled ? 1 : 0
  name    = "${var.project_name}-internal"
  network = google_compute_network.ceres[0].name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = ["10.0.0.0/8"]
}

# ============================================================================
# GKE Cluster
# ============================================================================

resource "google_container_cluster" "gke" {
  count    = var.gcp_enabled ? 1 : 0
  name     = var.cluster_name
  location = var.gcp_region

  initial_node_count       = var.gcp_node_count
  remove_default_node_pool = true

  network    = google_compute_network.ceres[0].name
  subnetwork = google_compute_subnetwork.gke[0].name

  cluster_secondary_range_name = "pods"

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

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

    monitoring_config {
      enabled = var.enable_monitoring
    }

    logging_config {
      enabled = var.enable_logging
    }
  }

  network_policy {
    enabled = true
  }

  workload_identity_config {
    workload_pool = "${var.gcp_project_id}.svc.id.goog"
  }

  resource_labels = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "google_container_node_pool" "primary" {
  count    = var.gcp_enabled ? 1 : 0
  name     = "${var.project_name}-node-pool"
  location = var.gcp_region
  cluster  = google_container_cluster.gke[0].name

  initial_node_count = var.gcp_node_count

  autoscaling {
    min_node_count = var.gcp_node_count
    max_node_count = var.gcp_node_count * 2
  }

  node_config {
    preemptible  = false
    machine_type = var.gcp_machine_type

    service_account = google_service_account.gke_nodes[0].email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      environment = var.environment
      cluster     = var.cluster_name
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

# ============================================================================
# Service Accounts
# ============================================================================

resource "google_service_account" "gke_nodes" {
  count        = var.gcp_enabled ? 1 : 0
  account_id   = "${var.project_name}-gke-nodes"
  display_name = "CERES GKE Nodes Service Account"
}

# ============================================================================
# Cloud SQL PostgreSQL
# ============================================================================

resource "google_sql_database_instance" "postgres" {
  count            = var.gcp_enabled ? 1 : 0
  name             = "${var.project_name}-postgres"
  database_version = "POSTGRES_${replace(var.postgres_version, ".", "_")}"
  region           = var.gcp_region

  settings {
    tier = "db-custom-4-16384"

    backup_configuration {
      enabled                        = true
      binary_log_enabled             = false
      replication_type               = "SYNCHRONOUS"
      start_time                     = "03:00"
      location                       = var.gcp_region
      point_in_time_recovery_enabled = true
      backup_retention_settings {
        retained_backups = 30
      }
    }

    ip_configuration {
      require_ssl        = true
      private_network    = google_compute_network.ceres[0].id
      enable_private_path_import = false
      ipv4_enabled       = false
    }

    user_labels = {
      environment = var.environment
      project     = var.project_name
    }

    location_preference {
      zone = var.gcp_zone
    }
  }

  deletion_protection = true

  depends_on = [google_compute_subnetwork.database]
}

resource "google_sql_database" "ceres" {
  count    = var.gcp_enabled ? 1 : 0
  name     = "ceres"
  instance = google_sql_database_instance.postgres[0].name
}

resource "google_sql_user" "ceres" {
  count    = var.gcp_enabled ? 1 : 0
  name     = "ceres"
  instance = google_sql_database_instance.postgres[0].name
  password = random_password.gcp_postgres[0].result
}

resource "random_password" "gcp_postgres" {
  count            = var.gcp_enabled ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ============================================================================
# Cloud Memorystore Redis
# ============================================================================

resource "google_redis_instance" "redis" {
  count           = var.gcp_enabled ? 1 : 0
  name            = "${var.project_name}-redis"
  memory_size_gb  = 5
  tier            = "STANDARD_HA"
  region          = var.gcp_region
  location_id     = var.gcp_zone
  connect_mode    = "PRIVATE_SERVICE_ACCESS"
  redis_version   = "7_0"
  authorized_network = google_compute_network.ceres[0].id

  auth_enabled           = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  labels = {
    environment = var.environment
    project     = var.project_name
  }

  depends_on = [google_compute_network.ceres]
}

# ============================================================================
# GCS Bucket для артефактов
# ============================================================================

resource "google_storage_bucket" "artifacts" {
  count    = var.gcp_enabled ? 1 : 0
  name     = "${var.project_name}-artifacts-${var.gcp_project_id}"
  location = var.gcp_region

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  labels = {
    environment = var.environment
    project     = var.project_name
  }
}

# ============================================================================
# Variables for GCP
# ============================================================================

variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_node_count" {
  description = "Количество worker nodes"
  type        = number
  default     = 3
}
