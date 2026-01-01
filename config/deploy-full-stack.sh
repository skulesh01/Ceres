#!/bin/bash
# One-command Ceres deployment: K8s + ArgoCD + GitOps

set -e

PROXMOX_IP="${1:-192.168.1.10}"
GITHUB_REPO="${2:-https://github.com/yourorg/ceres-k8s-manifests}"
GITHUB_TOKEN="${3:-}"

echo "╔════════════════════════════════════════════════════════╗"
echo "║  CERES KUBERNETES + GITOPS DEPLOYMENT                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Phase 1: Deploy K8s cluster
echo "Phase 1️⃣: Kubernetes Cluster Setup"
echo "=================================="

ssh ubuntu@$PROXMOX_IP << 'KUBE'
  set -e
  echo "Installing K8s on master..."
  
  curl -fsSL https://get.k8s.io | bash
  
  kubeadm init \
    --pod-network-cidr=10.244.0.0/16 \
    --apiserver-advertise-address=0.0.0.0 \
    --kubernetes-version=1.28.0
  
  mkdir -p $HOME/.kube
  sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  
  kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
  
  echo "✓ K8s cluster ready"
  kubectl get nodes
KUBE

echo "✓ K8s deployment complete"
echo ""

# Phase 2: Deploy Ceres services
echo "Phase 2️⃣: Ceres Services Deployment"
echo "===================================="

kubectl apply -f https://github.com/yourorg/ceres-k8s-manifests/releases/download/v1.0.0/ceres-manifests.yaml
kubectl rollout status deployment -n ceres --timeout=5m

echo "✓ Ceres services deployed"
echo ""

# Phase 3: Deploy ArgoCD
echo "Phase 3️⃣: ArgoCD GitOps Setup"
echo "=============================="

kubectl create namespace argocd 2>/dev/null || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=3m

# Create application
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ceres-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $GITHUB_REPO
    targetRevision: main
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: ceres
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo "✓ ArgoCD deployed"
echo ""

# Phase 4: Setup monitoring
echo "Phase 4️⃣: Monitoring Stack"
echo "=========================="

kubectl create namespace monitoring 2>/dev/null || true
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.68.0/bundle.yaml

echo "✓ Prometheus operator deployed"
echo ""

# Phase 5: Print credentials
echo "Phase 5️⃣: Credentials & Access"
echo "==============================="
echo ""

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "🔐 ArgoCD Access:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   https://localhost:8080"
echo "   User: admin"
echo "   Pass: $ARGOCD_PASS"
echo ""

echo "📊 Prometheus:"
echo "   kubectl port-forward svc/prometheus -n monitoring 9090:9090"
echo "   http://localhost:9090"
echo ""

echo "📈 Grafana:"
echo "   kubectl port-forward svc/grafana -n monitoring 3000:3000"
echo "   http://localhost:3000"
echo ""

echo "✅ DEPLOYMENT COMPLETE!"
echo ""
echo "Next steps:"
echo "1. Port-forward to ArgoCD UI and verify applications"
echo "2. Check service status: kubectl get pods -n ceres"
echo "3. Monitor deployment: kubectl get applications -n argocd -w"
echo "4. View logs: kubectl logs -n ceres -f deployment/keycloak"
