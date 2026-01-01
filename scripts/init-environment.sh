#!/usr/bin/env bash
set -euo pipefail

# Initialize environment: pull repo, setup directories, perms
echo "[INIT] Environment initialization..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. Ensure project is a git repo
if [[ ! -d "$PROJECT_ROOT/.git" ]]; then
  echo "[WARN] Not a git repo, initializing..."
  cd "$PROJECT_ROOT"
  git init || echo "[WARN] git init skipped"
fi

# 2. Create required directories
mkdir -p "$PROJECT_ROOT"/{config/k8s,logs,data,secrets}
echo "[OK] Directories created"

# 3. Set permissions
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
echo "[OK] Script permissions set"

# 4. Create .env template if not exists
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
  cat > "$PROJECT_ROOT/.env.example" <<'EOF'
# Remote deployment
export REMOTE_HOST=192.168.1.3
export REMOTE_USER=root
export REMOTE_PORT=22
export SSH_KEY_PATH=$HOME/.ssh/ceres

# Kubernetes
export REMOTE_KUBECONFIG=~/.kube/config
export K8S_MANIFEST_PATH=/srv/ceres/k8s

# GitHub
export GH_REPO=owner/repo

# Tenant provisioning
export TENANT_NAME=acme
export TENANT_DOMAIN=acme.example.com
EOF
  echo "[OK] .env.example created (copy to .env and fill in values)"
fi

# 5. Check docker/podman
if command -v docker &>/dev/null; then
  docker ps >/dev/null 2>&1 && echo "[OK] Docker available" || echo "[WARN] Docker not accessible (try sudo)"
elif command -v podman &>/dev/null; then
  podman ps >/dev/null 2>&1 && echo "[OK] Podman available" || echo "[WARN] Podman not accessible"
fi

echo "[INIT] Environment ready"
