#!/usr/bin/env bash
set -euo pipefail

# Secure-ish bootstrap for OpenLDAP in k3s.
# - Generates random passwords if not provided
# - Applies deployment/identity/openldap.yaml after replacing CHANGE_ME_* placeholders
#
# Usage:
#   bash scripts/setup-identity-openldap.sh
#   LDAP_ADMIN_PASSWORD=... LDAP_CONFIG_PASSWORD=... bash scripts/setup-identity-openldap.sh

MANIFEST="deployment/identity/openldap.yaml"

if [ ! -f "$MANIFEST" ]; then
  echo "[identity] missing $MANIFEST" >&2
  exit 1
fi

rand_hex() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 16
  else
    head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' | cut -c1-32
  fi
}

LDAP_ADMIN_PASSWORD="${LDAP_ADMIN_PASSWORD:-$(rand_hex)}"
LDAP_CONFIG_PASSWORD="${LDAP_CONFIG_PASSWORD:-$(rand_hex)}"

if [ "${LDAP_ADMIN_PASSWORD}" = "CHANGE_ME_ADMIN_PASSWORD" ] || [ "${LDAP_CONFIG_PASSWORD}" = "CHANGE_ME_CONFIG_PASSWORD" ]; then
  echo "[identity] refusing to use CHANGE_ME_* values" >&2
  exit 1
fi

# Apply manifest with runtime substitution.
# Note: we avoid committing generated secrets.

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

sed \
  -e "s/CHANGE_ME_ADMIN_PASSWORD/${LDAP_ADMIN_PASSWORD}/g" \
  -e "s/CHANGE_ME_CONFIG_PASSWORD/${LDAP_CONFIG_PASSWORD}/g" \
  "$MANIFEST" > "$tmp"

kubectl apply -f "$tmp"

echo "[identity] waiting for openldap rollout..."
kubectl rollout status deployment/openldap -n identity --timeout=180s

cat <<EOF
[identity] OpenLDAP deployed.
- Namespace: identity
- Service:   openldap.identity.svc.cluster.local:389
- Base DN:   dc=ceres,dc=local
- Bind DN:   cn=admin,dc=ceres,dc=local

ADMIN PASSWORD (SAVE THIS SAFELY): ${LDAP_ADMIN_PASSWORD}
CONFIG PASSWORD (SAVE THIS SAFELY): ${LDAP_CONFIG_PASSWORD}

Next: run scripts/setup-keycloak-ldap-federation.sh
EOF
