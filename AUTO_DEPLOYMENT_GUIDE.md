# CERES v3.0.0 - Полное Автоматическое Развертывание

## ✨ Что Изменилось

- ✅ **Все на Go** - никаких PowerShell скриптов
- ✅ **Идемпотентность** - можно запускать сколько угодно раз
- ✅ **Автообновление** - определяет версию и обновляет
- ✅ **16+ Сервисов** - полная платформа из коробки
- ✅ **Состояние в K8s** - ConfigMap для отслеживания
- ✅ **VPN Интеграция** - WireGuard автоматически

## 🚀 Быстрый Старт

### Развертывание на Proxmox

```bash
# 1. Подключиться к Proxmox
ssh root@192.168.1.3

# 2. Скопировать код CERES
# (Можно через scp с Windows или git clone)

# 3. Перейти в директорию
cd /root/ceres

# 4. Собрать CLI
go build -o /usr/local/bin/ceres ./cmd/ceres

# 5. РАЗВЕРНУТЬ ВСЕ!
ceres deploy --cloud proxmox
```

**Это все!** Одна команда разворачивает:
- PostgreSQL + Redis
- Keycloak (SSO)
- Grafana + Prometheus + Loki + AlertManager + Jaeger
- GitLab + Nextcloud + Mattermost + Wiki.js + Redmine
- MinIO + Vault
- Ingress NGINX с маршрутами

## 📊 Проверка Статуса

```bash
# На сервере
ceres status

# Или через kubectl
kubectl get pods --all-namespaces
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

## 🌐 Доступ к Сервисам

### HTTP (через Ingress)

Все сервисы доступны через NodePort 30080:

```
http://192.168.1.3:30080/auth        # Keycloak (admin : K3yClo@k!2025)
http://192.168.1.3:30080/grafana     # Grafana (admin : Grafana@Admin2025)
http://192.168.1.3:30080/prometheus  # Prometheus
http://192.168.1.3:30080/jaeger      # Jaeger
http://192.168.1.3:30080/gitlab      # GitLab (root : GitLab@Root2025)
http://192.168.1.3:30080/nextcloud   # Nextcloud (admin : Nextcloud@Admin2025)
http://192.168.1.3:30080/mattermost  # Mattermost
http://192.168.1.3:30080/wiki        # Wiki.js
http://192.168.1.3:30080/redmine     # Redmine
http://192.168.1.3:30080/minio       # MinIO (minioadmin : MinIO@Admin2025)
http://192.168.1.3:30080/vault       # Vault
```

### VPN (прямой доступ к ClusterIP)

```bash
# На Windows клиенте (требует сборки ceres.exe)
ceres vpn setup --server 192.168.1.3

# После подключения - доступ напрямую к ClusterIP
# PostgreSQL: 10.43.1.196:5432
# Redis: 10.43.89.168:6379
# и т.д.
```

## 🔄 Идемпотентность

### Первый Запуск
```
ceres deploy --cloud proxmox

📦 Step 1: Infrastructure Setup
📦 Step 2: Initialize State
📦 Step 3: Core Services (PostgreSQL, Redis)
📦 Step 4: Networking (Ingress NGINX)
📦 Step 5: Identity (Keycloak)
📦 Step 6: All Services (16 сервисов)
📦 Step 7: Ingress Routes
📦 Step 8: Mark Installation Complete
✅ Installation Complete!

=====================================
🌐 Access Information
=====================================

📊 Services:
  PostgreSQL:  10.43.1.196:5432 (user: postgres, pass: ceres_postgres_2025)
  Redis:       10.43.89.168:6379 (pass: ceres_redis_2025)
  Keycloak:    <ClusterIP>:8080 (admin / K3yClo@k!2025)
  Grafana:     <ClusterIP>:3000 (admin / Grafana@Admin2025)
  ...

🌍 External Access (NodePort):
  Ingress HTTP:  http://192.168.1.3:30080
  Ingress HTTPS: https://192.168.1.3:30443
```

### Повторный Запуск (Reconciliation)
```
ceres deploy --cloud proxmox

📋 Reconciling existing installation...
  📄 Applying deployment/postgresql-fixed.yaml
  📄 Applying deployment/redis.yaml
  📄 Applying deployment/keycloak.yaml
  📄 Applying deployment/ingress-nginx.yaml
  📄 Applying deployment/all-services.yaml
  📄 Applying deployment/ingress-routes.yaml
✅ Reconciliation complete!
```

### Обновление Версии
```
# Обновить код до новой версии
# Запустить deploy

ceres deploy --cloud proxmox

🔄 Upgrading from v2.0.0 to v3.0.0
  📄 Applying all manifests...
