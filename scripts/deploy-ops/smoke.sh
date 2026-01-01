#!/usr/bin/env bash
set -euo pipefail

# Попытаться выполнить встроенные проверки, если они существуют
if [[ -x "config/test-services.sh" ]]; then
  ./config/test-services.sh
  exit 0
fi

if [[ -x "config/validate-deployment.ps1" ]]; then
  echo "Run PowerShell validate (requires pwsh)" >&2
  pwsh ./config/validate-deployment.ps1
  exit 0
fi

echo "No smoke test script found. Add config/test-services.sh or config/validate-deployment.ps1" >&2
exit 1
