# CERES Kubernetes Migration Guide (v2.7.0)

## Обзор

CERES v2.7.0 добавляет полную поддержку развертывания на **Kubernetes (K3s)** - легковесном и простом в управлении кластере Kubernetes.

Этот гайд описывает:
- Миграцию с Docker Compose на K8s
- Развертывание на K3s кластере
- Использование Helm charts
- Управление multi-tenancy в Kubernetes
- Операции и мониторинг
- Масштабирование сервисов

## Архитектура K3s для CERES

```
┌─────────────────────────────────────────────────────────┐
│                   CERES K3s Cluster                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Control Plane (3 мастера):                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │
│  │  Master 1   │ │  Master 2   │ │  Master 3   │      │
│  │ (etcd/API)  │ │ (etcd/API)  │ │ (etcd/API)  │      │
│  └─────────────┘ └─────────────┘ └─────────────┘      │
│                                                         │
│  Worker Nodes (3 воркера):                             │
│  ┌──────────────────┬──────────────────┬───────────┐  │
│  │   Worker 1       │   Worker 2       │  Worker 3 │  │
│  │                  │                  │           │  │
│  │ ┌─────────┐      │ ┌─────────┐     │ ┌──────┐ │  │
│  │ │ Postgres│      │ │ Postgres│     │ │Redis │ │  │
│  │ │ Pod+PV  │      │ │ Pod+PV  │     │ │Pod+PV│ │  │
│  │ └─────────┘      │ └─────────┘     │ └──────┘ │  │
│  │ ┌─────────┐      │ ┌─────────┐     │          │  │
│  │ │Keycloak │      │ │Nextcloud│     │          │  │
│  │ │Deployment      │ │Deployment     │          │  │
│  │ └─────────┘      │ └─────────┘     │          │  │
│  │ ┌─────────┐      │ ┌─────────┐     │          │  │
│  │ │ Gitea   │      │ │ Nginx   │     │          │  │
│  │ │Deployment      │ │Ingress  │     │          │  │
│  │ └─────────┘      │ └─────────┘     │          │  │
│  └──────────────────┴──────────────────┴───────────┘  │
│                                                         │
│  Persistent Storage:                                   │
│  ┌──────────────────────────────────────────────────┐ │
│  │ Local Path Provisioner                           │ │
│  │ ├─ /data/postgres (100Gi each x3)               │ │
│  │ ├─ /data/redis (50Gi each x3)                   │ │
│  │ ├─ /data/nextcloud (200Gi)                      │ │
│  │ ├─ /data/gitea (100Gi)                          │ │
│  │ └─ /data/prometheus (100Gi)                     │ │
│  └──────────────────────────────────────────────────┘ │
│                                                         │
│  Networking:                                           │
│  ├─ Nginx Ingress (port 80/443)                      │
│  ├─ Service Discovery (CoreDNS)                      │
│  ├─ Network Policies (tenant isolation)              │
│  └─ CNI (Flannel by default in K3s)                 │
│                                                         │
│  Monitoring:                                           │
│  ├─ Prometheus (metrics)                             │
│  ├─ Loki (logs)                                      │
│  ├─ Grafana (dashboards)                            │
│  └─ Jaeger (distributed tracing)                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Требования

### Системные требования

- **Мастер ноды (3 штуки):**
  - CPU: 4 ядра
  - RAM: 8GB
  - Disk: 50GB
  - OS: Linux (Ubuntu 20.04+ рекомендуется)

- **Worker ноды (3+ штук):**
  - CPU: 8 ядер
  - RAM: 16GB
  - Disk: 200GB (для сервисов и данных)
  - OS: Linux

### ПО

- K3s v1.29+
- kubectl 1.29+
- Helm 3.0+
- Docker (опционально, для образов)

## Установка K3s

### На первой мастер ноде:

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=ceres-cluster-token \
  INSTALL_K3S_VERSION=v1.29.1 \
  K3S_DATASTORE_ENDPOINT="postgres://pguser:pgpass@postgres.local:5432/k3s" \
  K3S_DATASTORE_CAFILE=/etc/ceres/ca.crt \
  K3S_DATASTORE_CERTFILE=/etc/ceres/cert.crt \
  K3S_DATASTORE_KEYFILE=/etc/ceres/key.key \
  sh -
```

