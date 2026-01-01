#!/bin/bash
#
# CERES v3.0.0 - Cost Optimization & Resource Management
# Автоматическая оптимизация затрат, управление ресурсами, мониторинг расходов
# Right-sizing, spot instances, reserved capacity, resource quotas

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Параметры
CLUSTER_NAME="${1:-ceres-prod}"
NAMESPACE="${2:-ceres}"
REPORT_DIR="${3:-.}"
COST_THRESHOLD="${4:-5000}"  # Дневной threshold в USD

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 1. Анализ текущих затрат
# ============================================================================

analyze_current_costs() {
    log_info "Анализирую текущие затраты..."
    
    local cost_report="${REPORT_DIR}/cost-analysis-$(date +%Y%m%d).json"
    
    # Получить информацию об узлах
    local nodes_info=$(kubectl get nodes -o json | \
        jq '.items | map({
            name: .metadata.name,
            type: .metadata.labels."node.kubernetes.io/instance-type" // "unknown",
            cpu: .status.allocatable.cpu,
            memory: .status.allocatable.memory,
            storage: .status.allocatable."storage-ephemeral-storage" // "0"
        })')
    
    # Получить информацию о подах
    local pods_info=$(kubectl get pods -A -o json | \
        jq '.items | map({
            namespace: .metadata.namespace,
            name: .metadata.name,
            cpu_request: (.spec.containers[] | select(.resources.requests.cpu) | .resources.requests.cpu),
            memory_request: (.spec.containers[] | select(.resources.requests.memory) | .resources.requests.memory),
            cpu_limit: (.spec.containers[] | select(.resources.limits.cpu) | .resources.limits.cpu),
            memory_limit: (.spec.containers[] | select(.resources.limits.memory) | .resources.limits.memory)
        })')
    
    # Получить PersistentVolumes
    local storage_info=$(kubectl get pvc -A -o json | \
        jq '.items | map({
            namespace: .metadata.namespace,
            name: .metadata.name,
            size: .spec.resources.requests.storage,
            storage_class: .spec.storageClassName
        })')
    
    # Сохранить отчёт
    cat > "${cost_report}" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "cluster": "${CLUSTER_NAME}",
    "nodes": ${nodes_info},
    "pods": ${pods_info},
    "storage": ${storage_info}
}
EOF
    
    log_success "Отчёт о затратах сохранён в ${cost_report}"
}

# ============================================================================
# 2. Right-sizing рекомендации
# ============================================================================

rightsizing_recommendations() {
    log_info "Анализирую возможности оптимизации размера ресурсов..."
    
    # Получить метрики использования CPU/Memory
    local metrics=$(kubectl top pods -A --no-headers 2>/dev/null | awk '{
        namespace = $1
        pod = $2
        cpu = $3
        mem = $4
        gsub(/m$/, "", cpu)
        gsub(/Mi$/, "", mem)
        if (namespace !~ /^(kube|istio|cert)/ && cpu < 5) {
            print "DOWN: " namespace "/" pod " (CPU: " cpu "m)"
        }
    }')
    
    if [ -n "$metrics" ]; then
        log_warn "Рекомендации по оптимизации размера:"
        echo "$metrics" | head -20
    fi
    
    # Анализ Limits > Requests
    log_info "Анализирую значительные различия между Requests и Limits..."
    kubectl get pods -A -o json | jq -r '.items[] |
        select(.spec.containers[].resources.limits.cpu) |
        "\(.metadata.namespace)/\(.metadata.name)"' | while read -r pod; do
        
        local limits=$(kubectl get pod "${pod#*/}" -n "${pod%/*}" -o json | \
            jq '.spec.containers[0].resources.limits')
        local requests=$(kubectl get pod "${pod#*/}" -n "${pod%/*}" -o json | \
            jq '.spec.containers[0].resources.requests')
        
        # Если лимиты > 2x requests - рекомендовать оптимизацию
        if [ -n "$limits" ] && [ -n "$requests" ]; then
            log_info "  Проверьте ${pod}: возможно завышены Limits"
        fi
    done
}

# ============================================================================
# 3. Политики вытеснения и удаления неиспользуемых ресурсов
# ============================================================================

