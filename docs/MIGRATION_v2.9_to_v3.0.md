# CERES v3.0.0 - Migration Guide (v2.9 → v3.0)
# Production upgrade playbook with zero-downtime strategy

## Версия: v3.0.0
## Дата: January 2026
## Статус: Production Ready
## Breaking Changes: None

---

## Содержание
1. [Что нового в v3.0.0](#что-нового)
2. [Требования](#требования)
3. [Pre-Migration Checklist](#pre-migration-checklist)
4. [Migration Procedure](#migration-procedure)
5. [Validation & Testing](#validation--testing)
6. [Rollback Plan](#rollback-plan)
7. [Performance Verification](#performance-verification)
8. [FAQ & Troubleshooting](#faq--troubleshooting)

---

## Что нового

### 🎯 Основные улучшения v3.0.0

#### 1. Service Mesh Integration (Istio)
- **mTLS** для всех pod-to-pod коммуникаций
- **Traffic Management** - advanced routing, load balancing, circuit breaking
- **Observability** - distributed tracing, metrics collection, traffic visualization
- **Security** - AuthorizationPolicy, RequestAuthentication, PeerAuthentication
- **HA Configuration** - 3 istiod replicas, 3 ingress gateways

**Файлы:**
- `config/istio/istio-install.yml` (600+ строк)

#### 2. Cost Optimization Suite
- **Right-sizing** рекомендации для контейнеров
- **Spot Instances** интеграция (AWS, GCP)
- **Reserved Instances** анализ и рекомендации
- **Resource Quotas** и LimitRange для контроля затрат
- **Cost monitoring** в real-time с Prometheus

**Файлы:**
- `scripts/cost-optimization.sh` (600+ строк)

#### 3. Multi-Cloud Deployment
- **AWS EKS** с Karpenter для auto-scaling
- **Azure AKS** с Virtual Machine Scale Sets
- **Google GKE** с Autopilot (fully managed)
- **Hybrid Deployment** поддержка edge locations
- **Infrastructure-as-Code** полный Terraform stack

**Файлы:**
- `config/terraform/multi-cloud.tf` (1000+ строк)

#### 4. Production Hardening
- **Pod Security Policies** (PSP) для isolation
- **Network Policies** - default DENY all
- **RBAC** - least privilege service accounts
- **Audit Logging** - полная аудит трейл
- **Runtime Security** - Falco integration
- **Secrets Encryption** - at-rest и in-transit

**Файлы:**
- `config/security/hardening-policies.yml` (600+ строк)

#### 5. Performance Tuning
- **Kernel Optimization** - TCP buffer, connection handling
- **Container Runtime** - containerd optimization
- **Kubelet Tuning** - CPU pinning, NUMA awareness
- **etcd Optimization** - WAL, snapshot config
- **Network Performance** - BBR congestion control
- **Storage Optimization** - I/O scheduler, read-ahead

**Файлы:**
- `scripts/performance-tuning.yml` (500+ строк)

---

## Требования

### Minimum Requirements

```yaml
Kubernetes: v1.28 или выше
Nodes: 3 (minimum для HA)
CPU: 4 cores per node (рекомендуется 8+)
Memory: 8 GB per node (рекомендуется 16+ GB)
Storage: 100 GB (быстрое дисковое хранилище)
Network: 1Gbps+ (рекомендуется 10Gbps)
```

### Software Requirements

```bash
# CLI tools
kubectl v1.28+
helm 3.12+
istioctl 1.20+
terraform 1.0+
ansible 2.10+

# Kubernetes add-ons
metrics-server v0.6+
ingress-nginx или Istio
cert-manager 1.13+
```

### Permission Requirements

```yaml
- ClusterAdmin access (для миграции)
- Service account с admin permissions
- IAM/RBAC permissions для облачных провайдеров
```

---

## Pre-Migration Checklist

### ✅ Шаг 1: Backup текущей системы

```bash
# Backup etcd
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /tmp/etcd-backup-$(date +%Y%m%d).db

# Verify
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup-*.db

# Backup Kubernetes resources
kubectl get all -A -o yaml > /tmp/k8s-backup-$(date +%Y%m%d).yaml
kubectl get pvc -A -o yaml >> /tmp/k8s-backup-$(date +%Y%m%d).yaml
kubectl get pv -o yaml >> /tmp/k8s-backup-$(date +%Y%m%d).yaml
```

### ✅ Шаг 2: Проверка совместимости

```bash
# Проверить версию Kubernetes
kubectl version --short

# Проверить resource requirements
kubectl top nodes
kubectl top pods -A

# Проверить available PVs
kubectl get pv

# Verify node health
kubectl get nodes -o wide
kubectl describe nodes | grep -E "Ready|DiskPressure|MemoryPressure"
```

### ✅ Шаг 3: Drain подготовка

```bash
# Проверить pods, которые будут вытеснены
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== Node: $node ==="
  kubectl drain $node --dry-run=client --ignore-daemonsets --delete-emptydir-data
done

# Повысить PodDisruptionBudget значения
kubectl patch pdb <name> -n <ns> -p '{"spec":{"minAvailable":null,"maxUnavailable":2}}'
```

### ✅ Шаг 4: Проверить image registry

```bash
# Verify docker/container registry access
kubectl run registry-test --image=curlimages/curl --rm -it \
  -- sh -c 'curl -v https://registry.ceres.io/v2/_catalog'

# List all images in use
kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

### ✅ Шаг 5: Документировать текущее состояние

```bash
# Current version info
kubectl version > /tmp/pre-migration-k8s-version.txt
istioctl version >> /tmp/pre-migration-k8s-version.txt || true
helm version >> /tmp/pre-migration-k8s-version.txt

# Cluster info
kubectl cluster-info dump --output-directory=/tmp/k8s-cluster-dump-$(date +%Y%m%d)
```

---

## Migration Procedure

### Фаза 1: Istio Service Mesh Installation (90 минут)

```bash
# 1. Install Istio using IstioOperator
kubectl create namespace istio-system
kubectl apply -f config/istio/istio-install.yml

# Wait for Istio to be ready
kubectl wait --for=condition=ready pod \
  -l app=istiod -n istio-system --timeout=300s

# Verify istiod
kubectl get pod -n istio-system -l app=istiod
kubectl logs -n istio-system -l app=istiod --tail=50

# 2. Enable sidecar injection
kubectl label namespace ceres istio-injection=enabled

# 3. Apply Istio configuration
kubectl apply -f config/istio/istio-install.yml

# 4. Verify gateways are ready
kubectl get gateway -n istio-system
kubectl get ingressgateway -n istio-system
```

### Фаза 2: Cost Optimization Setup (60 минут)

```bash
# 1. Run cost optimization script
./scripts/cost-optimization.sh ceres-prod ceres /tmp/cost-reports

# 2. Apply resource quotas
kubectl apply -f config/security/hardening-policies.yml

# 3. Set up monitoring
kubectl create configmap cost-metrics -n ceres \
  --from-file=prometheus-rules.yaml=<(...)

# 4. Verify quotas
kubectl describe resourcequota -n ceres
kubectl describe limitrange -n ceres
```

### Фаза 3: Multi-Cloud Infrastructure (120 минут)

```bash
# 1. Prepare Terraform variables
cat > terraform.tfvars <<EOF
aws_region = "eu-west-1"
azure_region = "westeurope"
gcp_project = "ceres-prod"
gcp_region = "europe-west1"
EOF

# 2. Validate Terraform
cd config/terraform
terraform init
terraform validate
terraform plan -out=tfplan

# 3. Apply Terraform (dry-run first in staging)
# terraform apply tfplan

# 4. Verify cloud resources
aws eks describe-cluster --name ceres-prod
az aks show --resource-group rg-ceres-prod --name ceres-aks
gcloud container clusters describe ceres-gke --region europe-west1
```

### Фаза 4: Security Hardening (120 минут)

```bash
# 1. Apply security policies
kubectl apply -f config/security/hardening-policies.yml

# 2. Verify PSP
kubectl get psp
kubectl describe psp ceres-restricted

# 3. Apply network policies
kubectl apply -f config/security/hardening-policies.yml -l network-policy=true

# 4. Check audit logging
grep "audit-log" /etc/kubernetes/manifests/kube-apiserver.yaml

# 5. Verify secrets encryption
grep "encryption" /etc/kubernetes/manifests/kube-apiserver.yaml
```

### Фаза 5: Performance Tuning (90 минут)

```bash
# 1. Run performance playbook
ansible-playbook -i inventory.yml scripts/performance-tuning.yml

# 2. Verify kernel parameters
sysctl -a | grep net.core.rmem_max
sysctl -a | grep tcp_congestion_control

# 3. Check kubelet config
kubectl get node <node> -o jsonpath='{.metadata.annotations}' | grep kubelet

# 4. Monitor node utilization
kubectl top nodes
```

### Фаза 6: Migration Validation (60 минут)

```bash
# 1. Drain and update nodes (rolling update)
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Draining $node..."
  kubectl drain $node --ignore-daemonsets --delete-emptydir-data
  
  # Update node (depends on your cluster management)
  # ssh <node> "sudo apt update && sudo apt upgrade -y"
  
  echo "Uncordoning $node..."
  kubectl uncordon $node
  
  # Wait for readiness
  kubectl wait --for=condition=ready node/$node --timeout=300s
done

# 2. Verify all pods are running
kubectl get pods -A --field-selector=status.phase!=Running

# 3. Run connectivity tests
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://api.ceres.svc.cluster.local:8080/health
```

---

## Validation & Testing

### ✅ Health Checks

```bash
#!/bin/bash
# health-check.sh

echo "=== Kubernetes Cluster Health ==="
kubectl cluster-info
kubectl get nodes -o wide
kubectl get componentstatuses

echo "=== Pod Health ==="
kubectl get pods -A --field-selector=status.phase!=Running

echo "=== Istio Health ==="
kubectl get pods -n istio-system
istioctl analyze

echo "=== Storage Health ==="
kubectl get pv,pvc -A

echo "=== Service Mesh Connectivity ==="
kubectl logs -l app=api-server -n ceres --tail=20

echo "=== Cost Metrics ==="
kubectl get --raw /metrics | grep cost:hourly || true
```

### ✅ Performance Baseline

```bash
# 1. Measure API server latency
kubectl top nodes
kubectl top pods -A --containers

# 2. Run load test
kubectl run -it --rm load-test --image=loadimpact/k6 --restart=Never -- \
  k6 run - <<'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';

export default function() {
  let response = http.get('http://api.ceres.svc.cluster.local:8080/api/health');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 100ms': (r) => r.timings.duration < 100,
  });
  sleep(1);
}
EOF

# 3. Monitor during load
kubectl top nodes --containers
```

---

## Rollback Plan

```bash
# If something goes wrong, rollback is straightforward:

# 1. Restore from etcd backup (if needed)
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup-*.db \
  --data-dir=/var/lib/etcd-backup

# 2. Remove Istio (if issues)
kubectl delete -f config/istio/istio-install.yml
kubectl delete namespace istio-system

# 3. Remove security policies (if blocking workloads)
kubectl delete psp ceres-restricted
kubectl delete networkpolicies -A --selector=managed-by=ceres

# 4. Restore previous Kubernetes version
# This depends on your cluster management approach
```

---

## Performance Verification

### Network Performance

```bash
# TCP throughput test
iperf3 -s &
kubectl run iperf-client --image=networkstatic/iperf3 -- \
  iperf3 -c <service-ip> -t 10

# DNS resolution performance
time kubectl exec -it <pod> -- nslookup api.ceres.svc.cluster.local
```

### Storage Performance

```bash
# PVC I/O benchmark
kubectl run -it --rm fio --image=ljishen/fio --restart=Never -- \
  fio --name=random-read --ioengine=libaio --iodepth=32 \
  --rw=randread --bs=4k --direct=1 --size=1G --numjobs=4 \
  --runtime=60 --group_reporting
```

### Application Performance

```bash
# Check tail latencies
kubectl logs <pod> | grep "latency_p99"

# Monitor resource usage
kubectl top pods -n ceres --containers

# Check cache hit rates
kubectl logs <pod> | grep "cache.*hit"
```

---

## FAQ & Troubleshooting

### Q: Сколько времени займет миграция?
**A:** ~8-10 часов в зависимости от размера кластера и нагрузки

### Q: Будет ли downtime?
**A:** Нет, используется rolling update с PodDisruptionBudget

### Q: Какой disk space нужен?
**A:** ~50GB для backup, ~20GB для новых компонентов

### Q: Что делать если pod не запускается?
```bash
# 1. Проверить logs
kubectl logs <pod> -n <namespace>

# 2. Описать pod
kubectl describe pod <pod> -n <namespace>

# 3. Проверить events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Q: Как откатиться если что-то сломалось?
**A:** Используйте rollback процедуру выше

### Q: Совместима ли v3.0 с моими старыми приложениями?
**A:** Да, полная обратная совместимость. Старые приложения продолжат работать без изменений.

### Типичные проблемы и решения

#### Istio pod не запускается
```bash
# Проверить логи
kubectl logs -n istio-system -l app=istiod

# Проверить ресурсы
kubectl describe node <node>

# Увеличить timeout
kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 1000m
            memory: 1024Mi
EOF
```

#### Network policy блокирует трафик
```bash
# Временно удалить
kubectl delete networkpolicies --all -n ceres

# После отладки, применить корректную политику
kubectl apply -f config/security/hardening-policies.yml
```

#### Cost optimization не собирает метрики
```bash
# Проверить ConfigMap
kubectl get cm cost-metrics -n ceres -o yaml

# Перезагрузить Prometheus
kubectl rollout restart deployment/prometheus -n monitoring
```

---

## Post-Migration Validation

```bash
# Final checklist

# 1. All pods running
kubectl get pods -A --field-selector=status.phase!=Running

# 2. Service mesh healthy
istioctl analyze
kubectl get virtualservices -A

# 3. Cost tracking enabled
kubectl get configmap cost-metrics -n ceres

# 4. Security policies in place
kubectl get psp
kubectl get networkpolicies -A

# 5. Performance baseline met
kubectl top nodes
kubectl top pods -A | head -20
```

---

**Migration completed successfully!** 🎉

Теперь CERES v3.0.0 полностью:
- ✅ Service mesh enabled
- ✅ Cost optimized
- ✅ Multi-cloud ready
- ✅ Security hardened
- ✅ Performance tuned
- ✅ Production grade
