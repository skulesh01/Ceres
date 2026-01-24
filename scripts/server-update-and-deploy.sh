#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/skulesh01/Ceres.git}"
REPO_DIR="${REPO_DIR:-/root/Ceres}"

echo "[CERES] update+deploy"
echo "  repo: ${REPO_URL}"
echo "  dir:  ${REPO_DIR}"

if [ ! -d "${REPO_DIR}/.git" ]; then
  echo "[CERES] cloning repo..."
  mkdir -p "${REPO_DIR}"
  git clone "${REPO_URL}" "${REPO_DIR}"
fi

cd "${REPO_DIR}"

echo "[CERES] pulling latest..."
git fetch --all --prune
# Default: pull current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git pull --ff-only origin "${BRANCH}"

echo "[CERES] running deploy (reconcile)..."
# Make path resolution deterministic
export CERES_ROOT="${REPO_DIR}"

if [ -x "./bin/ceres" ]; then
  ./bin/ceres deploy --cloud proxmox --environment prod --namespace ceres
else
  # Fallback: run from source (requires Go on server)
  if command -v go >/dev/null 2>&1; then
    go run ./cmd/ceres/main.go deploy --cloud proxmox --environment prod --namespace ceres
  elif [ -x "/usr/local/go/bin/go" ]; then
    /usr/local/go/bin/go run ./cmd/ceres/main.go deploy --cloud proxmox --environment prod --namespace ceres
  else
    echo "Go not found and ./bin/ceres отсутствует. Установи Go или положи собранный бинарь в ./bin/ceres" >&2
    exit 1
  fi
fi

echo "[CERES] done"