### На других мастер нодах:

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=ceres-cluster-token \
  K3S_URL=https://master-0.ceres.local:6443 \
  INSTALL_K3S_VERSION=v1.29.1 \
  K3S_DATASTORE_ENDPOINT="postgres://pguser:pgpass@postgres.local:5432/k3s" \
  K3S_DATASTORE_CAFILE=/etc/ceres/ca.crt \
  K3S_DATASTORE_CERTFILE=/etc/ceres/cert.crt \
  K3S_DATASTORE_KEYFILE=/etc/ceres/key.key \
  sh -
```

### На worker нодах:

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=ceres-cluster-token \
  K3S_URL=https://master-0.ceres.local:6443 \
  INSTALL_K3S_VERSION=v1.29.1 \
  sh -
```

## Развертывание CERES

### 1. Быстрый старт (Linux/Mac)

```bash
cd /path/to/ceres
bash scripts/deploy-kubernetes.sh
```

### 2. Развертывание на Windows

```powershell
cd C:\path\to\ceres
.\scripts\Deploy-Kubernetes.ps1 -Namespace ceres -ReleaseName ceres
```

### 3. Ручное развертывание с Helm

```bash
# 1. Добавление репозиториев
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add codecentric https://codecentric.github.io/helm-charts
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Создание namespace
kubectl create namespace ceres

# 3. Создание секретов
kubectl create secret generic postgres-credentials \
  --from-literal=username=ceres_user \
  --from-literal=password=YOUR_PASSWORD \
  -n ceres

# 4. Развертывание CERES
helm install ceres ./helm/ceres -n ceres -f helm/ceres/values.yml

# 5. Проверка статуса
kubectl get pods -n ceres -w
```

## Компоненты K3s

### Core Services

```yaml
# PostgreSQL - StatefulSet с 3 репликами
StatefulSet: postgres
  Replicas: 3
  Storage: 100Gi per pod
  Service: postgres (ClusterIP)
  Headless: postgres-headless

# Redis - StatefulSet с 3 репликами
StatefulSet: redis
  Replicas: 3
  Storage: 50Gi per pod
  Service: redis (ClusterIP)
  Headless: redis-headless

# Keycloak - Deployment с 3 репликами
Deployment: keycloak
  Replicas: 3
  Service: keycloak (ClusterIP)
  Ingress: keycloak.ceres.local

# Nginx Ingress Controller - 3 инстанса
DaemonSet: nginx-ingress-controller
  Replicas: 3
  Service: ingress-nginx-controller (NodePort)

# Nextcloud - Deployment
Deployment: nextcloud
  Replicas: 3
  Storage: 200Gi shared
  Service: nextcloud
  Ingress: nextcloud.ceres.local

# Gitea - Deployment
Deployment: gitea
  Replicas: 2
  Storage: 100Gi
  Service: gitea
  Ingress: gitea.ceres.local

# Mattermost - Deployment
Deployment: mattermost
  Replicas: 3
  Storage: 50Gi
  Service: mattermost
  Ingress: mattermost.ceres.local

# Redmine, Wiki.js - Deployments
Deployment: redmine, wikijs
  Replicas: 2
  Storage: 50Gi each
  Services: redmine, wikijs
  Ingresses: redmine.ceres.local, wiki.ceres.local
```

### Storage Classes

