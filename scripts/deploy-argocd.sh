#!/bin/bash
# Deploy ArgoCD with Helm for CERES v2.8.0
# Features: OIDC/SSO, notifications, multi-cluster, HA

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
NAMESPACE="${1:-argocd}"
RELEASE_NAME="${2:-argocd}"
DOMAIN="${3:-ceres.local}"
SKIP_SECRETS="${4:-false}"

echo -e "${CYAN}"
echo "╔═════════════════════════════════════════════════════╗"
echo "║     CERES ArgoCD Deployment (K3s + Helm)           ║"
echo "║              v2.8.0 GitOps Ready                    ║"
echo "╚═════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Step 1: Verify prerequisites
echo -e "${CYAN}→${NC} Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗${NC} kubectl not found. Please install kubectl."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}✗${NC} helm not found. Please install helm."
    exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}✗${NC} Cannot connect to Kubernetes cluster"
    exit 1
fi

echo -e "${GREEN}✓${NC} All prerequisites met\n"

# Step 2: Create namespace
echo -e "${CYAN}→${NC} Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓${NC} Namespace ready\n"

# Step 3: Create secrets (if not skipped)
if [ "$SKIP_SECRETS" = "false" ]; then
    echo -e "${CYAN}→${NC} Creating ArgoCD secrets..."
    
    # Generate admin password
    ADMIN_PASSWORD=$(openssl rand -base64 32)
    ADMIN_PASS_BCRYPT=$(echo -n "$ADMIN_PASSWORD" | htpasswd -B -i -c /dev/stdin admin | cut -d: -f2)
    
    # GitHub SSH key (create from file or use placeholder)
    if [ -f "$HOME/.ssh/id_rsa" ]; then
        SSH_KEY=$(cat "$HOME/.ssh/id_rsa" | base64 -w0)
    else
        SSH_KEY="LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0K"
    fi
    
    # Create secret for repository access
    kubectl create secret generic argocd-repo-creds \
        --from-literal=sshPrivateKey="$SSH_KEY" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD admin secret
    kubectl create secret generic argocd-secret \
        --from-literal=admin.password="$ADMIN_PASS_BCRYPT" \
        --from-literal=admin.passwordMtime="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}✓${NC} Admin password: $ADMIN_PASSWORD"
    echo -e "${GREEN}✓${NC} Secrets created\n"
fi

# Step 4: Add Helm repositories
echo -e "${CYAN}→${NC} Adding Helm repositories..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add stable https://charts.helm.sh/stable
helm repo update
echo -e "${GREEN}✓${NC} Repositories updated\n"

# Step 5: Create values file for ArgoCD
echo -e "${CYAN}→${NC} Creating ArgoCD Helm values..."
cat > /tmp/argocd-values.yaml <<EOF
global:
  domain: $DOMAIN

server:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
  
  service:
    type: ClusterIP
  
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - argocd.$DOMAIN
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.$DOMAIN
  
  config:
    application.instanceLabelKey: argocd.argoproj.io/instance
    server.disable.auth: "false"
    server.insecure: "false"
    
    oidc.config: |
      name: Keycloak
      issuer: https://keycloak.$DOMAIN/realms/master
      clientID: argocd
      clientSecret: \$oidc.keycloak.clientSecret
      requestedScopes:
        - openid
        - profile
        - email
        - groups
    
    repositories: |
      - type: git
        url: https://github.com/ceres-platform/ceres-helm-charts
        passwordSecret:
          name: argocd-repo-creds
          key: sshPrivateKey

repoServer:
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
  
  volumeMounts:
    - name: cmp-tmp
      mountPath: /tmp
  
  initContainers:
    - name: download-tools
      image: alpine:3.18
      command:
        - sh
        - -c
      args:
        - wget https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64 -O /tmp/jq && chmod +x /tmp/jq

redis:
  enabled: true
  auth:
    enabled: true
  master:
    persistence:
      enabled: true
      size: 10Gi