✅ Upgrade complete!
```

## 📦 Развернутые Сервисы

| Категория | Сервисы | Порт/Path |
|-----------|---------|-----------|
| **Database** | PostgreSQL 16 | 5432 |
|  | Redis 7.0 | 6379 |
| **Identity** | Keycloak 23.0 | /auth |
|  | Vault 1.15 | /vault |
| **Monitoring** | Grafana 10.2 | /grafana |
|  | Prometheus 2.48 | /prometheus |
|  | Loki 2.9 | 3100 |
|  | AlertManager 0.26 | 9093 |
|  | Jaeger 1.51 | /jaeger |
| **Collaboration** | GitLab CE 16.6 | /gitlab |
|  | Nextcloud 28 | /nextcloud |
|  | Mattermost 9.2 | /mattermost |
|  | Wiki.js 2 | /wiki |
| **Project Mgmt** | Redmine 5.1 | /redmine |
| **Storage** | MinIO | /minio |
| **Networking** | Ingress NGINX | 30080/30443 |

**Всего: 16 сервисов**

## 🗂️ Структура Проекта

```
Ceres/
├── cmd/ceres/main.go                  # CLI entry point
├── pkg/
│   ├── deployment/
│   │   └── deployer.go                # Основная логика развертывания
│   ├── state/
│   │   └── state.go                   # Управление состоянием
│   └── vpn/
│       └── vpn.go                     # VPN автоматизация
├── deployment/
│   ├── ceres-state.yaml               # ConfigMap с состоянием
│   ├── postgresql-fixed.yaml          # PostgreSQL StatefulSet
│   ├── redis.yaml                     # Redis Deployment
│   ├── keycloak.yaml                  # Keycloak + ConfigMap
│   ├── ingress-nginx.yaml             # Ingress Controller
│   ├── all-services.yaml              # Все 16 сервисов
│   └── ingress-routes.yaml            # Ingress правила
└── DEPLOYMENT_AUTOMATION.md           # Полная документация
```

## 🎮 Команды CLI

```bash
# === DEPLOY ===
ceres deploy --cloud proxmox              # Полное развертывание
ceres deploy --cloud proxmox --dry-run    # Проверка без изменений
ceres deploy --namespace ceres            # Указать namespace

# === STATUS ===
ceres status                              # Общий статус
ceres status --namespace monitoring       # Статус конкретного namespace

# === VPN ===
ceres vpn setup                           # Настроить VPN (WireGuard)
ceres vpn setup --server 192.168.1.3      # С указанием сервера
ceres vpn status                          # Статус VPN
ceres vpn disconnect                      # Отключить VPN

# === CONFIG ===
ceres config show                         # Показать конфигурацию
ceres config validate                     # Проверить конфигурацию

# === VALIDATE ===
ceres validate                            # Проверить инфраструктуру
```

## 🔍 Troubleshooting

### Проверить поды
```bash
kubectl get pods --all-namespaces
kubectl get pods -n monitoring
kubectl get pods -n ceres
```

### Логи сервиса
```bash
kubectl logs -n monitoring <pod-name>
kubectl logs -n ceres keycloak-xxxxx
```

### Проверить сервисы
```bash
kubectl get svc --all-namespaces
kubectl get svc -n monitoring
```

### Проверить Ingress
```bash
kubectl get ingress --all-namespaces
```

### Проверить состояние развертывания
```bash
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

### Пересоздать развертывание
```bash
# Удалить state
kubectl delete configmap ceres-deployment-state -n kube-system

# Удалить все поды (опционально)
kubectl delete namespace monitoring
kubectl delete namespace ceres

# Запустить заново
ceres deploy --cloud proxmox
```

## 🛠️ Как Работает Идемпотентность

1. **Проверка установки**
   - CLI проверяет ConfigMap `ceres-deployment-state` в `kube-system`
   - Если существует → читает версию

2. **Определение действия**
   ```go
   if installed {
       if installedVersion == CeresVersion {
           return d.update()  // Reconcile
       } else {
           return d.upgrade(installedVersion)  // Upgrade
       }
   }
   return d.freshInstall()  // New install
   ```

3. **Выполнение**
   - **Fresh Install**: Разворачивает все манифесты, создает ConfigMap
   - **Update**: Применяет все манифесты (kubectl apply идемпотентен)
   - **Upgrade**: Применяет манифесты + обновляет версию в ConfigMap

4. **Результат**
   - Можно запускать `ceres deploy` сколько угодно раз
   - Не создаст дубликаты
   - Обновит конфигурацию при необходимости

## 📝 Учетные Данные

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

## 🔐 Интеграция с Proxmox

Состояние развертывания хранится в Kubernetes ConfigMap:

```bash
# На Proxmox
kubectl get configmap ceres-deployment-state -n kube-system -o yaml
```

ConfigMap содержит:
- Версию CERES
- Статус установки
- Список сервисов и их статус
- Endpoints (ClusterIP:Port)
- Учетные данные

## 🚧 Roadmap

- [ ] Helm charts для сложных сервисов
- [ ] Автоматическое создание баз данных
- [ ] Мониторинг в реальном времени
- [ ] Web UI для управления
- [ ] Backup/Restore автоматизация
- [ ] Multi-cloud support (AWS, Azure, GCP)

---

## 📚 Дополнительная Документация

- [DEPLOYMENT_AUTOMATION.md](./DEPLOYMENT_AUTOMATION.md) - Полное описание автоматизации
- [README.md](./README.md) - Общая информация о проекте
- [deployment/](./deployment/) - Все Kubernetes манифесты

---

🚀 **CERES v3.0.0** - Enterprise Kubernetes Platform  
Made with ❤️ for Production Deployments
