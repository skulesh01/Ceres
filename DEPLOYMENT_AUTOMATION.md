# CERES v3.0.0 - Идемпотентное Развертывание

## Автоматизация

Все развертывание выполняется **одной командой Go CLI**. Никаких отдельных PowerShell скриптов.

## Быстрый Старт

```bash
# 1. Сборка
cd e:\Новая папка\All_project\Ceres
go build -o bin/ceres.exe ./cmd/ceres

# 2. Развертывание (идемпотентно)
.\bin\ceres.exe deploy --cloud proxmox

# 3. Проверка статуса
.\bin\ceres.exe status

# 4. Настройка VPN (опционально)
.\bin\ceres.exe vpn setup --server 192.168.1.3
```

## Что Происходит При Развертывании

### Первый Запуск (Fresh Install)
```
📦 Step 1: Infrastructure Setup
📦 Step 2: Initialize State (ConfigMap)
📦 Step 3: Core Services (PostgreSQL, Redis)
📦 Step 4: Networking (Ingress NGINX)
📦 Step 5: Identity (Keycloak)
📦 Step 6: All Services (20+ сервисов)
📦 Step 7: Ingress Routes
📦 Step 8: Mark Installation Complete
✅ Installation Complete!
```

### Повторный Запуск (Update/Reconciliation)
```
📋 Reconciling existing installation...
  📄 Applying deployment/postgresql-fixed.yaml
  📄 Applying deployment/redis.yaml
  📄 Applying deployment/keycloak.yaml
  📄 Applying deployment/ingress-nginx.yaml
  📄 Applying deployment/all-services.yaml
  📄 Applying deployment/ingress-routes.yaml
✅ Reconciliation complete!
```

### Обновление Версии (Upgrade)
```
🔄 Upgrading from v2.0.0 to v3.0.0
  📄 Applying all manifests...
  ✅ Version updated: 3.0.0
✅ Upgrade complete!
```

## Идемпотентность

CLI автоматически определяет:
- ✅ Установлен ли CERES (проверка ConfigMap `ceres-deployment-state`)
- ✅ Текущую версию
- ✅ Нужно ли обновление или переустановка

**Результат:** Можно запускать `ceres deploy` сколько угодно раз - не будет дублирования.

## Развернутые Сервисы

### Core Infrastructure (2)
- PostgreSQL 16 (StatefulSet)
- Redis 7.0

### Identity & Security (2)
- Keycloak 23.0 (SSO/OIDC)
- Vault 1.15 (Secrets)

### Monitoring & Observability (5)
- Grafana 10.2
- Prometheus 2.48
- Loki 2.9 (Logs)
- AlertManager 0.26
- Jaeger 1.51 (Tracing)

### Collaboration (4)
- GitLab CE 16.6
- Nextcloud 28
- Mattermost 9.2
- Wiki.js 2

### Project Management (1)
- Redmine 5.1

### Storage (1)
- MinIO (S3-compatible)

### Networking (1)
- Ingress NGINX

**ИТОГО: 16 сервисов** (можно легко добавить еще)

## Доступ к Сервисам

### Через Ingress (HTTP)
```
http://192.168.1.3:30080/auth         # Keycloak
http://192.168.1.3:30080/grafana      # Grafana
http://192.168.1.3:30080/prometheus   # Prometheus
http://192.168.1.3:30080/jaeger       # Jaeger
http://192.168.1.3:30080/gitlab       # GitLab
http://192.168.1.3:30080/nextcloud    # Nextcloud
http://192.168.1.3:30080/mattermost   # Mattermost
http://192.168.1.3:30080/wiki         # Wiki.js
http://192.168.1.3:30080/redmine      # Redmine
http://192.168.1.3:30080/minio        # MinIO Console
http://192.168.1.3:30080/vault        # Vault UI
```

