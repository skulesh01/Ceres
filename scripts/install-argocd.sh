#!/bin/bash
set -euo pipefail

# Installs Argo CD into the current Kubernetes cluster.
# Usage: ./scripts/install-argocd.sh

NAMESPACE="argocd"
VERSION="v2.10.10"

echo "=== Installing Argo CD ${VERSION} into namespace ${NAMESPACE} ==="

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Install pinned version
kubectl apply -n "${NAMESPACE}" -f "https://raw.githubusercontent.com/argoproj/argo-cd/${VERSION}/manifests/install.yaml"

echo "Waiting for Argo CD pods..."
kubectl wait --for=condition=Ready pods --all -n "${NAMESPACE}" --timeout=600s

# Expose argocd-server as NodePort for quick access (single-node friendly)
# NodePort chosen to avoid common defaults.
kubectl patch svc argocd-server -n "${NAMESPACE}" -p '{"spec": {"type": "NodePort", "ports": [{"name":"https","port":443,"targetPort":8080,"nodePort":30090}]}}'

echo "Argo CD installed. Access: https://<SERVER_IP>:30090"

# Print initial admin password (ArgoCD stores it in a secret)
PASS=$(kubectl get secret -n "${NAMESPACE}" argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
if [ -n "$PASS" ]; then
  echo "Initial admin password: ${PASS}"
else
  echo "Initial admin password secret not found yet (may rotate after first login)."
fi
