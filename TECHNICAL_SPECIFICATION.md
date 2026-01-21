# Техническое Задание: CERES v3.0 → v3.1

**Проект**: CERES Enterprise Kubernetes Platform  
**Версия**: 3.0.0 → 3.1.0  
**Дата составления**: 21 января 2026  
**Заказчик**: Внутренний проект  
**Исполнитель**: DevOps Team

---

## 1. ВВЕДЕНИЕ

### 1.1. Цель Проекта

Устранение критических проблем платформы CERES v3.0.0 и внедрение недостающей автоматизации для обеспечения production-ready состояния.

### 1.2. Текущее Состояние

**Версия**: 3.0.0  
**Дата анализа**: 21 января 2026

#### Метрики системы:
- **Развернуто сервисов**: 38
- **Работающих подов**: 27/38 (71%)
- **Падающих подов**: 9/38 (24%)
- **Уровень автоматизации**: ~60%
- **RAM использовано**: ~12GB (из них 4-6GB на дубликаты)

#### Выявленные проблемы:
1. **КРИТИЧНО**: 4 критичных сервиса в CrashLoopBackOff
2. **КРИТИЧНО**: 5 конфликтов дублирования функционала
3. **КРИТИЧНО**: Отсутствие системы резервного копирования
4. **ВАЖНО**: Отсутствие TLS/HTTPS
5. **ВАЖНО**: Ручная настройка VPN
6. **ВАЖНО**: Отсутствие автоматической диагностики

### 1.3. Целевое Состояние

**Версия**: 3.1.0  
**Срок**: 10 рабочих дней

#### Целевые метрики:
- **Развернуто сервисов**: 27 (-11 дубликатов, +2 новых)
- **Работающих подов**: 25/25 (100%)
- **Падающих подов**: 0/25 (0%)
- **Уровень автоматизации**: 95%
- **RAM использовано**: ~8GB (-33%)

#### Ключевые улучшения:
- ✅ 100% uptime критичных сервисов
- ✅ Автоматическое резервное копирование (ежедневно)
- ✅ HTTPS для всех веб-сервисов
- ✅ One-click VPN setup
- ✅ Автоматическая диагностика и самовосстановление

---

## 2. БИЗНЕС-ТРЕБОВАНИЯ

### 2.1. Функциональные Требования

#### FR-1: Надежность Платформы
**Приоритет**: Критичный  
**Описание**: Платформа должна обеспечивать 99.9% uptime для критичных сервисов

**Критерии приемки**:
- [ ] Все критичные сервисы (PostgreSQL, Redis, Keycloak, GitLab, Ingress) работают 24/7
- [ ] Время восстановления после сбоя (MTTR) < 5 минут
- [ ] Автоматическое обнаружение и устранение типовых проблем

#### FR-2: Безопасность Данных
**Приоритет**: Критичный  
**Описание**: Все данные должны быть защищены и регулярно резервироваться

**Критерии приемки**:
- [ ] Автоматический backup всех критичных данных ежедневно
- [ ] Возможность восстановления за < 30 минут
- [ ] Шифрование данных в transit (HTTPS)
- [ ] Безопасное хранение секретов (Vault)

#### FR-3: Единая Точка Входа (SSO)
**Приоритет**: Критичный  
**Описание**: Пользователи должны аутентифицироваться один раз для доступа ко всем сервисам

**Критерии приемки**:
- [ ] Keycloak работает стабильно
- [ ] Все веб-сервисы интегрированы с Keycloak через OAuth2/OIDC
- [ ] OAuth2 Proxy настроен для защиты сервисов без встроенной аутентификации
- [ ] GitLab, Grafana, Mattermost, Wiki.js используют Keycloak напрямую
- [ ] Portainer, Adminer, MinIO защищены через OAuth2 Proxy

#### FR-4: DevOps Платформа
**Приоритет**: Критичный  
**Описание**: Полнофункциональная DevOps платформа для разработки

**Критерии приемки**:
- [ ] GitLab работает с PostgreSQL и Redis
- [ ] GitLab CI/CD pipeline функционален
- [ ] Container Registry доступен
- [ ] SonarQube интегрирован (опционально)

#### FR-5: Мониторинг и Логирование
**Приоритет**: Высокий  
**Описание**: Полная видимость состояния платформы в реальном времени

**Критерии приемки**:
- [ ] Prometheus собирает метрики со всех сервисов
- [ ] Grafana отображает дашборды
- [ ] Loki собирает логи через Promtail
- [ ] AlertManager отправляет уведомления при проблемах

#### FR-6: Автоматизация Управления
**Приоритет**: Высокий  
**Описание**: Все операции выполняются через CLI без ручных команд

**Критерии приемки**:
- [ ] CLI команда `ceres deploy` развертывает платформу полностью
- [ ] CLI команда `ceres fix` устраняет типовые проблемы
- [ ] CLI команда `ceres backup` создает резервные копии
- [ ] CLI команда `ceres vpn setup` настраивает VPN

#### FR-7: Почтовая Система
**Приоритет**: Высокий  
**Описание**: Собственный почтовый сервер для внутренних коммуникаций и уведомлений

**Критерии приемки**:
- [ ] Mailcow развернут и работает
- [ ] Домен @ceres.local настроен
- [ ] SMTP доступен для всех сервисов (GitLab, Mattermost, Keycloak, AlertManager)
- [ ] Веб-интерфейс Mailcow доступен
- [ ] Интеграция с Keycloak (SSO для почты)

#### FR-8: Интеграция Сервисов
**Приоритет**: Критичный  
**Описание**: Все сервисы интегрированы между собой для бесшовного опыта

**Критерии приемки**:
- [ ] **Keycloak SSO**: GitLab, Grafana, Mattermost, Wiki.js, Nextcloud, Mailcow
- [ ] **SMTP**: GitLab, Mattermost, Keycloak, AlertManager, Redmine используют Mailcow
- [ ] **Metrics**: Все сервисы экспортируют метрики в Prometheus
- [ ] **Logs**: Все сервисы отправляют логи в Loki через Promtail
- [ ] **Alerts**: AlertManager отправляет уведомления через Mailcow и Mattermost

### 2.2. Нефункциональные Требования

#### NFR-1: Производительность
- **Время развертывания платформы**: < 15 минут
- **Время создания backup**: < 5 минут
- **Время восстановления из backup**: < 30 минут
- **Response time веб-интерфейсов**: < 2 секунды

#### NFR-2: Масштабируемость
- **Поддержка**: до 100 одновременных пользователей
- **Хранилище**: до 500GB данных
- **Сервисы**: до 50 микросервисов

#### NFR-3: Доступность
- **Uptime**: 99.9% для критичных сервисов
- **RTO** (Recovery Time Objective): < 30 минут
- **RPO** (Recovery Point Objective): < 24 часа

#### NFR-4: Совместимость
- **Kubernetes**: K3s v1.28+, K8s v1.28+
- **OS**: Linux (Ubuntu 22.04, Debian 12, RHEL 9)
- **Архитектура**: amd64, arm64

#### NFR-5: Удобство Использования
- **CLI**: Интерактивное меню на русском языке
- **Документация**: Полная на русском + английском
- **Диагностика**: Понятные сообщения об ошибках

---

## 3. ТЕХНИЧЕСКИЕ ТРЕБОВАНИЯ

### 3.1. Архитектура Решения

#### 3.1.1. Компоненты Платформы

