#!/bin/bash
# Quick GitOps check - verify ArgoCD sync status

ARGOCD_NAMESPACE="argocd"
APP_NAME="${1:-ceres-apps}"

echo "📊 ArgoCD Application Status"
echo "========================================"

# Check if ArgoCD is running
if ! kubectl get deployment argocd-server -n $ARGOCD_NAMESPACE &>/dev/null; then
    echo "❌ ArgoCD not installed"
    exit 1
fi

# Get application status
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{
  .metadata.name}{"\n"
  "Status: "}{.status.operationState.phase}{"\n"
  "Sync Status: "}{.status.sync.status}{"\n"
  "Last Sync: "}{.status.operationState.finishedAt}{"\n"
  "Revision: "}{.status.operationState.syncResult.revision}{"\n"
}'

echo ""
echo "📦 Ceres Services Status:"
kubectl get pods -n ceres 2>/dev/null || echo "  Namespace not created yet"

echo ""
echo "🔄 Recent Syncs:"
kubectl get events -n $ARGOCD_NAMESPACE --sort-by='.lastTimestamp' | grep -i argocd | tail -5 || echo "  No recent events"
