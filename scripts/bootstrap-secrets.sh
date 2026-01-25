#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Kubernetes Secrets for CERES without storing credentials in Git.
# Safe behavior:
# - If a secret already exists, it is left untouched.
# - If missing, it is created (values can be provided via env, otherwise generated).
#
# This is designed to run on the k3s server (where kubectl is configured).

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-32
  fi
}

rand_b64_32() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n'
  else
    head -c 32 /dev/urandom | base64 | tr -d '\n'
  fi
}

ensure_ns() {
  local ns="$1"
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns" >/dev/null
}

secret_exists() {
  local ns="$1" name="$2"
  kubectl get secret "$name" -n "$ns" >/dev/null 2>&1
}

ensure_secret_kv() {
  local ns="$1" name="$2"; shift 2
  if secret_exists "$ns" "$name"; then
    echo "[secrets] exists: $ns/$name"
    return 0
  fi
  echo "[secrets] creating: $ns/$name"
  ensure_ns "$ns"
  kubectl create secret generic "$name" -n "$ns" "$@" >/dev/null
}

# --- Keycloak admin password (cluster secret) ---
# Used by deployment/keycloak.yaml via env var KEYCLOAK_ADMIN_PASSWORD.
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-${CERES_KEYCLOAK_ADMIN_PASSWORD:-}}"
if [ -z "${KC_ADMIN_PASSWORD}" ]; then
  KC_ADMIN_PASSWORD="$(rand_hex)"
fi
ensure_secret_kv ceres keycloak-secret \
  --from-literal=admin-password="${KC_ADMIN_PASSWORD}"

# --- PostgreSQL ---
# Used by deployment/postgresql.yaml and other components.
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-${CERES_POSTGRES_PASSWORD:-}}"
if [ -z "${POSTGRES_PASSWORD}" ]; then
  POSTGRES_PASSWORD="$(rand_hex)"
fi
ensure_secret_kv ceres-core postgresql-secret \
  --from-literal=postgres-password="${POSTGRES_PASSWORD}"

# --- Redis ---
REDIS_PASSWORD="${REDIS_PASSWORD:-${CERES_REDIS_PASSWORD:-}}"
if [ -z "${REDIS_PASSWORD}" ]; then
  REDIS_PASSWORD="$(rand_hex)"
fi
ensure_secret_kv ceres-core redis-secret \
  --from-literal=redis-password="${REDIS_PASSWORD}"

# --- OAuth2 Proxy ---
# Used by deployment/oauth2-proxy.yaml.
OAUTH2_PROXY_CLIENT_SECRET="${OAUTH2_PROXY_CLIENT_SECRET:-$(rand_hex)}"
OAUTH2_PROXY_COOKIE_SECRET="${OAUTH2_PROXY_COOKIE_SECRET:-$(rand_b64_32)}"
ensure_secret_kv oauth2-proxy oauth2-proxy-secret \
  --from-literal=client-id=oauth2-proxy \
  --from-literal=client-secret="${OAUTH2_PROXY_CLIENT_SECRET}" \
  --from-literal=cookie-secret="${OAUTH2_PROXY_COOKIE_SECRET}"

echo "[secrets] bootstrap complete"

cat <<EOF
NEXT STEPS (recommended):
- Save generated secrets somewhere safe (password manager).
- Optionally rotate defaults for other services that still embed credentials.
EOF