controller:
  replicas: 2
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

applicationSet:
  enabled: true
  replicas: 2

notifications:
  enabled: true
  argocdUrl: https://argocd.$DOMAIN
  
  notifiers:
    service.slack: |
      token: \$slack.token
    service.teams: |
      webhookUrl: \$teams.webhookUrl

metrics:
  enabled: true
  serviceMonitor:
    enabled: true

rbac:
  create: true
  policyDefault: role:readonly
EOF

echo -e "${GREEN}✓${NC} Values file created\n"

# Step 6: Install ArgoCD via Helm
echo -e "${CYAN}→${NC} Installing ArgoCD with Helm..."
helm upgrade --install "$RELEASE_NAME" argo/argo-cd \
    --namespace "$NAMESPACE" \
    --values /tmp/argocd-values.yaml \
    --wait \
    --timeout 10m \
    --version 6.0.0

echo -e "${GREEN}✓${NC} ArgoCD installed\n"

# Step 7: Wait for ArgoCD to be ready
echo -e "${CYAN}→${NC} Waiting for ArgoCD to be ready..."
kubectl rollout status deployment/argocd-server -n "$NAMESPACE" --timeout=5m
kubectl rollout status deployment/argocd-repo-server -n "$NAMESPACE" --timeout=5m
echo -e "${GREEN}✓${NC} ArgoCD is ready\n"

# Step 8: Apply custom configurations
echo -e "${CYAN}→${NC} Applying ArgoCD configurations..."
kubectl apply -f config/argocd/argocd-install.yml -n "$NAMESPACE"
kubectl apply -f config/argocd/applicationset.yml -n "$NAMESPACE"
echo -e "${GREEN}✓${NC} Configurations applied\n"

# Step 9: Get access information
echo -e "${CYAN}→${NC} Retrieving access information...\n"

ARGOCD_URL="https://argocd.$DOMAIN"
ARGOCD_PASSWORD=$(kubectl get secret argocd-secret -n "$NAMESPACE" -o jsonpath='{.data.admin\.password}' 2>/dev/null || echo "Check secret manually")

echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}ArgoCD Access Information${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "URL:      ${GREEN}$ARGOCD_URL${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}$ADMIN_PASSWORD${NC}"
echo -e "\n${YELLOW}Port Forward (Local Access):${NC}"
echo -e "kubectl port-forward -n $NAMESPACE svc/argocd-server 8080:443"
echo -e "\n${YELLOW}Login via CLI:${NC}"
echo -e "argocd login argocd.$DOMAIN"
echo -e "\n${YELLOW}Add External Cluster:${NC}"
echo -e "argocd cluster add <cluster-context>"
echo -e "\n${YELLOW}Create Application:${NC}"
echo -e "argocd app create ceres --repo https://github.com/ceres-platform/ceres-helm-charts --path helm/ceres --dest-server https://kubernetes.default.svc --dest-namespace ceres"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}\n"

# Step 10: Verify installation
echo -e "${CYAN}→${NC} Verifying installation..."
echo -e "\n${YELLOW}ArgoCD Pods:${NC}"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=argocd

echo -e "\n${YELLOW}ArgoCD Services:${NC}"
kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=argocd

echo -e "\n${YELLOW}Network Policies:${NC}"
kubectl get networkpolicies -n "$NAMESPACE"

echo -e "\n${GREEN}✓${NC} ArgoCD deployment complete!\n"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}CERES GitOps Platform (v2.8.0) is Ready!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}\n"

# Display next steps
echo -e "${CYAN}Next Steps:${NC}"
echo -e "1. Access ArgoCD: $ARGOCD_URL"
echo -e "2. Connect your Git repository"
echo -e "3. Create applications for auto-deployment"
echo -e "4. Setup notifications (Slack/Teams)"
echo -e "5. Configure multi-cluster management"
echo -e "6. Enable image auto-updates\n"
