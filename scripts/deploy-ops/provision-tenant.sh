#!/usr/bin/env bash
set -euo pipefail

TENANT_NAME="${TENANT_NAME:-${1:-}}"
TENANT_DOMAIN="${TENANT_DOMAIN:-${2:-}}"

if [[ -z "$TENANT_NAME" ]]; then
  echo "Usage: TENANT_NAME=<name> TENANT_DOMAIN=<domain> $0" >&2
  exit 1
fi

if [[ ! -x "scripts/provision-tenant.sh" ]]; then
  echo "scripts/provision-tenant.sh not found or not executable" >&2
  exit 1
fi

scripts/provision-tenant.sh "$TENANT_NAME" "$TENANT_DOMAIN"