```yaml
ceres-database:
  # PostgreSQL, Gitea, Redmine
  Provisioner: rancher.io/local-path
  ReclaimPolicy: Retain
  VolumeBindingMode: WaitForFirstConsumer

ceres-cache:
  # Redis
  Provisioner: rancher.io/local-path
  ReclaimPolicy: Retain
  VolumeBindingMode: WaitForFirstConsumer

ceres-files:
  # Nextcloud, shared storage
  Provisioner: rancher.io/local-path
  ReclaimPolicy: Retain
  VolumeBindingMode: WaitForFirstConsumer

ceres-logs:
  # Loki, log aggregation
  Provisioner: rancher.io/local-path
  ReclaimPolicy: Delete
  VolumeBindingMode: WaitForFirstConsumer
```

## Multi-Tenancy в Kubernetes

### Namespace-per-tenant模式

```bash
# 1. Создание namespace для тенанта
kubectl create namespace tenant-acme-corp

# 2. Применение Network Policy для изоляции
kubectl apply -f - << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-acme-corp
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          tenant-id: acme-corp
    - podSelector:
        matchLabels:
          role: ingress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          tenant-id: acme-corp
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
EOF

# 3. Развертывание сервиса тенанта
helm install tenant-app ./helm/ceres/tenant-chart \
  -n tenant-acme-corp \
  --set tenant.id=acme-corp \
  --set tenant.domain=acme-corp.ceres.local
```

### Resource Quotas

```bash
# Ограничение ресурсов на тенанта
kubectl apply -f - << EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-acme-corp-quota
  namespace: tenant-acme-corp
spec:
  hard:
    pods: "100"
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    persistentvolumeclaims: "10"
    requests.storage: "500Gi"
EOF
```

## Масштабирование

### Масштабирование сервиса

```bash
# Масштабирование Keycloak до 5 реплик
kubectl scale deployment/keycloak --replicas=5 -n ceres

# Масштабирование Nextcloud до 3 реплик
kubectl scale deployment/nextcloud --replicas=3 -n ceres

# Проверка статуса
kubectl get deployment -n ceres
```

### Автоматическое масштабирование (HPA)

```bash
# Создание HPA для Keycloak
kubectl autoscale deployment keycloak \
  --min=2 --max=10 \
  --cpu-percent=70 \
  -n ceres

# Просмотр HPA
kubectl get hpa -n ceres
```

## Мониторинг и Логи

### Просмотр логов

```bash
# Логи пода
kubectl logs -f pod/postgres-0 -n ceres

# Логи deployment
kubectl logs -f deployment/keycloak -n ceres

# Логи всех подов в namespace
kubectl logs -f --all-containers=true -n ceres
```

### Метрики

```bash
# CPU и память узлов
kubectl top nodes

# CPU и память подов
kubectl top pods -n ceres

# Детальные метрики
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes | jq .
```

### Доступ к Prometheus и Grafana

```bash
# Port forward к Prometheus
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring

# Port forward к Grafana
kubectl port-forward svc/grafana 3000:80 -n monitoring

# Доступ: http://localhost:9090, http://localhost:3000
```

## Backup и Restore

### Backup PostgreSQL StatefulSet

```bash
# Создание снимка
kubectl exec -it postgres-0 -n ceres -- \
  pg_dump -U ceres_user ceres_db > backup.sql

# Backup всех томов
kubectl exec -it postgres-0 -n ceres -- \
  tar czf /tmp/backup.tar.gz /var/lib/postgresql/data

# Копирование backup из пода
kubectl cp ceres/postgres-0:/tmp/backup.tar.gz ./backup.tar.gz
```

### Restore

```bash
# Копирование файла в под
kubectl cp ./backup.sql ceres/postgres-0:/tmp/

# Восстановление БД
kubectl exec -it postgres-0 -n ceres -- \
  psql -U ceres_user ceres_db < /tmp/backup.sql
```

## Обновление CERES

### Обновление через Helm

