#!/bin/bash
# FluxCD Bootstrap Script for CERES

set -e

GITHUB_USER="${1:-skulesh01}"
GITHUB_REPO="${2:-Ceres}"
CLUSTER_NAME="${3:-production}"

echo "🚀 Bootstrapping FluxCD for CERES"
echo "=================================="
echo "GitHub User: $GITHUB_USER"
echo "Repository: $GITHUB_REPO"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v flux >/dev/null 2>&1 || { echo "❌ FluxCD CLI is required but not installed."; exit 1; }

# Check cluster connectivity
echo "✓ Checking Kubernetes cluster connectivity..."
kubectl cluster-info > /dev/null 2>&1 || { echo "❌ Cannot connect to Kubernetes cluster"; exit 1; }

# Bootstrap Flux
echo "✓ Bootstrapping FluxCD..."
flux bootstrap github \
  --owner="$GITHUB_USER" \
  --repository="$GITHUB_REPO" \
  --branch=main \
  --path="./flux/clusters/$CLUSTER_NAME" \
  --personal \
  --components-extra=image-reflector-controller,image-automation-controller

# Wait for Flux to be ready
echo "✓ Waiting for FluxCD to be ready..."
kubectl wait --for=condition=ready --timeout=5m \
  -n flux-system \
  kustomization/flux-system

# Create CERES namespace
echo "✓ Creating CERES namespace..."
kubectl create namespace ceres --dry-run=client -o yaml | kubectl apply -f -

# Label namespace for monitoring
kubectl label namespace ceres \
  monitoring=enabled \
  --overwrite

echo ""
echo "✅ FluxCD Bootstrap Complete!"
echo ""
echo "Check status:"
echo "  flux get sources git"
echo "  flux get kustomizations"
echo "  kubectl -n ceres-system get all"
echo ""
echo "Next steps:"
echo "  1. Commit your changes to Git"
echo "  2. Flux will automatically sync and deploy CERES"
echo "  3. Monitor with: flux logs --follow"
