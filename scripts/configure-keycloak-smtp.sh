#!/usr/bin/env bash
set -euo pipefail

# Configures SMTP settings for the Keycloak realm (ceres) using kcadm inside the Keycloak pod.
# Intended for "external mail" setups where mail is hosted outside Kubernetes.
#
# Required env:
#   CERES_SMTP_HOST
# Optional env:
#   CERES_SMTP_PORT (default 587)
#   CERES_SMTP_USER / CERES_SMTP_PASS (for auth)
#   CERES_MAIL_FROM (default no-reply@ceres.local)
#   CERES_SMTP_STARTTLS (default true)
#   CERES_SMTP_TLS (default false)
#   CERES_KEYCLOAK_NAMESPACE (default ceres)
#   CERES_KEYCLOAK_REALM (default ceres)

KC_NS="${CERES_KEYCLOAK_NAMESPACE:-ceres}"
KC_REALM="${CERES_KEYCLOAK_REALM:-ceres}"
SMTP_HOST="${CERES_SMTP_HOST:-}"
SMTP_PORT="${CERES_SMTP_PORT:-587}"
SMTP_USER="${CERES_SMTP_USER:-}"
SMTP_PASS="${CERES_SMTP_PASS:-}"
MAIL_FROM="${CERES_MAIL_FROM:-no-reply@ceres.local}"
STARTTLS="${CERES_SMTP_STARTTLS:-true}"
TLS="${CERES_SMTP_TLS:-false}"

if [ -z "$SMTP_HOST" ]; then
  echo "[KEYCLOAK SMTP] CERES_SMTP_HOST is empty; nothing to configure" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "[KEYCLOAK SMTP] kubectl not found" >&2
  exit 1
fi

# Wait for Keycloak
kubectl wait --for=condition=Available deployment/keycloak -n "$KC_NS" --timeout=300s >/dev/null || true

ADMIN_USER="admin"
ADMIN_PASS="$(kubectl get secret -n "$KC_NS" keycloak-secret -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d 2>/dev/null || true)"
if [ -z "$ADMIN_PASS" ]; then
  echo "[KEYCLOAK SMTP] failed to read Keycloak admin password from secret ${KC_NS}/keycloak-secret" >&2
  exit 1
fi

# Configure via kcadm in pod
echo "[KEYCLOAK SMTP] configuring realm '$KC_REALM' SMTP: ${SMTP_HOST}:${SMTP_PORT} (starttls=${STARTTLS}, tls=${TLS})" >&2

# Login
kubectl exec -n "$KC_NS" deployment/keycloak -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS" >/dev/null

# Update realm SMTP settings
args=(
  -s "smtpServer.host=${SMTP_HOST}"
  -s "smtpServer.port=${SMTP_PORT}"
  -s "smtpServer.from=${MAIL_FROM}"
)

# Keycloak expects strings in smtpServer map
args+=( -s "smtpServer.starttls=${STARTTLS}" )
args+=( -s "smtpServer.ssl=${TLS}" )

if [ -n "$SMTP_USER" ]; then
  args+=( -s "smtpServer.auth=true" )
  args+=( -s "smtpServer.user=${SMTP_USER}" )
  args+=( -s "smtpServer.password=${SMTP_PASS}" )
fi

kubectl exec -n "$KC_NS" deployment/keycloak -- /opt/keycloak/bin/kcadm.sh update "realms/${KC_REALM}" "${args[@]}" >/dev/null

echo "[KEYCLOAK SMTP] done" >&2