```bash
# Проверка доступных версий
helm search repo ceres --versions

# Обновление CERES
helm upgrade ceres ./helm/ceres \
  -n ceres \
  -f helm/ceres/values.yml \
  --wait

# Откат к предыдущей версии
helm rollback ceres 1 -n ceres
```

### Проверка status

```bash
# Статус Helm release
helm status ceres -n ceres

# История releases
helm history ceres -n ceres
```

## Troubleshooting

### Pod не запускается

```bash
# Описание пода
kubectl describe pod postgres-0 -n ceres

# Логи инициализации
kubectl logs postgres-0 -c init-postgres -n ceres

# События в namespace
kubectl get events -n ceres --sort-by='.lastTimestamp'
```

### Проблемы с хранилищем

```bash
# Список PVC
kubectl get pvc -n ceres

# Описание PVC
kubectl describe pvc postgres-storage-postgres-0 -n ceres

# Список PV
kubectl get pv

# Описание PV
kubectl describe pv postgres-pv-1
```

### Сетевые проблемы

```bash
# Тестирование DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup postgres.ceres.svc.cluster.local

# Проверка Network Policy
kubectl get networkpolicies -n ceres

# Описание Network Policy
kubectl describe networkpolicy tenant-isolation -n tenants
```

## Полезные команды

```bash
# Общая информация
kubectl get all -n ceres
kubectl get nodes -o wide
kubectl get namespaces

# Управление подами
kubectl get pods -n ceres
kubectl describe pod postgres-0 -n ceres
kubectl logs -f pod/postgres-0 -n ceres
kubectl exec -it pod/postgres-0 -n ceres -- bash

# Управление сервисами
kubectl get svc -n ceres
kubectl port-forward svc/keycloak 8080:8080 -n ceres

# Управление Ingress
kubectl get ingress -n ceres
kubectl edit ingress nextcloud -n ceres

# Масштабирование
kubectl scale deployment keycloak --replicas=5 -n ceres
kubectl set image deployment/nextcloud nextcloud=nextcloud:28 -n ceres

# Удаление ресурсов
kubectl delete pod postgres-0 -n ceres
kubectl delete deployment keycloak -n ceres
kubectl delete pvc postgres-storage-postgres-0 -n ceres

# Debug
kubectl cluster-info
kubectl api-versions
kubectl api-resources
```

## Рекомендации для Production

1. **Backup Strategy:**
   - Ежедневные резервные копии PostgreSQL
   - Snapshotting PV
   - Offsite backup хранилище

2. **Security:**
   - Network Policies для всех namespaces
   - Pod Security Standards (restricted)
   - RBAC для управления доступом
   - Secrets Encryption at rest

3. **Monitoring:**
   - AlertManager для alerts
   - Custom Prometheus rules
   - Distributed tracing с Jaeger
   - Log aggregation с Loki

4. **HA и Disaster Recovery:**
   - 3+ мастер ноды
   - Geographically distributed worker nodes
   - Regular backup testing
   - RTO/RPO определение и документирование

5. **Resource Management:**
   - CPU/Memory requests and limits
   - Pod Disruption Budgets (PDB)
   - Horizontal Pod Autoscaling (HPA)
   - Vertical Pod Autoscaling (VPA)

## Заключение

CERES v2.7.0 на Kubernetes обеспечивает:
- ✓ Full high availability
- ✓ Automatic failover
- ✓ Easy scaling
- ✓ Multi-tenancy isolation
- ✓ Complete observability
- ✓ Zero-downtime updates
- ✓ Enterprise-grade reliability

Для дополнительной информации, смотрите другие гайды:
- GITOPS_GUIDE.md - Автоматизация развертывания
- ZERO_TRUST_GUIDE.md - Безопасность в K8s
- OBSERVABILITY_GUIDE.md - Мониторинг и логи
- HA_GUIDE.md - High Availability и LB
- MULTI_TENANCY_GUIDE.md - Multi-tenancy в K8s