```
┌─────────────────────────────────────────────────────────────┐
│                    CERES Platform v3.1                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           CLI Layer (Go Application)                │   │
│  │  - Interactive Menu                                  │   │
│  │  - Deployment Orchestration                         │   │
│  │  - Health Checks & Auto-Fix                         │   │
│  │  - Backup Management                                │   │
│  │  - VPN Management                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │        Kubernetes Cluster (K3s/K8s)                 │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Core Infrastructure                         │  │   │
│  │  │  - PostgreSQL (StatefulSet)                  │  │   │
│  │  │  - Redis (Deployment)                        │  │   │
│  │  │  - Traefik Ingress (K3s default)             │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Security & Networking                       │  │   │
│  │  │  - Cert-Manager (TLS automation) [NEW]       │  │   │
│  │  │  - Keycloak (SSO)                            │  │   │
│  │  │  - Vault (Secrets)                           │  │   │
│  │  │  - OAuth2 Proxy [NEW]                        │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  DevOps Platform                             │  │   │
│  │  │  - GitLab (Git + CI/CD + Registry)           │  │   │
│  │  │  - SonarQube (Code Quality)                  │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Collaboration                               │  │   │
│  │  │  - Mattermost (Team Chat)                    │  │   │
│  │  │  - Wiki.js (Documentation)                   │  │   │
│  │  │  - Redmine (Project Management)              │  │   │
│  │  │  - MinIO (Object Storage)                    │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Monitoring & Observability                  │  │   │
│  │  │  - Prometheus (Metrics)                      │  │   │
│  │  │  - Grafana (Dashboards)                      │  │   │
│  │  │  - Loki (Log Aggregation)                    │  │   │
│  │  │  - Promtail (Log Collection) [NEW]           │  │   │
│  │  │  - Jaeger (Distributed Tracing)              │  │   │
│  │  │  - AlertManager (Alerting)                   │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Backup & Recovery                           │  │   │
│  │  │  - Velero (K8s Backup) [NEW]                 │  │   │
│  │  │  - MinIO (Backup Storage)                    │  │   │
│  │  │  - Automated Daily Backups [NEW]             │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  │                                                       │   │
│  │  ┌──────────────────────────────────────────────┐  │   │
│  │  │  Management & Utilities                      │  │   │
│  │  │  - Adminer (Database UI)                     │  │   │
│  │  │  - Portainer (K8s UI)                        │  │   │
│  │  │  - Flux CD (GitOps)                          │  │   │
│  │  └──────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           VPN Access (WireGuard)                    │   │
│  │  - Server on Proxmox (10.8.0.1)                     │   │
│  │  - Clients auto-configured (10.8.0.2+)              │   │
│  │  - Access to ClusterIP services                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### 3.1.2. Сетевая Архитектура

```
Internet
    │
    ▼
┌─────────────────────┐
│  Proxmox Host       │
│  192.168.1.3        │
└─────────────────────┘
    │
    ├─── WireGuard VPN Server (10.8.0.1:51820)
    │         │
    │         └─── VPN Clients (10.8.0.2+)
    │
    └─── K3s Cluster
            │
            ├─── Pod Network (10.42.0.0/16)
            │
            └─── Service Network (10.43.0.0/16)
                    │
                    ├─── ClusterIP Services (internal)
                    ├─── NodePort Services (30000-32767)
                    └─── LoadBalancer (via Traefik)
```

### 3.2. Технологический Стек

#### 3.2.1. Основные Технологии

| Компонент | Технология | Версия | Назначение |
|-----------|------------|--------|------------|
| **Container Orchestration** | K3s | v1.28+ | Lightweight Kubernetes |
| **CLI Application** | Go | 1.21+ | Automation tool |
| **Infrastructure as Code** | Terraform | 1.6+ | Cloud provisioning |
| **GitOps** | Flux CD | 2.2+ | Continuous deployment |
| **Package Manager** | kubectl manifests | - | Service deployment |

#### 3.2.2. Core Services

| Service | Image | Version | Storage |
|---------|-------|---------|---------|
| PostgreSQL | postgres | 16 | 10Gi PVC |
| Redis | redis | 7.0 | 5Gi PVC |
| Keycloak | quay.io/keycloak/keycloak | 23.0 | - |
| GitLab | gitlab/gitlab-ce | latest | 20Gi PVC |

#### 3.2.3. Новые Компоненты (v3.1)

| Service | Image | Version | Назначение |
|---------|-------|---------|------------|
| **Cert-Manager** | quay.io/jetstack/cert-manager-controller | v1.13.0 | TLS automation |
| **Velero** | velero/velero | v1.12.0 | Backup/Restore |
| **Promtail** | grafana/promtail | 2.9.0 | Log collection |
| **OAuth2 Proxy** | quay.io/oauth2-proxy/oauth2-proxy | v7.5.0 | SSO gateway |
| **Mailcow** | mailcow/mailcow-dockerized | latest | Email server |
| **Postfix** | mailcow/postfix | latest | SMTP relay |

### 3.3. Требования к Инфраструктуре

#### 3.3.1. Минимальные Требования

**Single-node K3s**:
- **CPU**: 4 cores
- **RAM**: 8 GB
- **Storage**: 100 GB SSD
- **Network**: 100 Mbps

**Рекомендуемые**:
- **CPU**: 8 cores
- **RAM**: 16 GB
- **Storage**: 200 GB NVMe SSD
- **Network**: 1 Gbps

#### 3.3.2. Production Требования

**Multi-node K3s (3 nodes)**:
- **Master Node**: 4 CPU, 8GB RAM, 100GB SSD
- **Worker Nodes (x2)**: 8 CPU, 16GB RAM, 200GB SSD
- **Total**: 20 CPU, 40GB RAM, 500GB Storage

---

## 4. ДЕТАЛЬНЫЕ ЗАДАЧИ

### 4.1. ФАЗА 1: СТАБИЛИЗАЦИЯ (День 1-2)

#### Задача 1.1: Удаление Дублирующих Сервисов
**Приоритет**: Критичный  
**Трудоемкость**: 1 час  
**Исполнитель**: DevOps Engineer

**Описание**: Удалить 5 дублирующих сервисов для освобождения ресурсов и упрощения архитектуры.

**Технические детали**:
```bash
# Удалить namespaces с дубликатами
kubectl delete namespace elasticsearch
kubectl delete namespace kibana
kubectl delete namespace harbor
kubectl delete namespace jenkins
kubectl delete namespace uptime-kuma
```

**Обоснование удаления**:
- **Elasticsearch + Kibana**: Дублируют Loki + Grafana (функция: логирование)
- **Harbor**: Дублирует GitLab Container Registry
- **Jenkins**: Дублирует GitLab CI/CD
- **Uptime Kuma**: Дублирует Prometheus + AlertManager

**Автоматизация**:
```go
// pkg/deployment/cleanup.go
func (d *Deployer) RemoveDuplicates() error {
    duplicates := []string{
        "elasticsearch", "kibana", "harbor", 
        "jenkins", "uptime-kuma",
    }
    
    for _, ns := range duplicates {
        cmd := exec.Command("kubectl", "delete", "namespace", ns)
        if err := cmd.Run(); err != nil {
            fmt.Printf("Warning: Failed to delete %s: %v\n", ns, err)
        } else {
            fmt.Printf("✅ Deleted duplicate namespace: %s\n", ns)
        }
    }
    return nil
}
```

**Интеграция в CLI**:
```go
// cmd/ceres/main.go
cmd.AddCommand(&cobra.Command{
    Use:   "cleanup",
    Short: "Удалить избыточные сервисы",
    RunE: func(cmd *cobra.Command, args []string) error {
        deployer, _ := deployment.NewDeployer("proxmox", "prod", "ceres")
        return deployer.RemoveDuplicates()
    },
})
```

**Критерии приемки**:
- [ ] Все 5 namespaces удалены
- [ ] RAM usage снижен на ~4GB
- [ ] Команда `ceres cleanup` работает
- [ ] Документация обновлена

**Риски**:
- Возможна потеря данных из Elasticsearch (минимизация: предупреждение пользователя)

---

#### Задача 1.2: Исправление Ingress NGINX
**Приоритет**: Критичный  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Починить Ingress NGINX Controller для восстановления доступа к сервисам.

**Диагностика**:
```bash
kubectl logs -n ingress-nginx ingress-nginx-controller-xxx --tail=50
kubectl describe pod -n ingress-nginx ingress-nginx-controller-xxx
```

**Типовые проблемы**:
1. **Port conflict** с Traefik (K3s default)
2. **RBAC permissions** недостаточны
3. **Resource limits** слишком низкие

**Решение**:
```yaml
# deployment/ingress-nginx-fixed.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: controller
      app.kubernetes.io/name: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/component: controller
        app.kubernetes.io/name: ingress-nginx
    spec:
      serviceAccountName: ingress-nginx
      containers:
      - name: controller
        image: registry.k8s.io/ingress-nginx/controller:v1.9.0
        args:
        - /nginx-ingress-controller
        - --election-id=ingress-controller-leader
        - --controller-class=k8s.io/ingress-nginx
        - --configmap=$(POD_NAMESPACE)/ingress-nginx-controller
        - --http-port=8080      # Не конфликтует с Traefik:80
        - --https-port=8443     # Не конфликтует с Traefik:443
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: https
        resources:
          requests:
            cpu: 100m
            memory: 90Mi
          limits:
            cpu: 500m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
