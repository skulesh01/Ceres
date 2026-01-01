package ceres.authz

import future.keywords.if
import future.keywords.in

# Default deny
default allow := false

# Allow if user is admin
allow if {
    input.user.role == "admin"
}

# Allow read access to own resources
allow if {
    input.method == "GET"
    input.user.id == input.resource.owner_id
}

# Allow write access to own resources if not read-only
allow if {
    input.method in ["POST", "PUT", "PATCH", "DELETE"]
    input.user.id == input.resource.owner_id
    not input.resource.read_only
}

# Service-to-service authentication
allow if {
    valid_service_token
}

valid_service_token if {
    input.token.type == "service"
    input.token.service in allowed_services
    input.token.signature == compute_signature(input.token)
}

allowed_services := {
    "nextcloud",
    "gitea",
    "mattermost",
    "keycloak",
    "grafana",
    "prometheus"
}

# Resource-specific policies
allow if {
    resource_policy[input.resource.type]
}

resource_policy := {
    "file": file_policy,
    "repository": repo_policy,
    "message": message_policy,
    "dashboard": dashboard_policy
}

# File access policy
file_policy if {
    input.resource.type == "file"
    input.user.id in input.resource.shared_with
}

# Repository access policy
repo_policy if {
    input.resource.type == "repository"
    input.user.id in input.resource.collaborators
}

# Message access policy
message_policy if {
    input.resource.type == "message"
    input.user.id in input.resource.channel_members
}

# Dashboard access policy
dashboard_policy if {
    input.resource.type == "dashboard"
    input.user.role in ["admin", "operator", "viewer"]
}

# Rate limiting
allow if {
    not rate_limited
}

rate_limited if {
    input.user.request_count > 1000
    input.user.time_window == "1h"
}

# Audit log decision
audit_required if {
    input.method in ["POST", "PUT", "DELETE"]
    input.resource.sensitive == true
}

# Network policy - service-to-service communication
network_allowed if {
    allowed_connections[input.source.service][input.destination.service]
}

allowed_connections := {
    "nextcloud": {"postgres", "redis", "keycloak"},
    "gitea": {"postgres", "keycloak"},
    "mattermost": {"postgres", "keycloak"},
    "grafana": {"prometheus", "loki", "postgres", "keycloak"},
    "prometheus": {"cadvisor", "postgres_exporter", "redis_exporter"},
    "keycloak": {"postgres"}
}
