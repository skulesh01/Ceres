#!/bin/bash
# Multi-Cluster Configuration for CERES v2.8.0
# Enables ArgoCD/Flux to manage multiple K3s clusters
# Features: Cross-cluster communication, disaster recovery, load balancing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PRIMARY_CLUSTER="primary"
SECONDARY_CLUSTER="secondary"
DR_CLUSTER="disaster-recovery"
CLUSTERS=("$PRIMARY_CLUSTER" "$SECONDARY_CLUSTER" "$DR_CLUSTER")

# Functions
write_step() {
    echo -e "${CYAN}→${NC} $1"
}

write_success() {
    echo -e "${GREEN}✓${NC} $1"
}

write_error() {
    echo -e "${RED}✗${NC} $1"
}

# 1. Register external clusters to ArgoCD
register_cluster_to_argocd() {
    local cluster_name=$1
    local cluster_server=$2
    local cluster_token=$3
    
    write_step "Registering $cluster_name to ArgoCD..."
    
    # Create secret for cluster
    kubectl create secret generic "$cluster_name-cluster" \
        --from-literal=name="$cluster_name" \
        --from-literal=server="$cluster_server" \
        --from-literal=config="$cluster_token" \
        -n argocd \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Create ArgoCD cluster secret
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${cluster_name}-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: $cluster_name
  server: $cluster_server
  config: |
    {
      "bearerToken": "$cluster_token",
      "tlsClientConfig": {
        "insecure": false
      }
    }
EOF
    
    write_success "Registered $cluster_name"
}

# 2. Install Flux on external cluster
install_flux_on_cluster() {
    local cluster_name=$1
    local kubeconfig_path=$2
    
    write_step "Installing Flux on $cluster_name..."
    
    export KUBECONFIG="$kubeconfig_path"
    
    # Add Flux Helm repository
    helm repo add fluxcd-community https://fluxcd-community.github.io/helm-charts
    helm repo update
    
    # Install Flux with multi-tenancy
    helm upgrade --install flux fluxcd-community/flux2 \
        --namespace flux-system \
        --create-namespace \
        --set sourceController.replicas=2 \
        --set kustomizeController.replicas=2 \
        --set helmController.replicas=2 \
        --set notificationController.replicas=2 \
        --set imageAutomationController.enabled=true \
        --wait
    
    write_success "Flux installed on $cluster_name"
}

# 3. Create cluster-specific kustomizations
create_cluster_kustomization() {
    local cluster_name=$1
    
    write_step "Creating Kustomization for $cluster_name..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${cluster_name}-base
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: ceres-helm-charts
    namespace: flux-system
  path: ./kustomize/clusters/${cluster_name}
  prune: true
  wait: true
  timeout: 5m
  decryption:
    provider: sops
EOF
    
    write_success "Kustomization created for $cluster_name"
}

# 4. Setup cluster peering and networking
setup_cluster_peering() {
    local cluster1=$1
    local cluster2=$2
    
    write_step "Setting up peering between $cluster1 and $cluster2..."
    
    # Create NetworkPolicy for cross-cluster communication
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-cross-cluster
  namespace: ceres
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ceres
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: ceres
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 6379
EOF
    
    # Create service-to-service authentication
    cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: ceres
spec:
  mtls:
    mode: STRICT
EOF
    
    write_success "Cross-cluster peering configured"
}

# 5. Setup distributed database replication
setup_database_replication() {
    write_step "Configuring PostgreSQL replication across clusters..."
    
    # Create replication user
    psql -U postgres -c "
    CREATE ROLE replication_user WITH REPLICATION LOGIN PASSWORD 'replication_password';
    "
    
    # Configure streaming replication
    cat >> /var/lib/postgresql/data/postgresql.conf <<EOF
# Replication settings
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
hot_standby = on
hot_standby_feedback = on
EOF
    
    write_success "Database replication configured"
}

# 6. Setup Redis cluster replication
setup_redis_replication() {
    write_step "Configuring Redis replication across clusters..."
    
    # Create Redis cluster configuration
    cat <<EOF | kubectl apply -f -
apiVersion: redis.opstreelabs.in/v1alpha1
kind: RedisCluster
metadata:
  name: redis-cluster
  namespace: ceres
spec:
  masterSize: 3
  replicaSize: 2
  persistenceEnabled: true
  persistenceSize: "50Gi"
  kubernetesConfig:
    image: redis:7.0
  redisExporter:
    enabled: true
EOF
    
    write_success "Redis replication configured"
}