spec:
  type: NodePort
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: ingress-nginx
  ports:
  - name: http
    port: 80
    targetPort: 8080
    nodePort: 30080
  - name: https
    port: 443
    targetPort: 8443
    nodePort: 30443
```

**Автоматизация**:
```go
// pkg/deployment/deployer.go
func (d *Deployer) FixIngressNginx() error {
    // 1. Delete existing broken deployment
    exec.Command("kubectl", "delete", "deployment", 
        "ingress-nginx-controller", "-n", "ingress-nginx").Run()
    
    // 2. Apply fixed manifest
    d.applyManifest("deployment/ingress-nginx-fixed.yaml")
    
    // 3. Wait for readiness
    return d.waitForPods("ingress-nginx", 
        "app.kubernetes.io/component=controller", 120)
}
```

**Критерии приемки**:
- [ ] Pod в статусе Running
- [ ] NodePort 30080/30443 доступны
- [ ] HTTP запрос на http://192.168.1.3:30080 возвращает 404 (nginx работает)
- [ ] Ingress routes обрабатываются

---

#### Задача 1.3: Исправление Keycloak
**Приоритет**: Критичный  
**Трудоемкость**: 3 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Починить Keycloak для восстановления SSO функционала.

**Диагностика**:
```bash
kubectl logs -n ceres keycloak-xxx --tail=100
```

**Типовые проблемы**:
1. **Database connection failed**: Неверная строка подключения к PostgreSQL
2. **Schema not initialized**: База данных не создана
3. **Insufficient memory**: OOMKilled

**Решение**:
```yaml
# deployment/keycloak-fixed.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: ceres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      initContainers:
      # Проверка доступности PostgreSQL
      - name: wait-for-postgres
        image: postgres:16
        command:
        - sh
        - -c
        - |
          until pg_isready -h postgresql.ceres-core.svc.cluster.local -p 5432 -U postgres; do
            echo "Waiting for PostgreSQL..."
            sleep 2
          done
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0
        args:
        - start
        - --auto-build
        - --db=postgres
        - --features=token-exchange
        - --http-enabled=true
        - --http-port=8080
        - --hostname-strict=false
        - --proxy=edge
        env:
        - name: KEYCLOAK_ADMIN
          value: admin
        - name: KEYCLOAK_ADMIN_PASSWORD
          value: K3yClo@k!2025
        - name: KC_DB
          value: postgres
        - name: KC_DB_URL
          value: jdbc:postgresql://postgresql.ceres-core.svc.cluster.local:5432/keycloak
        - name: KC_DB_USERNAME
          value: postgres
        - name: KC_DB_PASSWORD
          value: ceres_postgres_2025
        - name: KC_HEALTH_ENABLED
          value: "true"
        - name: JAVA_OPTS
          value: "-Xms512m -Xmx1024m"
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 1000m
            memory: 2Gi
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 120
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 5
```

**Предварительная проверка БД**:
```bash
# Убедиться что база keycloak существует
kubectl exec -n ceres-core postgresql-0 -- psql -U postgres -c "\l" | grep keycloak
```

**Автоматизация**:
```go
// pkg/deployment/deployer.go
func (d *Deployer) FixKeycloak() error {
    // 1. Ensure database exists
    d.ensureDatabase("keycloak")
    
    // 2. Delete failed pod
    exec.Command("kubectl", "delete", "pod", "-n", "ceres", 
        "-l", "app=keycloak").Run()
    
    // 3. Apply fixed manifest
    d.applyManifest("deployment/keycloak-fixed.yaml")
    
    // 4. Wait for readiness (longer timeout)
    return d.waitForPods("ceres", "app=keycloak", 300)
}

func (d *Deployer) ensureDatabase(dbName string) error {
    cmd := exec.Command("kubectl", "exec", "-n", "ceres-core", 
        "postgresql-0", "--", "psql", "-U", "postgres", 
        "-c", fmt.Sprintf("CREATE DATABASE %s;", dbName))
    cmd.Run() // Ignore error if exists
    return nil
}
```

**Критерии приемки**:
- [ ] Pod в статусе Running
- [ ] Health endpoints (/health/live, /health/ready) отвечают 200
- [ ] Admin console доступен (http://keycloak-ip:8080)
- [ ] Вход с admin / K3yClo@k!2025 работает

---

#### Задача 1.4: Исправление GitLab
**Приоритет**: Критичный  
**Трудоемкость**: 4 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Починить GitLab для восстановления DevOps платформы.

**Диагностика**:
```bash
kubectl logs -n gitlab gitlab-xxx --tail=200
```

**Типовые проблемы**:
1. **Redis connection timeout**: Неверный host/password
2. **PostgreSQL initialization failed**: База не создана или схема устарела
3. **OOMKilled**: Недостаточно памяти (GitLab требует 4GB+)

**Решение**:
```yaml
# deployment/gitlab-fixed.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gitlab
  namespace: gitlab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gitlab
  template:
    metadata:
      labels:
        app: gitlab
    spec:
      initContainers:
      # Wait for PostgreSQL
      - name: wait-postgres
        image: postgres:16
        command: ['sh', '-c', 
          'until pg_isready -h postgresql.ceres-core.svc.cluster.local -U postgres; do sleep 2; done']
      # Wait for Redis
      - name: wait-redis
        image: redis:7.0
        command: ['sh', '-c',
          'until redis-cli -h redis.ceres-core.svc.cluster.local -a ceres_redis_2025 ping; do sleep 2; done']
      containers:
      - name: gitlab
        image: gitlab/gitlab-ce:16.7.0-ce.0
        ports:
        - containerPort: 80
          name: http
        - containerPort: 22
          name: ssh
        env:
        - name: GITLAB_OMNIBUS_CONFIG
          value: |
            external_url 'http://gitlab.ceres.local'
            gitlab_rails['initial_root_password'] = 'GitLab@Root2025'
            
            # PostgreSQL
            postgresql['enable'] = false
            gitlab_rails['db_adapter'] = 'postgresql'
            gitlab_rails['db_encoding'] = 'utf8'
            gitlab_rails['db_host'] = 'postgresql.ceres-core.svc.cluster.local'
            gitlab_rails['db_port'] = 5432
            gitlab_rails['db_database'] = 'gitlab'
            gitlab_rails['db_username'] = 'postgres'
            gitlab_rails['db_password'] = 'ceres_postgres_2025'
            
            # Redis
            redis['enable'] = false
            gitlab_rails['redis_host'] = 'redis.ceres-core.svc.cluster.local'
            gitlab_rails['redis_port'] = 6379
            gitlab_rails['redis_password'] = 'ceres_redis_2025'
            
            # Performance tuning
            puma['worker_processes'] = 2
            sidekiq['max_concurrency'] = 10
            prometheus_monitoring['enable'] = false
            
            # Disable unused features
            gitlab_rails['gitlab_email_enabled'] = false
            gitlab_rails['gitlab_default_can_create_group'] = true
            
        resources:
          requests:
            cpu: 1000m
            memory: 4Gi
          limits:
            cpu: 2000m
            memory: 8Gi
        volumeMounts:
        - name: gitlab-data
          mountPath: /var/opt/gitlab
        - name: gitlab-config
          mountPath: /etc/gitlab
        - name: gitlab-logs
          mountPath: /var/log/gitlab
        livenessProbe:
          httpGet:
            path: /-/liveness
            port: 80
          initialDelaySeconds: 300
          periodSeconds: 30
          timeoutSeconds: 10
        readinessProbe:
          httpGet:
            path: /-/readiness
            port: 80
          initialDelaySeconds: 180
          periodSeconds: 10
      volumes:
      - name: gitlab-data
        persistentVolumeClaim:
          claimName: gitlab-data
      - name: gitlab-config
        emptyDir: {}
      - name: gitlab-logs
        emptyDir: {}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gitlab-data
  namespace: gitlab
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

