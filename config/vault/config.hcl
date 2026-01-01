storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
  # For production, enable TLS:
  # tls_cert_file = "/vault/tls/vault.crt"
  # tls_key_file  = "/vault/tls/vault.key"
}

# API address for inter-service communication
api_addr = "http://vault:8200"

# Cluster address (for HA setup)
cluster_addr = "http://vault:8201"

# UI
ui = true

# Telemetry for monitoring
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

# Max lease TTL
max_lease_ttl = "768h"
default_lease_ttl = "168h"

# Plugin directory
plugin_directory = "/vault/plugins"
