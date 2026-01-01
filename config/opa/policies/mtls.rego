package ceres.mtls

import future.keywords.if
import future.keywords.in

# mTLS certificate validation
default certificate_valid := false

# Valid if certificate is issued by our CA
certificate_valid if {
    input.certificate.issuer == "CN=CERES Root CA"
    not certificate_expired
    not certificate_revoked
}

certificate_expired if {
    now := time.now_ns()
    expiry := time.parse_rfc3339_ns(input.certificate.not_after)
    now > expiry
}

certificate_revoked if {
    input.certificate.serial_number in revoked_certificates
}

# Revoked certificates list (should be fetched from Vault CRL)
revoked_certificates := set()

# Service identity validation
valid_service_identity if {
    service_name := extract_service_name(input.certificate.subject)
    service_name in allowed_services
    certificate_valid
}

extract_service_name(subject) := name if {
    # Extract CN from subject
    cn_pattern := `CN=([^,]+)`
    matches := regex.find_n(cn_pattern, subject, 1)
    count(matches) > 0
    name := trim_prefix(matches[0], "CN=")
}

allowed_services := {
    "postgres.ceres.local",
    "redis.ceres.local",
    "keycloak.ceres.local",
    "nextcloud.ceres.local",
    "gitea.ceres.local",
    "mattermost.ceres.local",
    "grafana.ceres.local",
    "prometheus.ceres.local",
    "caddy.ceres.local"
}

# Connection authorization based on mTLS
connection_allowed if {
    valid_service_identity
    source := extract_service_name(input.certificate.subject)
    destination := input.destination.service
    allowed_connections[source][destination]
}

allowed_connections := {
    "nextcloud.ceres.local": {"postgres.ceres.local", "redis.ceres.local", "keycloak.ceres.local"},
    "gitea.ceres.local": {"postgres.ceres.local", "keycloak.ceres.local"},
    "mattermost.ceres.local": {"postgres.ceres.local", "keycloak.ceres.local"},
    "grafana.ceres.local": {"prometheus.ceres.local", "keycloak.ceres.local"},
    "prometheus.ceres.local": {"postgres.ceres.local", "redis.ceres.local"},
    "keycloak.ceres.local": {"postgres.ceres.local"}
}