**Автоматизация**:
```go
func (d *Deployer) FixGitLab() error {
    // 1. Ensure database exists
    d.ensureDatabase("gitlab")
    
    // 2. Delete failed pod (force)
    exec.Command("kubectl", "delete", "pod", "-n", "gitlab",
        "-l", "app=gitlab", "--force", "--grace-period=0").Run()
    
    // 3. Apply fixed manifest with PVC
    d.applyManifest("deployment/gitlab-fixed.yaml")
    
    // 4. Wait for readiness (very long timeout for GitLab)
    fmt.Println("⏳ GitLab startup takes 5-10 minutes...")
    return d.waitForPods("gitlab", "app=gitlab", 600)
}
```

**Критерии приемки**:
- [ ] Pod в статусе Running
- [ ] HTTP endpoint доступен
- [ ] Вход с root / GitLab@Root2025 работает
- [ ] Можно создать новый проект
- [ ] Container Registry работает

**Риски**:
- GitLab требует 4-8GB RAM (может не работать на малых серверах)

---

#### Задача 1.5: Исправление Nextcloud (опционально)
**Приоритет**: Средний  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Починить Nextcloud для восстановления файлообменника.

**Альтернатива**: Использовать MinIO (уже работает) + WebUI

**Решение**: См. аналогичный подход как с Keycloak (initContainer + правильные env vars)

**Критерии приемки**:
- [ ] Pod в статусе Running
- [ ] Web UI доступен
- [ ] Можно загружать/скачивать файлы

---

### 4.2. ФАЗА 2: TLS/HTTPS АВТОМАТИЗАЦИЯ (День 3)

#### Задача 2.1: Установка Cert-Manager
**Приоритет**: Высокий  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Установить Cert-Manager для автоматического управления TLS сертификатами.

**Технические детали**:
```yaml
# deployment/cert-manager.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: cert-manager
  namespace: kube-system
spec:
  repo: https://charts.jetstack.io
  chart: cert-manager
  version: v1.13.3
  targetNamespace: cert-manager
  set:
    installCRDs: "true"
    global.leaderElection.namespace: "cert-manager"
```

**Создание ClusterIssuer**:
```yaml
# deployment/cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# Опционально: Let's Encrypt для production
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@ceres.local
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Автоматизация**:
```go
// pkg/deployment/tls.go
package deployment

func (d *Deployer) SetupTLS() error {
    fmt.Println("📦 Installing Cert-Manager...")
    
    // 1. Apply cert-manager Helm chart
    if err := d.applyManifest("deployment/cert-manager.yaml"); err != nil {
        return err
    }
    
    // 2. Wait for cert-manager pods
    d.waitForPods("cert-manager", "app.kubernetes.io/name=cert-manager", 120)
    
    // 3. Create ClusterIssuers
    fmt.Println("📦 Creating ClusterIssuers...")
    if err := d.applyManifest("deployment/cluster-issuer.yaml"); err != nil {
        return err
    }
    
    // 4. Update ingress routes with TLS
    fmt.Println("📦 Enabling TLS for Ingress routes...")
    if err := d.applyManifest("deployment/ingress-routes-tls.yaml"); err != nil {
        return err
    }
    
    fmt.Println("✅ TLS automation enabled")
    return nil
}
```

**Критерии приемки**:
- [ ] Cert-manager pods Running
- [ ] ClusterIssuer создан (kubectl get clusterissuer)
- [ ] Test certificate выпущен успешно

---

#### Задача 2.2: Обновление Ingress Routes с TLS
**Приоритет**: Высокий  
**Трудоемкость**: 1 час  
**Исполнитель**: DevOps Engineer

**Описание**: Обновить все Ingress маршруты для использования HTTPS.

**Пример**:
```yaml
# deployment/ingress-routes-tls.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - grafana.ceres.local
    secretName: grafana-tls
  rules:
  - host: grafana.ceres.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitlab-ingress
  namespace: gitlab
  annotations:
    cert-manager.io/cluster-issuer: selfsigned-issuer
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - gitlab.ceres.local
    secretName: gitlab-tls
  rules:
  - host: gitlab.ceres.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitlab
            port:
              number: 80
```

**Критерии приемки**:
- [ ] Все веб-сервисы доступны через HTTPS
- [ ] Сертификаты автоматически выпускаются
- [ ] HTTP редиректится на HTTPS

---

### 4.3. ФАЗА 3: BACKUP & RECOVERY (День 4)

#### Задача 3.1: Установка Velero
**Приоритет**: Критичный  
**Трудоемкость**: 3 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Установить Velero для резервного копирования кластера.

**Технические детали**:
```yaml
# deployment/velero.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: velero
---
# MinIO bucket для бэкапов
apiVersion: batch/v1
kind: Job
metadata:
  name: create-backup-bucket
  namespace: minio
spec:
  template:
    spec:
      containers:
      - name: mc
        image: minio/mc:latest
        command:
        - sh
        - -c
        - |
          mc alias set myminio http://minio.minio.svc:9000 minioadmin MinIO@Admin2025
          mc mb myminio/ceres-backups || true
          mc policy set download myminio/ceres-backups
      restartPolicy: OnFailure
---
apiVersion: v1
kind: Secret
metadata:
  name: velero-credentials
  namespace: velero
stringData:
  cloud: |
    [default]
    aws_access_key_id = minioadmin
    aws_secret_access_key = MinIO@Admin2025
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: velero
  namespace: kube-system
spec:
  repo: https://vmware-tanzu.github.io/helm-charts
  chart: velero
  version: 5.1.0
  targetNamespace: velero
  valuesContent: |-
    configuration:
      provider: aws
      backupStorageLocation:
        bucket: ceres-backups
        config:
          region: minio
          s3ForcePathStyle: true
          s3Url: http://minio.minio.svc:9000
      volumeSnapshotLocation:
        config:
          region: minio
    credentials:
      existingSecret: velero-credentials
    initContainers:
    - name: velero-plugin-for-aws
      image: velero/velero-plugin-for-aws:v1.8.0
      volumeMounts:
      - mountPath: /target
        name: plugins
    schedules:
      daily:
        disabled: false
        schedule: "0 2 * * *"
        template:
          ttl: "720h"
          includedNamespaces:
          - ceres
          - ceres-core
          - monitoring
          - gitlab
          - mattermost
          - wiki
          - redmine
```

**Автоматизация**:
```go
// pkg/backup/backup.go
package backup

import (
    "fmt"
    "os/exec"
    "time"
)

type BackupManager struct {
    deployer *deployment.Deployer
}

func NewBackupManager(deployer *deployment.Deployer) *BackupManager {
    return &BackupManager{deployer: deployer}
}

func (b *BackupManager) Setup() error {
    fmt.Println("📦 Installing Velero...")
    
    // 1. Create MinIO bucket
    b.deployer.ApplyManifest("deployment/velero.yaml")
    
    // 2. Wait for job completion
    time.Sleep(30 * time.Second)
    
    // 3. Wait for Velero pod
    b.deployer.WaitForPods("velero", "app.kubernetes.io/name=velero", 120)
    
    fmt.Println("✅ Velero installed with daily backups")
    return nil
}