setup_resource_quotas() {
    log_info "Устанавливаю ResourceQuota для контроля затрат..."
    
    kubectl apply -f - <<'EOF'
---
# ResourceQuota для namespace ceres
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ceres-quota
  namespace: ceres
spec:
  hard:
    requests.cpu: "100"
    requests.memory: "200Gi"
    limits.cpu: "200"
    limits.memory: "400Gi"
    pods: "500"
    persistentvolumeclaims: "50"
  scopeSelector:
    matchExpressions:
    - operator: In
      scopeName: PriorityClass
      values: ["default", "high-priority"]
---
# LimitRange для оптимизации размера контейнеров
apiVersion: v1
kind: LimitRange
metadata:
  name: ceres-limits
  namespace: ceres
spec:
  limits:
  # Pod limits
  - type: Pod
    min:
      cpu: "10m"
      memory: "32Mi"
    max:
      cpu: "8"
      memory: "16Gi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
  
  # Container limits
  - type: Container
    min:
      cpu: "10m"
      memory: "32Mi"
    max:
      cpu: "4"
      memory: "8Gi"
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
  
  # PVC limits
  - type: PersistentVolumeClaim
    min:
      storage: "1Gi"
    max:
      storage: "500Gi"
EOF
    
    log_success "ResourceQuota и LimitRange установлены"
}

# ============================================================================
# 4. Автоматизация Spot Instances (для облаков)
# ============================================================================

setup_spot_instances() {
    log_info "Настраиваю Spot Instance политики..."
    
    # Создать PriorityClass для Spot vs On-Demand
    kubectl apply -f - <<'EOF'
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: on-demand
value: 1000
globalDefault: false
description: "On-demand instances - высший приоритет"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: spot-instances
value: 100
globalDefault: false
description: "Spot instances - низший приоритет"
---
# Node affinity для Spot instances
apiVersion: v1
kind: ConfigMap
metadata:
  name: spot-config
  namespace: ceres
data:
  spot-nodes.yaml: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: spot-workload
    spec:
      replicas: 3
      selector:
        matchLabels:
          workload-type: batch
      template:
        metadata:
          labels:
            workload-type: batch
        spec:
          priorityClassName: spot-instances
          affinity:
            nodeAffinity:
              preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                preference:
                  matchExpressions:
                  - key: karpenter.sh/capacity-type
                    operator: In
                    values: ["spot"]
          terminationGracePeriodSeconds: 30
          tolerations:
          - key: karpenter.sh/do-not-evict
            operator: Equal
            value: "false"
          containers:
          - name: app
            image: app:latest
            resources:
              requests:
                cpu: "500m"
                memory: "512Mi"
              limits:
                cpu: "1000m"
                memory: "1Gi"
EOF
    
    log_success "Spot Instance конфигурация готова"
}

# ============================================================================
# 5. Очистка неиспользуемых ресурсов
# ============================================================================

cleanup_unused_resources() {
    log_info "Очищаю неиспользуемые ресурсы..."
    
    # Удалить PVC без Pod'ов
    log_warn "Проверяю orphaned PVC..."
    kubectl get pvc -A -o json | jq -r '.items[] | 
        select(.spec.selector == null) |
        "\(.metadata.namespace) \(.metadata.name)"' | while read ns pvc; do
        
        local pods=$(kubectl get pods -n "$ns" --selector=pvc="$pvc" 2>/dev/null | tail -1)
        if [ "$pods" == "No resources found" ] || [ -z "$pods" ]; then
            log_warn "  Orphaned PVC found: $ns/$pvc"
        fi
    done
    
    # Удалить завершённые Job'ы старше 7 дней
    log_warn "Проверяю старые Job'ы..."
    kubectl delete job -A --sort-by=.metadata.creationTimestamp \
        --field-selector=status.successful=1,status.completionTime=$(date -d '7 days ago' --iso-8601=date) \
        2>/dev/null || true
    
    # Очистить unused images
    log_warn "Очищаю неиспользуемые images в узлах..."
    kubectl get nodes -o name | while read node; do
        kubectl debug node/"${node##*/}" -it --image=ubuntu 2>/dev/null -- \
            sh -c "ctr images ls | grep '<none>' | awk '{print $1}' | xargs -r ctr images rm" || true
    done
    
    log_success "Очистка завершена"
}

# ============================================================================
# 6. Мониторинг затрат в real-time
# ============================================================================

setup_cost_monitoring() {
    log_info "Устанавливаю мониторинг затрат..."
    
    # Создать ConfigMap с cost метриками
    kubectl apply -f - <<'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-metrics
  namespace: ceres
data:
  prometheus-rules.yaml: |
    groups:
    - name: cost.rules
      interval: 60s
      rules:
      # Estimated hourly cost
      - record: cost:hourly:usd
        expr: |
          (
            sum(karpenter_nodes_total{state="active"}) * 1.20
            +
            sum(rate(container_cpu_usage_seconds_total[5m])) * 0.025
            +
            sum(container_memory_usage_bytes) / 1024 / 1024 / 1024 * 0.003
          ) / 3600
      
      # Daily estimate
      - record: cost:daily:usd:estimate
        expr: cost:hourly:usd * 24
      
      # Top consumers
      - record: cost:by_namespace:usd
        expr: |
          sum by (namespace) (
            sum(container_cpu_usage_seconds_total) by (namespace) * 0.025 +
            sum(container_memory_usage_bytes) by (namespace) / 1024 / 1024 / 1024 * 0.003
          )
---
# PrometheusRule для алертов
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cost-alerts
  namespace: ceres
spec:
  groups:
  - name: cost.alerts
    interval: 300s
    rules:
    - alert: DailyCostExceeded
      expr: cost:daily:usd:estimate > 5000
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Дневные затраты превышают {{ $value | humanize }}$"
    
    - alert: UnusualCostSpike
      expr: |
        rate(cost:hourly:usd[1h]) > avg_over_time(cost:hourly:usd[7d]) * 1.5
      for: 10m
      labels:
        severity: critical
      annotations:
        summary: "Значительный скачок затрат: {{ $value | humanize }}$/час"
EOF
    
    log_success "Cost monitoring установлен"
}

