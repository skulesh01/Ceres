# 🌐 CERES v3.1.0 - Access Guide

**Server IP**: 192.168.1.3  
**Updated**: January 22, 2026

---

## 🔑 Default Credentials

**Keycloak Admin**: admin / admin123

---

## 🚀 Quick Access

### ✅ Direct IP Access (No Configuration Needed)
- **Main Portal**: http://192.168.1.3/ (Keycloak SSO)

### 🏠 Domain Access (Requires hosts file configuration)

**Add to hosts file** (`/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`):
```
192.168.1.3 keycloak.ceres.local gitlab.ceres.local grafana.ceres.local chat.ceres.local files.ceres.local wiki.ceres.local mail.ceres.local portainer.ceres.local minio.ceres.local db.ceres.local prometheus.ceres.local projects.ceres.local vault.ceres.local
```

---

## 📋 All Services (via Traefik Ingress)

## 📋 All Services (via Traefik Ingress)

### 🔐 Identity & Access
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Keycloak** | http://keycloak.ceres.local/ | `kubectl port-forward -n ceres svc/keycloak 8080:8080` | SSO & IAM |

### 🗂️ Development & Collaboration  
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **GitLab** | http://gitlab.ceres.local/ | `kubectl port-forward -n gitlab svc/gitlab 8081:80` | Git, CI/CD, Registry |
| **Mattermost** | http://chat.ceres.local/ | `kubectl port-forward -n mattermost svc/mattermost 8065:8065` | Team Chat |
| **Redmine** | http://projects.ceres.local/ | `kubectl port-forward -n redmine svc/redmine 3002:3000` | Project Management |

### 📊 Monitoring & Observability
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Grafana** | http://grafana.ceres.local/ | `kubectl port-forward -n monitoring svc/grafana 3000:3000` | Dashboards |
| **Prometheus** | http://prometheus.ceres.local/ | `kubectl port-forward -n monitoring svc/prometheus 9090:9090` | Metrics |

### 📁 Storage & Files
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Nextcloud** | http://files.ceres.local/ | `kubectl port-forward -n nextcloud svc/nextcloud 8082:80` | File Sharing |
| **MinIO** | http://minio.ceres.local/ | `kubectl port-forward -n minio svc/minio 9001:9001` | S3 Storage |

### 📚 Documentation
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Wiki.js** | http://wiki.ceres.local/ | `kubectl port-forward -n wiki svc/wikijs 3001:3000` | Knowledge Base |

### 🛠️ Infrastructure
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Portainer** | http://portainer.ceres.local/ | `kubectl port-forward -n portainer svc/portainer 9443:9443` | Container Management |
| **Adminer** | http://db.ceres.local/ | `kubectl port-forward -n adminer svc/adminer 8083:8080` | Database UI |
| **Vault** | http://vault.ceres.local/ | `kubectl port-forward -n vault svc/vault 8200:8200` | Secrets Management |

### 📧 Email
| Service | Domain URL | Port-Forward | Description |
|---------|-----------|--------------|-------------|
| **Mailcow** | http://mail.ceres.local/ | `kubectl port-forward -n mailcow svc/mailcow-webmail 8084:80` | Email Server |

---

## 🎯 Quick Start Commands

### Access Keycloak (Main Portal)
```bash
# Direct IP (works immediately)
http://192.168.1.3/

# With domain (after hosts file update)
http://keycloak.ceres.local/
```

### Access Other Services via Port-Forward
```bash
# GitLab
kubectl port-forward -n gitlab svc/gitlab 8081:80 &
# Open: http://localhost:8081/

# Grafana  
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
# Open: http://localhost:3000/

# Nextcloud
kubectl port-forward -n nextcloud svc/nextcloud 8082:80 &
# Open: http://localhost:8082/
```

---

## 🚨 Troubleshooting

### Run Automated Fix
```bash
./scripts/fix-ingress.sh
```

### Check Services Status
```bash
kubectl get pods -A | grep Running
kubectl get ingress -A
```

---

## 📚 Documentation

- [QUICKSTART.md](QUICKSTART.md) - Quick Start Guide
- [docs/INGRESS_FIX.md](docs/INGRESS_FIX.md) - Ingress Troubleshooting
- [CHANGELOG.md](CHANGELOG.md) - Version History

---

**Version**: 3.1.0  
**Last Updated**: January 22, 2026

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