func (b *BackupManager) CreateBackup(name string) error {
    if name == "" {
        name = fmt.Sprintf("manual-%s", time.Now().Format("20060102-150405"))
    }
    
    fmt.Printf("📦 Creating backup: %s\n", name)
    
    cmd := exec.Command("kubectl", "exec", "-n", "velero",
        "deploy/velero", "--", "velero", "backup", "create", name,
        "--include-namespaces", "ceres,ceres-core,monitoring,gitlab",
        "--wait")
    
    output, err := cmd.CombinedOutput()
    if err != nil {
        return fmt.Errorf("backup failed: %v\n%s", err, output)
    }
    
    fmt.Println("✅ Backup created successfully")
    return nil
}

func (b *BackupManager) ListBackups() (string, error) {
    cmd := exec.Command("kubectl", "exec", "-n", "velero",
        "deploy/velero", "--", "velero", "backup", "get")
    output, err := cmd.Output()
    return string(output), err
}

func (b *BackupManager) Restore(backupName string) error {
    fmt.Printf("🔄 Restoring from backup: %s\n", backupName)
    
    cmd := exec.Command("kubectl", "exec", "-n", "velero",
        "deploy/velero", "--", "velero", "restore", "create",
        "--from-backup", backupName, "--wait")
    
    output, err := cmd.CombinedOutput()
    if err != nil {
        return fmt.Errorf("restore failed: %v\n%s", err, output)
    }
    
    fmt.Println("✅ Restore completed")
    return nil
}

