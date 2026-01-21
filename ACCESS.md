# CERES v3.0.0 - Доступ к Сервисам

## 🌐 Прямой Доступ (NodePort)

**16 работающих сервисов доступны напрямую:**

### 📊 Мониторинг и Наблюдение

| Сервис | URL | Логин | Пароль | Описание |
|--------|-----|-------|---------|----------|
| **Grafana** | http://192.168.1.3:30300 | admin | Grafana@Admin2025 | Дашборды мониторинга |
| **Jaeger** | http://192.168.1.3:30686 | - | - | Distributed Tracing |
| **Uptime Kuma** | http://192.168.1.3:30310 | - | Создать при первом входе | Мониторинг доступности |

### 🔧 DevOps & CI/CD

| Сервис | URL | Логин | Пароль | Описание |
|--------|-----|-------|---------|----------|
| **Gogs** | http://192.168.1.3:30701 | - | Создать при первом входе | Git (легче чем GitLab) |
| **Jenkins** | http://192.168.1.3:30808 | - | Создать при первом входе | CI/CD |
| **SonarQube** | http://192.168.1.3:30903 | admin | admin | Анализ кода |

### 💬 Collaboration

| Сервис | URL | Логин | Пароль | Описание |
|--------|-----|-------|---------|----------|
| **Mattermost** | http://192.168.1.3:30806 | - | Создать при первом входе | Командный чат |
| **Wiki.js** | http://192.168.1.3:30301 | - | Создать при первом входе | Документация |
| **Nextcloud** | http://192.168.1.3:30802 | admin | Nextcloud@Admin2025 | Файлы, календарь |

### 🗄️ Storage & Management

| Сервис | URL | Логин | Пароль | Описание |
|--------|-----|-------|---------|----------|
| **MinIO Console** | http://192.168.1.3:30901 | minioadmin | MinIO@Admin2025 | S3 Storage |
| **Portainer** | http://192.168.1.3:30902 | - | Создать при первом входе | Container Management |
| **Adminer** | http://192.168.1.3:30880 | - | - | Database Management |

### 🔐 Security

| Сервис | URL | Логин | Пароль | Описание |
|--------|-----|-------|---------|----------|
| **Vault** | http://192.168.1.3:30820 | Token | root-token-2025 | Secrets Management |

### 💾 Databases (прямое подключение)

| Сервис | Host:Port | Логин | Пароль | Описание |
|--------|-----------|-------|---------|----------|
| **PostgreSQL** | 192.168.1.3:5432 | postgres | ceres_postgres_2025 | Основная БД |
| **Redis** | 192.168.1.3:6379 | - | ceres_redis_2025 | Кэш и очереди |

---

## 🚀 Быстрые Ссылки

### Открыть в Браузере (PowerShell)

```powershell
# Мониторинг
Start-Process "http://192.168.1.3:30300"  # Grafana
Start-Process "http://192.168.1.3:30686"  # Jaeger
Start-Process "http://192.168.1.3:30310"  # Uptime Kuma

# DevOps
Start-Process "http://192.168.1.3:30701"  # Gogs (Git)
Start-Process "http://192.168.1.3:30808"  # Jenkins
Start-Process "http://192.168.1.3:30903"  # SonarQube

# Collaboration
Start-Process "http://192.168.1.3:30806"  # Mattermost
Start-Process "http://192.168.1.3:30301"  # Wiki.js
Start-Process "http://192.168.1.3:30802"  # Nextcloud

# Management
Start-Process "http://192.168.1.3:30901"  # MinIO
Start-Process "http://192.168.1.3:30902"  # Portainer
Start-Process "http://192.168.1.3:30880"  # Adminer
Start-Process "http://192.168.1.3:30820"  # Vault
```

### Подключение к Базам Данных

**PostgreSQL:**
```bash
psql -h 192.168.1.3 -p 5432 -U postgres -d postgres
# Password: ceres_postgres_2025
```

**Redis:**
```bash
redis-cli -h 192.168.1.3 -p 6379 -a ceres_redis_2025
```

**Через Adminer (Web UI):**
```
http://192.168.1.3:30880
Server: postgresql.ceres-core.svc.cluster.local
Username: postgres
Password: ceres_postgres_2025
Database: postgres
```

---

## 📊 Статус Сервисов

```bash
# Проверить на сервере
ssh root@192.168.1.3 "kubectl get pods --all-namespaces | grep Running"

# Проверить сервисы
ssh root@192.168.1.3 "kubectl get svc --all-namespaces | grep NodePort"
```

---

## 🎯 Первое Использование

### 1. Grafana (Мониторинг)
```
http://192.168.1.3:30300
Логин: admin / Grafana@Admin2025
```

### 2. Gogs (Git сервер - легче чем GitLab)
```
http://192.168.1.3:30701
При первом входе создать admin аккаунт
Настроить: SQLite (встроенная БД)
```

### 3. Jenkins (CI/CD)
```
http://192.168.1.3:30808
Получить initial password:
ssh root@192.168.1.3 "kubectl exec -n jenkins jenkins-xxxxx -- cat /var/jenkins_home/secrets/initialAdminPassword"
```

### 4. Mattermost (Чат)
```
http://192.168.1.3:30806
Создать первый аккаунт (станет admin)
```

### 5. Portainer (Container Management)
```
http://192.168.1.3:30902
Создать admin пароль
Выбрать: Kubernetes
```

---

## ✅ Работающие Сервисы (16 из 17)

✅ PostgreSQL - База данных  
✅ Redis - Кэш  
✅ Grafana - Дашборды  
✅ Jaeger - Tracing  
✅ Loki - Логи  
✅ AlertManager - Алерты  
✅ Prometheus - Метрики  
✅ Gogs - Git сервер  
✅ Jenkins - CI/CD  
✅ SonarQube - Анализ кода  
✅ Mattermost - Чат  
✅ Wiki.js - Документация  
✅ Nextcloud - Файлы  
✅ MinIO - S3 Storage  
✅ Portainer - Container UI  
✅ Uptime Kuma - Uptime monitoring  
✅ Adminer - DB Management  
✅ Vault - Secrets  

---

**Обновлено:** 21 января 2026  
**Версия:** 3.0.0  
**Количество сервисов:** 18 (16 работают + 2 в процессе)
