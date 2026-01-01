#!/bin/bash
# Setup Sealed Secrets for CERES

set -e

echo "🔐 Setting up Sealed Secrets for CERES"
echo "======================================="

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl required"; exit 1; }
command -v kubeseal >/dev/null 2>&1 || { echo "❌ kubeseal required. Install: https://github.com/bitnami-labs/sealed-secrets/releases"; exit 1; }

# Install Sealed Secrets Controller
echo "✓ Installing Sealed Secrets Controller..."
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller
echo "✓ Waiting for Sealed Secrets Controller..."
kubectl -n kube-system wait --for=condition=ready pod -l name=sealed-secrets-controller --timeout=120s

# Fetch public certificate
echo "✓ Fetching public certificate..."
kubeseal --fetch-cert --controller-name=sealed-secrets-controller --controller-namespace=kube-system > pub-sealed-secrets.pem

echo "✅ Sealed Secrets Controller installed!"
echo ""
echo "Public certificate saved to: pub-sealed-secrets.pem"
echo ""
echo "Create sealed secrets:"
echo "  kubectl create secret generic my-secret --from-literal=key=value --dry-run=client -o yaml | \\"
echo "    kubeseal -o yaml > sealed-secret.yaml"
echo ""
echo "Or use the helper script:"
echo "  ./scripts/create-sealed-secrets.sh"