func (b *BackupManager) ScheduleStatus() (string, error) {
    cmd := exec.Command("kubectl", "exec", "-n", "velero",
        "deploy/velero", "--", "velero", "schedule", "get")
    output, err := cmd.Output()
    return string(output), err
}
```

**Интеграция в CLI**:
```go
// cmd/ceres/main.go
func backupInteractive() error {
    fmt.Println("\n💾 РЕЗЕРВНОЕ КОПИРОВАНИЕ")
    fmt.Println("  1. Создать backup сейчас")
    fmt.Println("  2. Список backups")
    fmt.Println("  3. Восстановить из backup")
    fmt.Println("  4. Статус автобэкапов")
    fmt.Println("  0. Назад")
    
    var choice int
    fmt.Scanln(&choice)
    
    deployer, _ := deployment.NewDeployer("proxmox", "prod", "ceres")
    backupMgr := backup.NewBackupManager(deployer)
    
    switch choice {
    case 1:
        return backupMgr.CreateBackup("")
    case 2:
        list, err := backupMgr.ListBackups()
        fmt.Println(list)
        return err
    case 3:
        fmt.Print("Имя backup: ")
        var name string
        fmt.Scanln(&name)
        return backupMgr.Restore(name)
    case 4:
        status, err := backupMgr.ScheduleStatus()
        fmt.Println(status)
        return err
    }
    return nil
}
```

**Критерии приемки**:
- [ ] Velero pod Running
- [ ] MinIO bucket создан
- [ ] Ежедневный backup schedule работает
- [ ] Ручной backup создается за < 5 минут
- [ ] Restore работает корректно

---

### 4.4. ФАЗА 4: LOGGING PIPELINE (День 5)

#### Задача 4.1: Установка Promtail
**Приоритет**: Высокий  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Развернуть Promtail для автоматического сбора логов подов.

**Технические детали**:
```yaml
# deployment/promtail.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: promtail
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: promtail
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: promtail
subjects:
- kind: ServiceAccount
  name: promtail
  namespace: monitoring
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    
    positions:
      filename: /tmp/positions.yaml
    
    clients:
      - url: http://loki.monitoring.svc:3100/loki/api/v1/push
    
    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_node_name]
            target_label: node_name
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
          - source_labels: [__meta_kubernetes_pod_label_app]
            target_label: app
          - replacement: /var/log/pods/*$1/*.log
            separator: /
            source_labels:
            - __meta_kubernetes_pod_uid
            - __meta_kubernetes_pod_container_name
            target_label: __path__
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
      - name: promtail
        image: grafana/promtail:2.9.3
        args:
        - -config.file=/etc/promtail/promtail.yaml
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: run
          mountPath: /run/promtail
        - name: pods
          mountPath: /var/log/pods
          readOnly: true
        ports:
        - containerPort: 9080
          name: http-metrics
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: run
        hostPath:
          path: /run/promtail
      - name: pods
        hostPath:
          path: /var/log/pods
```

**Автоматизация**:
```go
// pkg/deployment/logging.go
func (d *Deployer) SetupLogging() error {
    fmt.Println("📦 Installing Promtail...")
    
    // 1. Apply Promtail DaemonSet
    if err := d.applyManifest("deployment/promtail.yaml"); err != nil {
        return err
    }
    
    // 2. Wait for DaemonSet
    d.waitForPods("monitoring", "app=promtail", 60)
    
    fmt.Println("✅ Log collection enabled")
    fmt.Println("📊 View logs in Grafana → Explore → Loki")
    return nil
}
```

**Критерии приемки**:
- [ ] Promtail DaemonSet pods Running на всех узлах
- [ ] Логи появляются в Loki
- [ ] В Grafana можно просмотреть логи через Explore

---

### 4.5. ФАЗА 5: VPN AUTOMATION (День 6)

#### Задача 5.1: Автоматизация WireGuard Setup
**Приоритет**: Высокий  
**Трудоемкость**: 3 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Реализовать полностью автоматический setup VPN.

**Технические детали**: См. QUICK_ANALYSIS.md, раздел Priority 4

**Критерии приемки**:
- [ ] Команда `ceres vpn setup` генерирует ключи
- [ ] Автоматически добавляет клиента на сервер
- [ ] Создает файл ceres-vpn-client.conf
- [ ] Инструкции для импорта выводятся

---

### 4.6. ФАЗА 6: MAILCOW & SMTP (День 7)

#### Задача 6.1: Установка Mailcow
**Приоритет**: Высокий  
**Трудоемкость**: 4 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Развернуть собственный почтовый сервер для внутренних коммуникаций.

**Технические детали**:
```yaml
# deployment/mailcow.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mailcow
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mailcow-data
  namespace: mailcow
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mailcow
  namespace: mailcow
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mailcow
  template:
    metadata:
      labels:
        app: mailcow
    spec:
      containers:
      # Postfix (SMTP)
      - name: postfix
        image: mailcow/postfix:1.70
        ports:
        - containerPort: 25
          name: smtp
        - containerPort: 587
          name: submission
        env:
        - name: MAILCOW_HOSTNAME
          value: mail.ceres.local
        - name: MAILCOW_DOMAIN
          value: ceres.local
        volumeMounts:
        - name: mailcow-data
          mountPath: /var/vmail
          subPath: vmail
      # Dovecot (IMAP)
      - name: dovecot
        image: mailcow/dovecot:1.70
        ports:
        - containerPort: 143
          name: imap
        - containerPort: 993
          name: imaps
        volumeMounts:
        - name: mailcow-data
          mountPath: /var/vmail
          subPath: vmail
      # SOGo (Webmail)
      - name: sogo
        image: mailcow/sogo:1.70
        ports:
        - containerPort: 20000
          name: http
        env:
        - name: SOGO_OIDC_ENABLED
          value: "true"
        - name: SOGO_OIDC_ISSUER
          value: http://keycloak.ceres.svc.cluster.local:8080/realms/ceres
        - name: SOGO_OIDC_CLIENT_ID
          value: mailcow
        - name: SOGO_OIDC_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: mailcow-oidc
              key: client-secret
      volumes:
      - name: mailcow-data
        persistentVolumeClaim:
          claimName: mailcow-data
---
apiVersion: v1
kind: Service
metadata:
  name: mailcow-smtp
  namespace: mailcow
spec:
  selector:
    app: mailcow
  ports:
  - name: smtp
    port: 25
    targetPort: 25
  - name: submission
    port: 587
    targetPort: 587
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: mailcow-webmail
  namespace: mailcow
spec:
  selector:
    app: mailcow
  ports:
  - port: 80
    targetPort: 20000
  type: ClusterIP
```

**Автоматизация**:
```go
// pkg/deployment/mail.go
package deployment

import (
    "fmt"
    "os/exec"
)

type MailManager struct {
    deployer *Deployer
}

func NewMailManager(deployer *Deployer) *MailManager {
    return &MailManager{deployer: deployer}
}

func (m *MailManager) Setup() error {
    fmt.Println("📧 Installing Mailcow...")
    
    // 1. Deploy Mailcow
    if err := m.deployer.ApplyManifest("deployment/mailcow.yaml"); err != nil {
        return err
    }
    
    // 2. Wait for readiness
    m.deployer.WaitForPods("mailcow", "app=mailcow", 180)
    
    // 3. Create Keycloak client for Mailcow
    if err := m.createKeycloakClient(); err != nil {
        return err
    }
    
    // 4. Configure SMTP for services
    if err := m.configureSMTPIntegration(); err != nil {
        return err
    }
    
    fmt.Println("✅ Mailcow installed")
    fmt.Println("📧 SMTP: mailcow-smtp.mailcow.svc:587")
    fmt.Println("🌐 Webmail: http://mail.ceres.local")
    return nil
}

func (m *MailManager) createKeycloakClient() error {
    // TODO: Use Keycloak API to create OIDC client
    fmt.Println("  📝 Creating Keycloak client for Mailcow...")
    return nil
}

func (m *MailManager) configureSMTPIntegration() error {
    services := []struct{
        name      string
        namespace string
        configMap string
    }{
        {"gitlab", "gitlab", "gitlab-smtp"},
        {"mattermost", "mattermost", "mattermost-smtp"},
        {"keycloak", "ceres", "keycloak-smtp"},
    }
    
    for _, svc := range services {
        fmt.Printf("  📧 Configuring SMTP for %s...\n", svc.name)
        // Apply SMTP ConfigMap
        m.deployer.ApplyManifest(fmt.Sprintf(
            "deployment/smtp-configs/%s.yaml", svc.name))
    }
    
    return nil
}
```

**Критерии приемки**:
- [ ] Mailcow pods Running
- [ ] SMTP порт 587 доступен внутри кластера
- [ ] Webmail доступен через Ingress
- [ ] Тестовое письмо отправлено

---

#### Задача 6.2: Интеграция Keycloak с Сервисами
**Приоритет**: Критичный  
**Трудоемкость**: 6 часов  
**Исполнитель**: DevOps Engineer

**Описание**: Настроить SSO через Keycloak для всех веб-сервисов.

**Сервисы для интеграции**:
1. **GitLab** - OIDC (встроенная поддержка)
2. **Grafana** - OAuth2 (встроенная поддержка)
3. **Mattermost** - SAML/OIDC (встроенная поддержка)
4. **Wiki.js** - OIDC (встроенная поддержка)
5. **Nextcloud** - OIDC (через app)
6. **Mailcow** - OIDC (SOGo)
7. **Portainer** - OAuth2 Proxy (обертка)
8. **Adminer** - OAuth2 Proxy (обертка)
9. **MinIO** - OAuth2 Proxy (обертка)
10. **Prometheus** - OAuth2 Proxy (обертка)

**Техническая реализация**:

**1. GitLab OIDC**:
```yaml
# deployment/gitlab-keycloak.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gitlab-oidc
  namespace: gitlab
data:
  gitlab.rb: |
    gitlab_rails['omniauth_enabled'] = true
    gitlab_rails['omniauth_allow_single_sign_on'] = ['openid_connect']
    gitlab_rails['omniauth_block_auto_created_users'] = false
    gitlab_rails['omniauth_auto_link_user'] = ['openid_connect']
    
    gitlab_rails['omniauth_providers'] = [
      {
        name: 'openid_connect',
        label: 'Keycloak',
        args: {
          name: 'openid_connect',
          scope: ['openid', 'profile', 'email'],
          response_type: 'code',
          issuer: 'http://keycloak.ceres.svc.cluster.local:8080/realms/ceres',
          client_auth_method: 'query',
          discovery: true,
          uid_field: 'preferred_username',
          client_options: {
            identifier: 'gitlab',
            secret: ENV['GITLAB_OIDC_SECRET'],
            redirect_uri: 'http://gitlab.ceres.local/users/auth/openid_connect/callback'
          }
        }
      }
    ]
```

**2. Grafana OAuth2**:
```yaml
# deployment/grafana-keycloak.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-oauth
  namespace: monitoring
data:
  grafana.ini: |
    [auth.generic_oauth]
    enabled = true
    name = Keycloak
    allow_sign_up = true
    client_id = grafana
    client_secret = ${GRAFANA_OIDC_SECRET}
    scopes = openid email profile
    auth_url = http://keycloak.ceres.svc.cluster.local:8080/realms/ceres/protocol/openid-connect/auth
    token_url = http://keycloak.ceres.svc.cluster.local:8080/realms/ceres/protocol/openid-connect/token
    api_url = http://keycloak.ceres.svc.cluster.local:8080/realms/ceres/protocol/openid-connect/userinfo
    role_attribute_path = contains(roles[*], 'admin') && 'Admin' || 'Viewer'
```

**3. OAuth2 Proxy (для сервисов без встроенного SSO)**:
```yaml
# deployment/oauth2-proxy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: ceres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
        args:
        - --provider=oidc
        - --provider-display-name=Keycloak
        - --client-id=oauth2-proxy
        - --client-secret=$(OAUTH2_CLIENT_SECRET)
        - --oidc-issuer-url=http://keycloak.ceres.svc.cluster.local:8080/realms/ceres
        - --redirect-url=https://oauth.ceres.local/oauth2/callback
        - --cookie-secret=$(COOKIE_SECRET)
        - --email-domain=*
        - --upstream=static://202
        - --http-address=0.0.0.0:4180
        - --reverse-proxy=true
        env:
        - name: OAUTH2_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: client-secret
        - name: COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: cookie-secret
        ports:
        - containerPort: 4180
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: ceres
spec:
  selector:
    app: oauth2-proxy
  ports:
  - port: 4180
    targetPort: 4180
```

**Автоматизация**:
```go
// pkg/deployment/sso.go
package deployment

import "fmt"

type SSOManager struct {
    deployer *Deployer
}

func NewSSOManager(deployer *Deployer) *SSOManager {
    return &SSOManager{deployer: deployer}
}

func (s *SSOManager) IntegrateAll() error {
    fmt.Println("🔐 Integrating services with Keycloak SSO...")
    
    // 1. Create Keycloak realm
    if err := s.createRealm("ceres"); err != nil {
        return err
    }
    
    // 2. Create OIDC clients
    clients := []string{
        "gitlab", "grafana", "mattermost", "wikijs",
        "nextcloud", "mailcow", "oauth2-proxy",
    }
    
    for _, client := range clients {
        fmt.Printf("  📝 Creating client: %s\n", client)
        if err := s.createClient(client); err != nil {
            return err
        }
    }
    
    // 3. Deploy OAuth2 Proxy
    if err := s.deployer.ApplyManifest("deployment/oauth2-proxy.yaml"); err != nil {
        return err
    }
    
    // 4. Update service configurations
    services := map[string]string{
        "gitlab":     "deployment/gitlab-keycloak.yaml",
        "grafana":    "deployment/grafana-keycloak.yaml",
        "mattermost": "deployment/mattermost-keycloak.yaml",
        "wikijs":     "deployment/wikijs-keycloak.yaml",
    }
    
    for name, manifest := range services {
        fmt.Printf("  🔧 Configuring %s...\n", name)
        if err := s.deployer.ApplyManifest(manifest); err != nil {
            return err
        }
    }
    
    // 5. Update Ingress with OAuth2 Proxy annotations
    if err := s.updateIngressForSSO(); err != nil {
        return err
    }
    
    fmt.Println("✅ SSO integration complete")
    return nil
}

func (s *SSOManager) createRealm(name string) error {
    // Use Keycloak Admin API
    return nil
}

func (s *SSOManager) createClient(name string) error {
    // Use Keycloak Admin API
    return nil
}

func (s *SSOManager) updateIngressForSSO() error {
    // Add OAuth2 Proxy annotations to Ingress
    return s.deployer.ApplyManifest("deployment/ingress-routes-sso.yaml")
}
```

**Критерии приемки**:
- [ ] Все 10 сервисов используют Keycloak для входа
- [ ] Single Sign-On работает (вход в один сервис = доступ ко всем)
- [ ] Logout из Keycloak выходит из всех сервисов
- [ ] Роли Keycloak управляют доступом (admin, user, viewer)

---

### 4.7. ФАЗА 7: HEALTH CHECK & MONITORING (День 8-9)

#### Задача 6.1: Автоматическая Диагностика
**Приоритет**: Высокий  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Реализовать автоматическую диагностику с самовосстановлением.

**Технические детали**: См. QUICK_ANALYSIS.md, раздел Priority 5

**Критерии приемки**:
- [ ] Команда `ceres health` проверяет все критичные сервисы
- [ ] Автоматически исправляет проблемы
- [ ] Отчет сохраняется в Markdown

---

#### Задача 6.2: Grafana Dashboards
**Приоритет**: Средний  
**Трудоемкость**: 2 часа  
**Исполнитель**: DevOps Engineer

**Описание**: Создать дашборды для мониторинга платформы.

**Дашборды**:
1. **CERES Platform Overview**
   - Running pods / Total pods
   - CPU/Memory usage
   - Network traffic
   - Storage usage

2. **Service Health**
   - PostgreSQL connections
   - Redis operations/sec
   - GitLab uptime
   - Keycloak sessions

3. **Logs Dashboard**
   - Error rate by service
   - Top 10 errors
   - Log volume

**Критерии приемки**:
- [ ] 3 дашборда импортированы в Grafana
- [ ] Все панели показывают данные
- [ ] Алерты настроены

---

## 5. КРИТЕРИИ ПРИЕМКИ ПРОЕКТА

### 5.1. Функциональные Критерии

#### Критичные (Must Have)
- [ ] **Все критичные сервисы работают**: PostgreSQL, Redis, Keycloak, GitLab, Ingress NGINX
- [ ] **Zero CrashLoopBackOff**: Нет падающих подов
- [ ] **Backup автоматизирован**: Ежедневный backup создается в 02:00
- [ ] **TLS работает**: Все веб-сервисы доступны через HTTPS
- [ ] **CLI полностью функционален**: Все команды работают без ошибок

#### Важные (Should Have)
- [ ] **VPN setup одной командой**: `ceres vpn setup` создает конфиг
- [ ] **Логи собираются**: Promtail → Loki работает
- [ ] **Мониторинг полный**: Grafana дашборды показывают метрики
- [ ] **Health check автоматический**: `ceres health` выполняется без ошибок

#### Желательные (Nice to Have)
- [ ] **OAuth2 Proxy**: Единая аутентификация
- [ ] **GitOps**: Flux CD синхронизируется с Git
- [ ] **Алерты**: Email/Slack уведомления при проблемах

### 5.2. Нефункциональные Критерии

- [ ] **Производительность**: Время развертывания < 15 минут
- [ ] **Надежность**: Uptime > 99.9%
- [ ] **Документация**: Все команды задокументированы
- [ ] **Тесты**: E2E тесты проходят

### 5.3. Метрики Успеха

| Метрика | Текущее | Целевое | Критичность |
|---------|---------|---------|-------------|
| Running Pods | 27/38 (71%) | 25/25 (100%) | Критично |
| CrashLoopBackOff | 9 | 0 | Критично |
| RAM Usage | ~12GB | ~8GB | Важно |
| Автоматизация | 60% | 95% | Критично |
| MTTR | N/A | < 5 мин | Критично |
| Backup Frequency | Нет | Ежедневно | Критично |
| TLS Coverage | 0% | 100% | Важно |

---

## 6. РИСКИ И МИТИГАЦИЯ

### 6.1. Технические Риски

#### Риск 1: GitLab Требует Много Ресурсов
**Вероятность**: Высокая  
**Влияние**: Критичное  
**Описание**: GitLab может не запуститься на серверах с < 8GB RAM

**Митигация**:
- Установить resource limits
- Отключить ненужные функции (Prometheus, Sentry)
- Альтернатива: использовать Gitea (lightweight)

#### Риск 2: Потеря Данных При Удалении Дубликатов
**Вероятность**: Средняя  
**Влияние**: Среднее  
**Описание**: Elasticsearch может содержать важные логи

**Митигация**:
- Предупреждение пользователя перед удалением
- Экспорт данных из Elasticsearch перед удалением
- Backup namespace перед удалением

#### Риск 3: TLS Сертификаты Не Выпускаются
**Вероятность**: Средняя  
**Влияние**: Среднее  
**Описание**: Let's Encrypt может не работать без внешнего IP

**Митигация**:
- Использовать self-signed сертификаты (работает всегда)
- Документировать добавление CA в trusted

#### Риск 4: Velero Backup Заполняет Диск
**Вероятность**: Средняя  
**Влияние**: Высокое  
**Описание**: Backups могут занять весь диск MinIO

**Митигация**:
- TTL 30 дней для backups
- Мониторинг размера MinIO bucket
- Алерты при заполнении > 80%

### 6.2. Организационные Риски

#### Риск 5: Отсутствие Знаний Kubernetes
**Вероятность**: Средняя  
**Влияние**: Среднее  
**Описание**: Команда может не знать как отлаживать K8s

**Митигация**:
- Обучение команды (документация)
- Автоматизация типовых задач в CLI
- Runbook для типовых проблем

---

## 7. ГРАФИК ВЫПОЛНЕНИЯ

### 7.1. Gantt Chart

```
День 1-2: СТАБИЛИЗАЦИЯ
├─ [1h]  Задача 1.1: Удаление дубликатов
├─ [2h]  Задача 1.2: Исправление Ingress NGINX
├─ [3h]  Задача 1.3: Исправление Keycloak
├─ [4h]  Задача 1.4: Исправление GitLab
└─ [2h]  Задача 1.5: Исправление Nextcloud

День 3: TLS AUTOMATION
├─ [2h]  Задача 2.1: Установка Cert-Manager
└─ [1h]  Задача 2.2: Обновление Ingress Routes

День 4: BACKUP & RECOVERY
├─ [3h]  Задача 3.1: Установка Velero
└─ [1h]  Задача 3.2: Тестирование backup/restore

День 5: LOGGING PIPELINE
├─ [2h]  Задача 4.1: Установка Promtail
└─ [1h]  Задача 4.2: Проверка логов в Grafana

День 6: VPN AUTOMATION
├─ [3h]  Задача 5.1: Автоматизация WireGuard
└─ [1h]  Задача 5.2: Тестирование VPN

День 7: MAILCOW & SSO INTEGRATION
├─ [4h]  Задача 6.1: Установка Mailcow
└─ [6h]  Задача 6.2: Интеграция Keycloak с сервисами

День 8-9: HEALTH CHECK & MONITORING
├─ [2h]  Задача 7.1: Автоматическая диагностика
├─ [2h]  Задача 7.2: Grafana Dashboards
├─ [2h]  Задача 7.3: SMTP интеграция для алертов
└─ [2h]  Финальное тестирование и документация
```

### 7.2. Milestones

| Milestone | Дата | Критерии |
|-----------|------|----------|
| **M1: Стабильная Платформа** | День 2 | 0 CrashLoopBackOff, все критичные сервисы Running |
| **M2: HTTPS Enabled** | День 3 | Cert-Manager работает, TLS для всех сервисов |
| **M3: Backup Автоматизирован** | День 4 | Velero создает ежедневные backups |
| **M4: Полное Логирование** | День 5 | Promtail собирает логи, видны в Grafana |
| **M5: One-Click VPN** | День 6 | `ceres vpn setup` работает |
| **M6: Production Ready** | День 7 | Все критерии приемки выполнены |

---

## 8. ДОКУМЕНТАЦИЯ

### 8.1. Обновление Документации

Следующие файлы должны быть обновлены:

1. **README.md**
   - Добавить секцию "Backup & Recovery"
   - Обновить список сервисов (убрать дубликаты)
   - Добавить секцию "Security (TLS)"

2. **VERSIONING.md**
   - Добавить запись о v3.1.0
   - Описать breaking changes (удаление сервисов)

3. **QUICKSTART.md**
   - Обновить шаги развертывания
   - Добавить VPN setup

4. **DEPLOYMENT_PLAN.md**
   - Отметить завершенные фазы
   - Обновить архитектуру

5. Создать новые файлы:
   - **BACKUP_GUIDE.md** - Руководство по backup/restore
   - **TLS_SETUP.md** - Настройка TLS сертификатов
   - **VPN_GUIDE.md** - Подключение к VPN
   - **TROUBLESHOOTING.md** - Решение типовых проблем

### 8.2. Runbook

Создать runbook для типовых сценариев:

```markdown
# CERES Platform Runbook

## Scenario 1: Pod в CrashLoopBackOff
1. `ceres diagnose` - диагностика
2. `kubectl logs -n <namespace> <pod> --tail=100`
3. `ceres fix <service>` - автоисправление
4. Если не помогло → См. TROUBLESHOOTING.md

## Scenario 2: Нет доступа к сервисам
1. Проверить Ingress: `kubectl get ingress -A`
2. Проверить VPN: `ceres vpn status`
3. Проверить NodePort: `kubectl get svc -A | grep NodePort`

## Scenario 3: Восстановление из backup
1. `ceres backup list` - список backups
2. `ceres backup restore <name>` - восстановление
3. Проверка: `ceres status`
```

---

## 9. ТЕСТИРОВАНИЕ

### 9.1. Unit Tests

```go
// pkg/deployment/deployer_test.go
func TestRemoveDuplicates(t *testing.T) {
    // Mock kubectl calls
    // Test successful deletion
    // Test error handling
}

func TestFixKeycloak(t *testing.T) {
    // Test database creation
    // Test pod restart
    // Test readiness check
}
```

### 9.2. Integration Tests

```bash
#!/bin/bash
# tests/integration_test.sh

echo "=== CERES v3.1 Integration Tests ==="

# Test 1: Deployment
./bin/ceres deploy --dry-run
if [ $? -ne 0 ]; then
    echo "❌ Deploy command failed"
    exit 1
fi

# Test 2: Status
./bin/ceres status | grep "Running"
if [ $? -ne 0 ]; then
    echo "❌ No running pods found"
    exit 1
fi

# Test 3: Backup
./bin/ceres backup create test-backup
./bin/ceres backup list | grep "test-backup"
if [ $? -ne 0 ]; then
    echo "❌ Backup not created"
    exit 1
fi

# Test 4: Health Check
./bin/ceres health
if [ $? -ne 0 ]; then
    echo "❌ Health check failed"
    exit 1
fi

echo "✅ All integration tests passed"
```

### 9.3. E2E Tests

```yaml
# tests/e2e/test-suite.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: e2e-tests
data:
  test.sh: |
    #!/bin/bash
    # E2E Test: Full Platform Deployment
    
    # 1. Deploy platform
    ceres deploy
    
    # 2. Wait for all pods Running
    kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=600s
    
    # 3. Test service endpoints
    curl -k https://grafana.ceres.local
    curl -k https://gitlab.ceres.local
    
    # 4. Create backup
    ceres backup create e2e-test
    
    # 5. Simulate failure
    kubectl delete pod -n ceres -l app=keycloak
    
    # 6. Verify auto-recovery
    sleep 30
    ceres health
    
    # 7. Restore from backup
    ceres backup restore e2e-test
    
    echo "✅ E2E tests completed"
```

---

## 10. ПОДДЕРЖКА И ЭКСПЛУАТАЦИЯ

### 10.1. SLA

| Service | Uptime | MTTR | RPO | RTO |
|---------|--------|------|-----|-----|
| PostgreSQL | 99.9% | 5 min | 24h | 30 min |
| Redis | 99.9% | 5 min | 24h | 15 min |
| Keycloak | 99.5% | 10 min | 24h | 30 min |
| GitLab | 99.5% | 15 min | 24h | 60 min |
| Monitoring | 99.0% | 30 min | N/A | N/A |

### 10.2. On-Call Runbook

**Алерт: Pod CrashLoopBackOff**
```
1. Severity: P1 (Critical)
2. Action:
   - ssh to server
   - ceres diagnose
   - ceres fix <service>
3. Escalation: If not resolved in 30 min → Senior DevOps
```

**Алерт: Disk Space > 90%**
```
1. Severity: P2 (High)
2. Action:
   - Check backup storage: kubectl exec -n minio minio-xxx -- df -h
   - Delete old backups: ceres backup delete <old-backup>
   - Increase PVC size if needed
3. Escalation: If disk full → P1
```

---

## 11. СТОИМОСТЬ И РЕСУРСЫ

### 11.1. Трудозатраты

| Фаза | Задач | Часов | Человеко-дней |
|------|-------|-------|---------------|
| Фаза 1: Стабилизация | 5 | 12 | 1.5 |
| Фаза 2: TLS | 2 | 3 | 0.4 |
| Фаза 3: Backup | 2 | 4 | 0.5 |
| Фаза 4: Logging | 2 | 3 | 0.4 |
| Фаза 5: VPN | 2 | 4 | 0.5 |
| Фаза 6: Mailcow & SSO | 2 | 10 | 1.3 |
| Фаза 7: Monitoring | 3 | 6 | 0.8 |
| Тестирование | - | 4 | 0.5 |
| Документация | - | 4 | 0.5 |
| **ИТОГО** | **18** | **50** | **6.4** |

### 11.2. Команда

- **DevOps Engineer (Senior)**: 1 человек, full-time, 9 дней
- **QA Engineer**: 0.5 человека (тестирование), 2 дня

### 11.3. Инфраструктура

**Текущая** (достаточно):
- Proxmox: 1 сервер (8 CPU, 16GB RAM, 200GB SSD)
- K3s: 1 node

**Если понадобится масштабирование**:
- +2 worker nodes (8 CPU, 16GB RAM each)
- Стоимость: ~$100-200/месяц (облако) или $0 (on-premise)

---

## 12. ПРИЛОЖЕНИЯ

### 12.1. Глоссарий

- **CrashLoopBackOff**: Состояние пода, когда контейнер постоянно падает и перезапускается
- **ClusterIP**: Внутренний IP-адрес сервиса в Kubernetes
- **NodePort**: Порт на узле кластера для доступа к сервису извне
- **PVC**: Persistent Volume Claim - запрос на хранилище
- **StatefulSet**: Контроллер для stateful приложений (БД)
- **DaemonSet**: Контроллер для запуска пода на каждом узле

### 12.2. Ссылки

- [Cert-Manager Documentation](https://cert-manager.io/docs/)
- [Velero Documentation](https://velero.io/docs/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/)
- [WireGuard Quick Start](https://www.wireguard.com/quickstart/)
- [K3s Documentation](https://docs.k3s.io/)

---

## СОГЛАСОВАНИЕ

| Роль | ФИО | Подпись | Дата |
|------|-----|---------|------|
| Заказчик | | | |
| Технический Лидер | | | |
| DevOps Lead | | | |
| QA Lead | | | |

---

**Версия документа**: 1.0  
**Дата создания**: 21 января 2026  
**Статус**: На согласовании