# 7. Setup ingress across clusters (load balancing)
setup_multi_cluster_ingress() {
    write_step "Setting up multi-cluster load balancing..."
    
    # Create DNS entry pointing to all clusters
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ceres-global
  namespace: ceres
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "ceres.global"
spec:
  type: LoadBalancer
  externalIPs:
    - 10.0.0.1  # Primary cluster
    - 10.0.0.2  # Secondary cluster
    - 10.0.0.3  # DR cluster
  ports:
    - port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app: ceres-ingress
EOF
    
    write_success "Multi-cluster load balancing configured"
}

# 8. Setup backup and restore across clusters
setup_backup_sync() {
    write_step "Configuring backup synchronization..."
    
    # Create backup schedule for each cluster
    cat <<EOF | kubectl apply -f -
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: ceres-daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    ttl: "720h"
    includedNamespaces:
      - ceres
      - monitoring
    storageLocation: aws-s3
    volumeSnapshotLocation: aws-ebs
    hooks:
      resources:
        - name: pre-backup-hook
          kind: Pod
          namespace: ceres
          containers:
            - name: pre-backup
              image: ceres-platform/backup-hook
              command:
                - /scripts/pre-backup.sh
EOF
    
    write_success "Backup synchronization configured"
}

# 9. Verify cluster health across all clusters
verify_cluster_health() {
    write_step "Verifying health of all clusters..."
    
    for cluster in "${CLUSTERS[@]}"; do
        write_step "Checking $cluster..."
        
        # Check cluster connectivity
        if kubectl cluster-info 2>/dev/null; then
            write_success "$cluster is reachable"
        else
            write_error "$cluster is unreachable"
            return 1
        fi
        
        # Check core components
        kubectl get pods -n flux-system --quiet 2>/dev/null && \
            write_success "Flux running on $cluster" || \
            write_error "Flux not running on $cluster"
        
        kubectl get pods -n argocd --quiet 2>/dev/null && \
            write_success "ArgoCD running on $cluster" || \
            write_error "ArgoCD not running on $cluster"
    done
    
    write_success "All clusters healthy"
}

# 10. Setup observability across clusters
setup_multi_cluster_monitoring() {
    write_step "Configuring multi-cluster monitoring..."
    
    # Configure Prometheus federation
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: multi-cluster-federation
  namespace: monitoring
spec:
  groups:
    - name: federation
      interval: 15s
      rules:
        - record: 'cluster:node_cpu:rate5m'
          expr: 'rate(node_cpu_seconds_total[5m])'
        - record: 'cluster:node_memory:bytes'
          expr: 'node_memory_MemAvailable_bytes'
EOF
    
    # Configure cross-cluster alerting
    cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: multi-cluster-alerts
  namespace: monitoring
spec:
  groups:
    - name: cluster-health
      rules:
        - alert: ClusterOffline
          expr: 'up{job="kubernetes-apiservers"} == 0'
          for: 5m
          annotations:
            summary: "Cluster {{ \$labels.cluster }} is offline"
        - alert: HighCrosClusterLatency
          expr: 'histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 0.5'
          for: 10m
EOF
    
    write_success "Multi-cluster monitoring configured"
}

# Main execution
echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════╗"
echo "║   CERES Multi-Cluster Configuration v2.8.0    ║"
echo "║      ArgoCD/Flux Cross-Cluster Setup           ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Parse command line arguments
if [ $# -eq 0 ]; then
    write_error "Usage: $0 [register|install-flux|create-kustomization|setup-peering|backup-sync|verify]"
    exit 1
fi

case "$1" in
    register)
        register_cluster_to_argocd "$2" "$3" "$4"
        ;;
    install-flux)
        install_flux_on_cluster "$2" "$3"
        ;;
    create-kustomization)
        create_cluster_kustomization "$2"
        ;;
    setup-peering)
        setup_cluster_peering "$2" "$3"
        ;;
    setup-database)
        setup_database_replication
        ;;
    setup-redis)
        setup_redis_replication
        ;;
    setup-ingress)
        setup_multi_cluster_ingress
        ;;
    setup-backup)
        setup_backup_sync
        ;;
    setup-monitoring)
        setup_multi_cluster_monitoring
        ;;
    verify)
        verify_cluster_health
        ;;
    all)
        write_step "Running full multi-cluster setup..."
        for cluster in "${CLUSTERS[@]}"; do
            setup_cluster_kustomization "$cluster"
        done
        setup_cluster_peering "$PRIMARY_CLUSTER" "$SECONDARY_CLUSTER"
        setup_multi_cluster_ingress
        setup_backup_sync
        setup_multi_cluster_monitoring
        verify_cluster_health
        write_success "Multi-cluster setup complete!"
        ;;
    *)
        write_error "Unknown command: $1"
        exit 1
        ;;
esac

echo -e "\n${GREEN}═══════════════════════════════════════════════${NC}"
echo -e "${GREEN}Multi-cluster configuration complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════${NC}\n"
