#!/bin/bash
set -euo pipefail

SERVICE_NAME="ceres-autoupdate"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root" >&2
  exit 1
fi

systemctl disable --now "${SERVICE_NAME}.timer" 2>/dev/null || true
systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true

echo "Disabled: ${SERVICE_NAME}.timer (GitOps should own deployments now)"
