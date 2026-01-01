#!/usr/bin/env bash
set -euo pipefail

# Check core dependencies for Linux server
echo "[CHECK] Core dependencies..."

MISSING_DEPS=()

# Essential commands
for cmd in git curl wget; do
  if ! command -v "$cmd" &>/dev/null; then
    MISSING_DEPS+=("$cmd")
  fi
done

# Check for container runtime
if ! command -v docker &>/dev/null && ! command -v podman &>/dev/null; then
  MISSING_DEPS+=("docker or podman")
fi

# Check for k8s tools
if ! command -v kubectl &>/dev/null; then
  echo "[WARN] kubectl not found (install manually or use docker)"
fi

if ! command -v helm &>/dev/null; then
  echo "[WARN] helm not found (optional)"
fi

# Report
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  echo "[ERROR] Missing dependencies: ${MISSING_DEPS[*]}"
  echo ""
  echo "Installation guide:"
  echo "  Ubuntu/Debian:"
  echo "    sudo apt-get update && sudo apt-get install -y git curl wget docker.io"
  echo "  RHEL/CentOS:"
  echo "    sudo yum install -y git curl wget docker"
  echo "  k3s (all-in-one k8s):"
  echo "    curl -sfL https://get.k3s.io | sh -"
  echo ""
  exit 1
fi

echo "[OK] All core dependencies present"