### Через VPN (Direct ClusterIP)
```bash
# 1. Подключиться к VPN
.\bin\ceres.exe vpn setup

# 2. Проверить подключение
.\bin\ceres.exe vpn status

# 3. Доступ к сервисам напрямую
# PostgreSQL: <ClusterIP>:5432
# Redis: <ClusterIP>:6379
# Grafana: <ClusterIP>:3000
# И т.д.
```

## Состояние Развертывания

### Просмотр Состояния
```bash
# Через CLI
.\bin\ceres.exe status

# Через kubectl
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

### Структура ConfigMap
```yaml
data:
  version: "3.0.0"
  installed: "true"
  installDate: "2025-01-28T..."
  services: |
    postgresql: deployed
    redis: deployed
    keycloak: deployed
    ...
  endpoints: |
    postgresql: 10.43.1.196:5432
    redis: 10.43.89.168:6379
    ...
  credentials: |
    postgres_password: ceres_postgres_2025
    keycloak_admin: admin:K3yClo@k!2025
    ...
```

## Учетные Данные

| Сервис | Пользователь | Пароль |
|--------|-------------|---------|
| PostgreSQL | postgres | ceres_postgres_2025 |
| Redis | - | ceres_redis_2025 |
| Keycloak | admin | K3yClo@k!2025 |
| Grafana | admin | Grafana@Admin2025 |
| GitLab | root | GitLab@Root2025 |
| Nextcloud | admin | Nextcloud@Admin2025 |
| MinIO | minioadmin | MinIO@Admin2025 |
| Vault | - | root-token-2025 |

## Команды CLI

```bash
# Развертывание
ceres deploy --cloud proxmox
ceres deploy --cloud proxmox --dry-run

# Статус
ceres status
ceres status --namespace ceres

# VPN
ceres vpn setup --server 192.168.1.3
ceres vpn status
ceres vpn disconnect

# Конфигурация
ceres config show
ceres config validate

# Валидация
ceres validate
```

## Архитектура

```
┌─────────────────────────────────────────────┐
│           Ingress NGINX (NodePort)          │
│         http://192.168.1.3:30080            │
└────────────────┬────────────────────────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
┌─────────┐ ┌─────────┐ ┌──────────┐
│Keycloak │ │ Grafana │ │  GitLab  │
│  (SSO)  │ │(Monitor)│ │  (Git)   │
└─────────┘ └─────────┘ └──────────┘
    │            │            │
    └────────────┼────────────┘
                 ▼
         ┌──────────────┐
         │  PostgreSQL  │
         │   (Database) │
         └──────────────┘

WireGuard VPN (10.8.0.0/24)
  └─> Direct ClusterIP Access
```

## Интеграция с Proxmox

Состояние развертывания хранится в:
1. **Kubernetes ConfigMap** - `ceres-deployment-state` (kube-system namespace)
2. **Доступно через Proxmox** - kubectl на сервере Proxmox

```bash
# На Proxmox сервере (192.168.1.3)
ssh root@192.168.1.3
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

## Удаление PowerShell Скриптов

Все функции теперь в Go CLI:
- ❌ deploy-all.ps1 (УДАЛИТЬ - сломан)
- ❌ deploy-simple.ps1 (УДАЛИТЬ)
- ❌ scripts/setup-vpn.ps1 (ЗАМЕНЕН на `ceres vpn setup`)
- ✅ ceres.exe (ЕДИНСТВЕННЫЙ инструмент)

## Troubleshooting

### Проверка подов
```bash
kubectl get pods --all-namespaces
```

### Проверка сервисов
```bash
kubectl get svc --all-namespaces
```

### Логи пода
```bash
kubectl logs -n <namespace> <pod-name>
```

### Пересоздать развертывание
```bash
# Удалить state
kubectl delete configmap ceres-deployment-state -n kube-system

# Запустить заново
.\bin\ceres.exe deploy --cloud proxmox
```

## Roadmap

- [ ] Helm charts для сложных сервисов (GitLab, Harbor)
- [ ] Автоматическое создание баз данных для каждого сервиса
- [ ] Мониторинг состояния сервисов в реальном времени
- [ ] Web UI для управления
- [ ] Backup/Restore автоматизация
