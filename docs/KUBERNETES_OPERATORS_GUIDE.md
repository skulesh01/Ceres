# CERES Kubernetes Operators Guide v2.9.0

## 📋 Содержание

1. [Обзор Operators](#обзор-operators)
2. [Архитектура](#архитектура)
3. [Custom Resource Definitions (CRDs)](#custom-resource-definitions)
4. [Tenant Operator](#tenant-operator)
5. [Backup Operator](#backup-operator)
6. [Database Operator](#database-operator)
7. [Webhooks & Validation](#webhooks--validation)
8. [Установка и развертывание](#установка-и-развертывание)
9. [Примеры использования](#примеры-использования)
10. [Troubleshooting](#troubleshooting)

---

## Обзор Operators

**Kubernetes Operators** - это метод упаковки, развертывания и управления приложениями Kubernetes. Они используют пользовательские ресурсы (CRDs) для расширения API Kubernetes и обеспечения повседневного управления сложными приложениями.

### CERES Operators включают:

| Operator | Назначение | CRD |
|----------|-----------|-----|
| **Tenant Operator** | Автоматизация provisioning тенантов | `CeresTenant` |
| **Backup Operator** | Управление резервными копиями | `CeresBackup` |
| **Database Operator** | Управление PostgreSQL кластерами | `CeresDatabase` |
| **Webhook Server** | Валидация и мутация CRD | - |

---

## Архитектура

```
┌────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                      │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │            API Server & Admission Controllers        │  │
│  │  ┌─────────────────────────────────────────────┐    │  │
│  │  │         Webhook Server                      │    │  │
│  │  │  - Validation (Tenant, Database, Backup)   │    │  │
│  │  │  - Mutation (Defaults, Labels)              │    │  │
│  │  │  - Conversion (v1alpha1 -> v1beta1)         │    │  │
│  │  └─────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↑                                │
│                     kubeapi calls                           │
│                            ↓                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Tenant     │  │   Backup     │  │   Database   │     │
│  │  Operator    │  │  Operator    │  │  Operator    │     │
│  │              │  │              │  │              │     │
│  │ - Watch CRD  │  │ - Watch CRD  │  │ - Watch CRD  │     │
│  │ - Reconcile  │  │ - Reconcile  │  │ - Reconcile  │     │
│  │ - Create NS  │  │ - Schedule   │  │ - Provision  │     │
│  │ - Keycloak   │  │ - Backup/Restore │ - HA Setup  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         ↓                  ↓                  ↓             │
│  ┌──────────┐  ┌────────────────┐  ┌──────────────┐       │
│  │ Keycloak │  │   Velero       │  │   PostgreSQL │       │
│  │  Realm   │  │  Backups (S3)  │  │  StatefulSet │       │
│  └──────────┘  └────────────────┘  └──────────────┘       │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

## Custom Resource Definitions

### CeresPlatform

Определяет конфигурацию всей платформы CERES.

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresPlatform
metadata:
  name: ceres-prod
  namespace: ceres
spec:
  version: "2.9.0"
  
  infrastructure:
    cluster: k3s
    ingress:
      class: nginx
      domain: ceres.example.com
      tlsIssuer: letsencrypt-prod
    
    storage:
      class: local-path
      size: 100Gi
    
    monitoring:
      enabled: true
      prometheus:
        retention: 30d
        replicas: 2
  
  components:
    core:
      enabled: true
      replicas: 3
      resources:
        requests:
          cpu: "500m"
          memory: "512Mi"
  
  multiTenancy:
    enabled: true
    maxTenants: 100
    isolation: row-level
  
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 30
    storage: s3
```

### CeresTenant

Определяет отдельного тенанта в системе.

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresTenant
metadata:
  name: acme-corp
  namespace: ceres
spec:
  tenantId: acme
  name: "ACME Corporation"
  displayName: "ACME Corp"
  description: "Enterprise customer"
  
  plan: professional
  namespace: tenant-acme
  
  admin:
    username: admin
    email: admin@acme.example.com
    firstName: John
    lastName: Doe
  
  configuration:
    logo: "https://acme.example.com/logo.png"
    colors:
      primary: "#FF6B35"
      secondary: "#004E89"
    features:
      analytics: true
      webhooks: true
      api-access: true
  
  quota:
    cpu: "8"
    memory: "16Gi"
    storage: "200Gi"
    pods: 100
  
  billing:
    billingEmail: billing@acme.example.com
    paymentMethod: credit-card
    active: true
  
  keycloak:
    realmName: acme
    createRealm: true
  
  database:
    separate: false
    backup: true
```

**Статус после создания:**

```yaml
status:
  phase: Active
  provisioned: "2024-01-15T10:30:00Z"
  namespace: tenant-acme
  keycloakRealm: acme
  database:
    host: postgres.ceres.svc
    port: 5432
    name: tenant_acme
  conditions:
  - type: Ready
    status: "True"
    reason: TenantProvisioned
    message: Tenant acme provisioned successfully
    lastTransitionTime: "2024-01-15T10:30:00Z"
```

### CeresBackup

Управляет резервными копиями и расписаниями.

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresBackup
metadata:
  name: daily-full-backup
  namespace: ceres
spec:
  type: full
  schedule: "0 2 * * *"  # Daily 2 AM
  
  destination:
    type: s3
    bucket: ceres-backups
    path: /daily
    credentials: backup-credentials
  
  retention:
    days: 30
    count: 20
  
  components:
  - database
  - cache
  - files
  
  encryption:
    enabled: true
    algorithm: AES-256-GCM
  
  verification:
    enabled: true
    schedule: "0 4 * * 0"  # Weekly Sunday
```

### CeresDatabase

Определяет базу данных и ее конфигурацию.

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresDatabase
metadata:
  name: postgres-primary
  namespace: ceres
spec:
  engine: postgresql
  version: "15.2"
  replicas: 3
  
  storage:
    size: 100Gi
    class: fast-ssd
  
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 30
  
  monitoring:
    enabled: true
  
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "4000m"
      memory: "8Gi"
```

---

## Tenant Operator

Автоматизирует процесс создания и управления тенантами.

### Что делает Tenant Operator:

1. **Создание Kubernetes Namespace** - выделенное пространство имен для тенанта
2. **RBAC Setup** - роли и привязки для изоляции тенанта
3. **Keycloak Realm** - создание отдельного realm для аутентификации
4. **Admin User** - создание администратора тенанта
5. **Database Schema** - инициализация схемы БД с RLS политиками

### Процесс reconciliation:

```
┌─────────────────────────────────┐
│  CeresTenant Created            │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Validate Tenant ID             │
│  - Check format                 │
│  - Ensure uniqueness            │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Create Kubernetes Namespace    │
│  - Apply labels                 │
│  - Set pod security             │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Create RBAC Resources          │
│  - ServiceAccount               │
│  - Role                         │
│  - RoleBinding                  │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Setup Keycloak Realm           │
│  - Create realm                 │
│  - Configure email              │
│  - Create admin user            │
│  - Create OAuth2 client         │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Initialize Database Schema     │
│  - Create schema                │
│  - Enable RLS                   │
│  - Create tenant user           │
└────────┬────────────────────────┘
         │
         ↓
┌─────────────────────────────────┐
│  Update Status to Active        │
│  - Mark provisioned             │
│  - Record credentials           │
│  - Set Ready condition          │
└─────────────────────────────────┘
```

---

## Backup Operator

Управляет резервным копированием и восстановлением.

### Функции:

- **Velero Integration** - использует Velero для резервного копирования
- **Schedule Management** - автоматические расписания резервного копирования
- **Encryption** - шифрование резервных копий (AES-256-GCM)
- **Verification** - проверка целостности резервных копий
- **Retention Policies** - автоматическое удаление старых резервных копий
- **Cross-Cluster Restore** - восстановление на других кластерах

### Пример использования:

```bash
# Просмотр всех резервных копий
kubectl get ceresbackups -n ceres

# Просмотр деталей резервной копии
kubectl describe ceresbackup daily-full-backup -n ceres

# Просмотр логов оператора
kubectl logs -n ceres -l app=backup-operator -f

# Восстановление из резервной копии
kubectl annotate ceresbackup daily-full-backup \
  ceres.io/restore-from=true \
  --overwrite -n ceres
```

---

## Database Operator

Управляет жизненным циклом PostgreSQL кластеров.

### Функции:

- **Автоматическое развертывание** - создание PostgreSQL StatefulSet
- **High Availability** - автоматическое резервное копирование и failover
- **Scaling** - управление репликами и ресурсами
- **Backup Management** - интеграция с Backup Operator
- **Monitoring** - экспорт метрик для Prometheus
- **Health Checks** - liveness и readiness probes

### Команды:

```bash
# Получить список баз данных
kubectl get ceresdatabases -n ceres

# Просмотреть подробную информацию
kubectl describe ceresdatabase postgres-primary -n ceres

# Масштабирование
kubectl patch ceresdatabase postgres-primary \
  -p '{"spec":{"replicas":5}}' \
  --type merge -n ceres

# Проверить статус
kubectl get ceresdatabase postgres-primary -n ceres \
  -o jsonpath='{.status.phase}'
```

---

## Webhooks & Validation

### Validation Webhooks

Валидируют CRD перед созданием/обновлением.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: ceres-validators
webhooks:
- name: validate.cerestenant.ceres.io
  clientConfig:
    service:
      name: webhook
      namespace: ceres
      path: "/validate/cerestenant"
  rules:
  - operations: ["CREATE", "UPDATE"]
    apiGroups: ["ceres.io"]
    apiVersions: ["v1alpha1"]
    resources: ["cerestenants"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Fail
```

### Mutation Webhooks

Автоматически добавляют значения по умолчанию и метки.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: ceres-mutators
webhooks:
- name: mutate.cerestenant.ceres.io
  clientConfig:
    service:
      name: webhook
      namespace: ceres
      path: "/mutate/cerestenant"
  rules:
  - operations: ["CREATE"]
    apiGroups: ["ceres.io"]
    apiVersions: ["v1alpha1"]
    resources: ["cerestenants"]
  admissionReviewVersions: ["v1"]
  sideEffects: None
  failurePolicy: Ignore
```

---

## Установка и развертывание

### Предварительные требования

```bash
# Kubernetes 1.24+
kubectl version --short

# Helm 3.0+
helm version

# Python 3.9+ (для операторов)
python3 --version

# Docker (для build)
docker --version
```

### Установка

```bash
# 1. Клонировать репозиторий
git clone https://github.com/ceres-platform/ceres.git
cd ceres

# 2. Установить Operators
./scripts/deploy-operators.sh

# 3. Проверить статус
kubectl get pods -n ceres
kubectl get crd | grep ceres.io

# 4. Просмотреть логи
kubectl logs -n ceres -l app=tenant-operator -f
```

### Настройка переменных окружения

```bash
export NAMESPACE=ceres
export KEYCLOAK_URL=http://keycloak:8080
export KEYCLOAK_ADMIN_PASSWORD=admin
export DB_HOST=postgres
export DB_PORT=5432
export DB_ADMIN_PASSWORD=postgres
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
```

---

## Примеры использования

### Создание нового тенанта

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresTenant
metadata:
  name: globex-corp
  namespace: ceres
spec:
  tenantId: globex
  name: "Globex Corporation"
  displayName: "Globex"
  plan: professional
  admin:
    username: admin
    email: admin@globex.example.com
    firstName: Admin
    lastName: Globex
```

```bash
kubectl apply -f tenant-globex.yml

# Проверить статус
kubectl describe cerestenant globex-corp -n ceres

# Когда статус = "Active", тенант готов к использованию
```

### Создание резервной копии

```yaml
apiVersion: ceres.io/v1alpha1
kind: CeresBackup
metadata:
  name: weekly-backup
  namespace: ceres
spec:
  type: full
  schedule: "0 3 * * 0"  # Weekly Sunday 3 AM
  destination:
    type: s3
    bucket: ceres-backups
    path: /weekly
    credentials: backup-credentials
  retention:
    days: 90
    count: 12
  components:
  - database
  - files
  encryption:
    enabled: true
  verification:
    enabled: true
```

### Масштабирование БД

```bash
# Изменить количество реплик
kubectl patch ceresdatabase postgres-primary \
  -p '{"spec":{"replicas":5}}' \
  --type merge -n ceres

# Увеличить объем хранилища
kubectl patch ceresdatabase postgres-primary \
  -p '{"spec":{"storage":{"size":"200Gi"}}}' \
  --type merge -n ceres
```

---

## Troubleshooting

### Проблема: Operator не запускается

```bash
# Проверить логи оператора
kubectl logs -n ceres deployment/tenant-operator -f

# Проверить события
kubectl describe deployment tenant-operator -n ceres

# Проверить ресурсы
kubectl top nodes
kubectl top pods -n ceres
```

### Проблема: Тенант не создается

```bash
# Проверить события CeresTenant
kubectl describe cerestenant acme-corp -n ceres

# Проверить логи оператора
kubectl logs -n ceres -l app=tenant-operator --tail=50

# Проверить Keycloak доступность
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://keycloak:8080/health
```

### Проблема: Webhook ошибки

```bash
# Проверить webhook pod
kubectl get pods -n ceres -l app=webhook-server

# Проверить логи webhook
kubectl logs -n ceres -l app=webhook-server -f

# Проверить webhook configuration
kubectl get validatingwebhookconfigurations
kubectl describe validatingwebhookconfigurations ceres-validators
```

### Проблема: Резервная копия не создается

```bash
# Проверить Velero
kubectl get pods -n velero

# Проверить S3 доступность
kubectl run -it --rm debug --image=amazonlinux:2 --restart=Never -- \
  aws s3 ls s3://ceres-backups

# Проверить логи Backup Operator
kubectl logs -n ceres -l app=backup-operator -f
```

### Полезные команды

```bash
# Просмотреть все CRDs
kubectl api-resources | grep ceres.io

# Получить JSON schema CRD
kubectl get crd cerestenants.ceres.io -o yaml

# Просмотреть all operator resources
kubectl get all -n ceres -l managed-by=ceres-operators

# Просмотреть события в namespace
kubectl get events -n ceres --sort-by='.lastTimestamp'

# Debug pod
kubectl debug pod/tenant-operator-xxx -n ceres -it
```

---

## Best Practices

1. **Используйте отдельные Namespace** для разных окружений (dev, staging, prod)
2. **Мониторьте Operators** - добавьте ServiceMonitor для Prometheus
3. **Резервное копирование конфигурации** - сохраняйте CRDs в Git
4. **Лимиты ресурсов** - устанавливайте quotas для тенантов
5. **Аудит** - логируйте все изменения CRDs
6. **Обновления** - следите за обновлениями операторов

---

## Ссылки

- [Kubernetes Operators Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- [KOPF Framework](https://kopf.readthedocs.io/)
- [Velero Backup Solution](https://velero.io/)
- [PostgreSQL Operator Pattern](https://github.com/zalando/postgres-operator)

---

**Version:** 2.9.0  
**Last Updated:** 2024-01-15  
**Maintained by:** CERES Team