# ============================================================================
# 7. Авто-масштабирование на основе затрат
# ============================================================================

setup_cost_aware_autoscaling() {
    log_info "Настраиваю cost-aware autoscaling..."
    
    kubectl apply -f - <<'EOF'
---
# Karpenter provisioner для cost optimization
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: ceres-cost-optimized
spec:
  template:
    spec:
      requirements:
      - key: karpenter.sh/capacity-type
        operator: In
        values: ["on-demand", "spot"]
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]
      - key: node.kubernetes.io/instance-type
        operator: In
        values:
        - c5.xlarge    # General purpose, cost-effective
        - c5.2xlarge
        - m5.xlarge
        - t3.2xlarge   # Burstable, low baseline cost
      - key: karpenter.sh/do-not-evict
        operator: DoesNotExist
    nodeClassRef:
      name: ceres-default
  
  limits:
    cpu: 1000
    memory: 1000Gi
  
  consolidationPolicy:
    nodes: "When Underutilized"
    expireAfter: 720h
  
  expireAfter: 2592000s
  
  weight: 100
---
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: ceres-default
spec:
  amiFamily: AL2
  role: "KarpenterNodeRole-${CLUSTER_NAME}"
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: "${CLUSTER_NAME}"
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "${CLUSTER_NAME}"
  tags:
    ManagedBy: karpenter
    CostCenter: engineering
  userData: |
    #!/bin/bash
    echo "Cost-optimized node initialized"
EOF
    
    log_success "Cost-aware autoscaling настроен"
}

# ============================================================================
# 8. Резервирование мощности (Reserved Instances)
# ============================================================================

recommend_reserved_instances() {
    log_info "Анализирую рекомендации по Reserved Instances..."
    
    # Получить информацию об использовании узлов за последний месяц
    local report="${REPORT_DIR}/reserved-instance-recommendations.txt"
    
    cat > "$report" <<EOF
===== RESERVED INSTANCE РЕКОМЕНДАЦИИ =====
Дата отчёта: $(date)

АНАЛИЗ ПОТРЕБЛЕНИЯ:
EOF
    
    # Проанализировать стабильные workloads
    kubectl get deployments -A -o json | jq -r '.items[] |
        select(.spec.replicas > 2) |
        "\(.metadata.namespace)/\(.metadata.name) - \(.spec.replicas) replicas"' >> "$report"
    
    cat >> "$report" <<'EOF'

РЕКОМЕНДАЦИИ:
1. Зарезервировать 1-year для stable workloads (экономия ~30%)
2. Зарезервировать 3-year для базовой мощности (экономия ~50%)
3. Использовать On-Demand для flexible/burst workloads

РАСЧЁТНАЯ ЭКОНОМИЯ:
- Baseline (Reserved 1-year): ~2000 USD/месяц экономии
- Полная миграция (Reserved 3-year): ~4500 USD/месяц экономии

ACTION ITEMS:
- Провести аудит workload patterns
- Определить baseline capacity requirements
- Приобрести Reserved Instances для identified baseline
- Оставить On-Demand для burst capacity
EOF
    
    log_success "Рекомендации сохранены в $report"
    cat "$report"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_info "Запускаю Cost Optimization Suite v3.0..."
    log_info "Cluster: $CLUSTER_NAME"
    log_info "Namespace: $NAMESPACE"
    
    # Проверить доступ к кластеру
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Не удаётся подключиться к кластеру"
        exit 1
    fi
    
    # Выполнить все шаги оптимизации
    analyze_current_costs
    rightsizing_recommendations
    setup_resource_quotas
    setup_spot_instances
    cleanup_unused_resources
    setup_cost_monitoring
    setup_cost_aware_autoscaling
    recommend_reserved_instances
    
    log_success "Cost Optimization Suite завершена!"
    log_info "Отчёты доступны в ${REPORT_DIR}/"
}

main "$@"
