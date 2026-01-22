#!/bin/bash
set -euo pipefail

# One-command bootstrap for GitOps using Argo CD.
# - Installs Argo CD
# - Creates the 'ceres' Application pointing to this repo

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/install-argocd.sh

echo "=== Applying Argo CD Application (Ceres) ==="
kubectl apply -f deployment/gitops/argocd-application.yaml

echo "Done. Argo CD will sync resources automatically."
