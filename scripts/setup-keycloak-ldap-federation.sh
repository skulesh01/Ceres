#!/usr/bin/env bash
set -euo pipefail

# Configures Keycloak LDAP User Federation against OpenLDAP deployed by setup-identity-openldap.sh.
# Security notes:
# - This uses kubectl exec into Keycloak and runs kcadm.sh.
# - Prefer running LDAP with TLS (LDAPS/StartTLS) in production.
# - This script does NOT store passwords in git; pass them via env.
#
# Usage:
#   LDAP_ADMIN_PASSWORD=... bash scripts/setup-keycloak-ldap-federation.sh

REALM="${REALM:-ceres}"
KEYCLOAK_NS="${KEYCLOAK_NS:-ceres}"
KEYCLOAK_DEPLOY="${KEYCLOAK_DEPLOY:-keycloak}"

LDAP_HOST="${LDAP_HOST:-openldap.identity.svc.cluster.local}"
LDAP_PORT="${LDAP_PORT:-389}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=ceres,dc=local}"
LDAP_BIND_DN="${LDAP_BIND_DN:-cn=admin,dc=ceres,dc=local}"
LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-}"

if [ -z "${LDAP_ADMIN_PASSWORD}" ]; then
  echo "[keycloak-ldap] LDAP_ADMIN_PASSWORD is required" >&2
  exit 1
fi

# Keycloak admin creds: prefer env, otherwise read from cluster secret.
KC_ADMIN_USER="${KC_ADMIN_USER:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-}"
if [ -z "${KC_ADMIN_PASSWORD}" ]; then
  KC_ADMIN_PASSWORD="$(kubectl get secret keycloak-secret -n "${KEYCLOAK_NS}" -o jsonpath='{.data.admin-password}' | base64 -d)"
fi

POD="$(kubectl get pods -n "${KEYCLOAK_NS}" -l app=keycloak -o jsonpath='{.items[0].metadata.name}')"
if [ -z "$POD" ]; then
  echo "[keycloak-ldap] Keycloak pod not found" >&2
  exit 1
fi

echo "[keycloak-ldap] logging into keycloak via kcadm..."
kubectl exec -n "${KEYCLOAK_NS}" "$POD" -- /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user "${KC_ADMIN_USER}" \
  --password "${KC_ADMIN_PASSWORD}" \
  --config /tmp/kcadm.config >/dev/null

# Check if provider already exists
existing_id="$(kubectl exec -n "${KEYCLOAK_NS}" "$POD" -- /opt/keycloak/bin/kcadm.sh get components -r "${REALM}" --config /tmp/kcadm.config \
  -q name=ceres-ldap -q providerId=ldap \
  --fields id -o csv 2>/dev/null | tail -n 1 | tr -d '\r' | tr -d ' ')"

if [ -n "${existing_id}" ]; then
  echo "[keycloak-ldap] LDAP provider already exists (id=${existing_id}); skipping create."
  exit 0
fi

echo "[keycloak-ldap] creating LDAP user federation provider..."
# Settings chosen for 'single password everywhere': allow updates from Keycloak to LDAP.
# NOTE: This assumes LDAP is the source of truth; user creation should happen in LDAP.
# For now we keep IMPORT_ENABLED=true to sync users into Keycloak.

kubectl exec -n "${KEYCLOAK_NS}" "$POD" -- /opt/keycloak/bin/kcadm.sh create components -r "${REALM}" \
  -s name=ceres-ldap \
  -s providerId=ldap \
  -s providerType=org.keycloak.storage.UserStorageProvider \
  -s parentId="${REALM}" \
  -s 'config.enabled=["true"]' \
  -s 'config.vendor=["other"]' \
  -s 'config.connectionUrl=["ldap://'"${LDAP_HOST}"':'"${LDAP_PORT}"'"]' \
  -s 'config.usersDn=['"${LDAP_BASE_DN}"']' \
  -s 'config.bindDn=['"${LDAP_BIND_DN}"']' \
  -s 'config.bindCredential=['"${LDAP_ADMIN_PASSWORD}"']' \
  -s 'config.authType=["simple"]' \
  -s 'config.editMode=["WRITABLE"]' \
  -s 'config.importEnabled=["true"]' \
  -s 'config.syncRegistrations=["false"]' \
  -s 'config.usernameLDAPAttribute=["uid"]' \
  -s 'config.rdnLDAPAttribute=["uid"]' \
  -s 'config.uuidLDAPAttribute=["entryUUID"]' \
  -s 'config.userObjectClasses=["inetOrgPerson,organizationalPerson,person,top"]' \
  --config /tmp/kcadm.config >/dev/null

cat <<EOF
[keycloak-ldap] Done.
- Realm: ${REALM}
- Provider: ceres-ldap

Next steps (recommended):
1) Decide where users are created (LDAP-first vs Keycloak-first).
2) Add TLS to LDAP and switch connectionUrl to ldaps://...
3) Configure mail server (Dovecot/Postfix) to authenticate via the same LDAP.
EOF
